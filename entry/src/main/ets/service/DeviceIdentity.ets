/**
 * 本机设备标识（M1 第二轮优化）：收藏/笔记/主题共享同一份 LWW deviceId。
 *
 * 设计说明：
 * 1. 优先使用系统 ODID（@ohos.deviceInfo，API 12+，无需额外权限）：
 *    ODID 按设备生成，备份恢复到新设备后读到的是新设备的 ODID，
 *    天然避免「备份复制 deviceId 导致双端平局判定指向同一设备」；
 * 2. ODID 为空/读取失败（部分模拟器、未签名调试包等）时，回退到本地持久化 UUID：
 *    独立 Preferences store 'yellow_river_device'，首次从旧 store
 *    （yellow_river_user_data / yellow_river_themes 的 device_id）迁移，避免标识突变；
 * 3. deviceId 语义 = 「最后写入该记录的设备」：业务层每次写入都必须重新取 get() 并写入记录，
 *    不能只在新增时赋值（M1 审计问题）。
 */

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'DeviceIdentity';
/** 回退标识的独立 store（不与收藏/主题数据 store 共享实例） */
const STORE_NAME = 'yellow_river_device';
const KEY_DEVICE_ID = 'device_id';
/** 旧版本设备标识所在 store（迁移源，按优先级排列） */
const LEGACY_STORES: string[] = ['yellow_river_user_data', 'yellow_river_themes'];

export class DeviceIdentity {
  /** 已确定的设备标识（ODID 或持久化 UUID） */
  private static deviceId: string = '';
  /** 回退 store 实例 */
  private static fallbackPref: preferences.Preferences | null = null;
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
    let stored: string = DeviceIdentity.readFallback(context);
    if (stored === '') {
      stored = util.generateRandomUUID(false);
      DeviceIdentity.persistFallback(stored);
    }
    DeviceIdentity.deviceId = stored;
    hilog.info(DOMAIN, TAG, 'lww device id: persisted uuid');
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

  /** 读取系统 ODID（失败/为空返回空串，走持久化回退） */
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

  /** 读取回退标识：独立 store 优先，其次迁移旧 store 的历史 device_id */
  private static readFallback(context: common.Context): string {
    try {
      const options: preferences.Options = { name: STORE_NAME };
      DeviceIdentity.fallbackPref = preferences.getPreferencesSync(context, options);
      const value = DeviceIdentity.fallbackPref.getSync(KEY_DEVICE_ID, '');
      const stored: string = String(value).trim();
      if (stored !== '') {
        return stored;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read fallback store failed: %{public}s', JSON.stringify(err));
      DeviceIdentity.fallbackPref = null;
    }
    for (let i = 0; i < LEGACY_STORES.length; i++) {
      try {
        const options: preferences.Options = { name: LEGACY_STORES[i] };
        const legacy = preferences.getPreferencesSync(context, options);
        const value = legacy.getSync(KEY_DEVICE_ID, '');
        const stored: string = String(value).trim();
        if (stored !== '') {
          DeviceIdentity.persistFallback(stored);
          return stored;
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'read legacy device id failed: %{public}s', JSON.stringify(err));
      }
    }
    return '';
  }

  /** 持久化回退标识（失败仅记日志，本次进程仍使用内存值） */
  private static persistFallback(id: string): void {
    const pref = DeviceIdentity.fallbackPref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(KEY_DEVICE_ID, id);
      pref.flushSync();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist device id failed: %{public}s', JSON.stringify(err));
    }
  }
}
