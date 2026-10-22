/**
 * 权限服务（M6.1）：分布式数据同步运行时权限。
 *
 * 背景（2026-10-22 审计 B1）：
 * - `ohos.permission.DISTRIBUTED_DATASYNC` 是 user_grant（本机 SDK PermissionDefinitions.json 实测），
 *   只在 module.json5 声明不会自动授权；不申请时 `getAvailableDeviceListSync()` 抛 201，
 *   同步面板会把「权限未授予」误显示成「暂无在线设备/单机模式」。
 * - 官方文档明确：用户拒绝后 `requestPermissionsFromUser` 不能再次拉起弹窗，
 *   需 `requestPermissionOnSetting`（API 12+）或引导用户去系统设置。
 *
 * 设计：
 * - 本服务只做「权限查询/申请」；KV 初始化仍由 SyncService 负责，避免权限与存储耦合。
 * - 查询用 checkAccessTokenSync + bundleManager.getBundleInfoForSelfSync（API 10+），
 *   不用 getSelfPermissionStatus（API 20+，超出本项目 API 16 兼容下限）。
 * - 本进程只主动请求一次；面板里的重试入口走 requestPermissionOnSetting。
 * - 所有可抛异常 SDK 调用包 try/catch，失败按未授权处理（本地模式不受影响）。
 */

import { abilityAccessCtrl, bundleManager, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PermissionService';
/** 分布式数据同步权限（与 module.json5 声明一致） */
const SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';

export class PermissionService {
  /** 本进程是否已主动拉起过权限弹窗（避免多入口重复请求） */
  private static requested: boolean = false;

  /** 是否已授予分布式数据同步权限（查询失败按未授权处理） */
  static isSyncPermissionGranted(): boolean {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = info.appInfo.accessTokenId;
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const status: abilityAccessCtrl.GrantStatus =
        atManager.checkAccessTokenSync(tokenId, SYNC_PERMISSION);
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'check sync permission failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /**
   * 首次申请权限（用户拒绝后系统不会再次弹窗，需改用 requestSyncPermissionOnSetting）。
   * @return 本次申请后是否已授权
   */
  static async requestSyncPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (PermissionService.isSyncPermissionGranted()) {
      return true;
    }
    if (PermissionService.requested) {
      return false;
    }
    PermissionService.requested = true;
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, [SYNC_PERMISSION]);
      const granted: boolean = result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hilog.info(DOMAIN, TAG, 'request sync permission: %{public}s', granted ? 'granted' : 'denied');
      return granted;
    } catch (err) {
      // 系统调用异常（非用户拒绝）允许下次重试首次申请
      PermissionService.requested = false;
      hilog.error(DOMAIN, TAG, 'request sync permission failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /**
   * 用户拒绝后的再次授权入口：拉起权限设置弹窗（API 12+）。
   * 异常时回查一次当前授权状态（例如权限已被系统恢复）。
   * @return 处理后是否已授权
   */
  static async requestSyncPermissionOnSetting(context: common.UIAbilityContext): Promise<boolean> {
    if (PermissionService.isSyncPermissionGranted()) {
      return true;
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const results: abilityAccessCtrl.GrantStatus[] =
        await atManager.requestPermissionOnSetting(context, [SYNC_PERMISSION]);
      const granted: boolean = results.length > 0 &&
        results[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hilog.info(DOMAIN, TAG, 'permission on setting: %{public}s', granted ? 'granted' : 'denied');
      return granted;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'request permission on setting failed: %{public}s', JSON.stringify(err));
      return PermissionService.isSyncPermissionGranted();
    }
  }
}
