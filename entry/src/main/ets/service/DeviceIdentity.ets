/**
 * 本机设备标识（M1 第二轮优化）：收藏/笔记/主题共享同一份 LWW deviceId。
 *
 * 设计说明：
 * 1. 优先使用系统 ODID（@ohos.deviceInfo，API 12+，无需额外权限）：
 *    ODID 按设备生成，备份恢复到新设备后读到的是新设备的 ODID；
 * 2. ODID 为空/读取失败（部分模拟器、未签名调试包等）时，回退到 cacheDir 的随机 UUID：
 *    官方备份配置的默认 includes 仅覆盖 files/preferences/database/distributedfiles 等，
 *    **不包含 cache**，因此备份恢复到新设备不会复制该 UUID；
 *    cache 被系统/用户清理时会重新生成 ID——只影响 LWW 平局归因（冲突日志显示新 ID），
 *    不影响任何用户数据，也不影响同步收敛；
 * 3. deviceId 语义 = 「最后写入该记录的设备」：业务层每次写入都必须重新取 get() 并写入记录。
 */

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'DeviceIdentity';
/** 回退标识文件（位于 cacheDir；不参与系统备份） */
const IDENTITY_FILE = 'lww_device_id.txt';

export class DeviceIdentity {
  /** 已确定的设备标识（ODID 或 cache UUID） */
  private static deviceId: string = '';
  /** 未 init 时的进程内兜底标识（不持久化，仅避免写入空 deviceId） */
  private static processId: string = '';

  /**
   * 初始化设备标识（幂等）。
   * 由 FavoriteService.init / ThemeService.init 调用；写操作前必须完成。
   */
  static init(context: common.Context): void {
    if (DeviceIdentity.deviceId !== '') {
      return;
    }
    const odid: string = DeviceIdentity.readOdid();
    if (odid !== '') {
      DeviceIdentity.deviceId = odid;
      hilog.info(DOMAIN, TAG, 'lww device id: system ODID');
      return;
    }
    let stored: string = DeviceIdentity.readCachedId(context);
    if (stored === '') {
      stored = util.generateRandomUUID(false);
      DeviceIdentity.writeCachedId(context, stored);
    }
    DeviceIdentity.deviceId = stored;
    hilog.info(DOMAIN, TAG, 'lww device id: cache uuid');
  }

  /** 取当前设备标识（业务每次写入都调用，确保记录指向真实最后写入设备） */
  static get(): string {
    if (DeviceIdentity.deviceId !== '') {
      return DeviceIdentity.deviceId;
    }
    // 理论上 init 已覆盖；未初始化时用进程内 UUID 兜底，避免把空串写入数据。
    if (DeviceIdentity.processId === '') {
      DeviceIdentity.processId = util.generateRandomUUID(false);
      hilog.warn(DOMAIN, TAG, 'device identity not initialized, use process-scoped uuid');
    }
    return DeviceIdentity.processId;
  }

  /** 读取系统 ODID（失败/为空返回空串，走 cache 回退） */
  private static readOdid(): string {
    try {
      const raw: string = deviceInfo.ODID;
      if (raw === '') {
        return '';
      }
      // 统一小写：LWW 平局按字典序比较，避免大小写差异导致排序不稳定。
      return raw.trim().toLowerCase();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read ODID failed: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  private static identityPath(context: common.Context): string {
    return `${context.cacheDir}/${IDENTITY_FILE}`;
  }

  /** 读取 cache 中的回退标识（不存在/异常返回空串） */
  private static readCachedId(context: common.Context): string {
    try {
      const path: string = DeviceIdentity.identityPath(context);
      if (!fileIo.accessSync(path)) {
        return '';
      }
      return fileIo.readTextSync(path).trim();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read cached device id failed: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  /** 写入 cache 回退标识（失败仅记日志，本次进程仍使用内存值） */
  private static writeCachedId(context: common.Context, id: string): void {
    let file: fileIo.File | null = null;
    try {
      const path: string = DeviceIdentity.identityPath(context);
      file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, id);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'write cached device id failed: %{public}s', JSON.stringify(err));
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'close device id file failed: %{public}s', JSON.stringify(err));
        }
      }
    }
  }
}
