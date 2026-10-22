import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SyncService } from '../service/SyncService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // M6.1：页面加载完成后申请分布式数据同步权限（user_grant，需 UIAbilityContext）。
      this.ensureSyncPermission();
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    // 用户可能刚从系统设置授予权限：回到前台时重试初始化（已初始化则直接返回）。
    SyncService.init(this.context);
    // M6.2：回前台主动追赶一次（后台/离线期间对端可能已写入）；无在线设备时空操作。
    SyncService.syncWhenOnline();
  }

  /** 申请分布式数据同步权限；授予后 SyncService 会立即重试初始化（M6.1） */
  private async ensureSyncPermission(): Promise<void> {
    try {
      const granted: boolean = await SyncService.requestPermission(this.context);
      hilog.info(DOMAIN, 'testTag', 'sync permission: %{public}s', granted ? 'granted' : 'denied');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'request sync permission failed: %{public}s', JSON.stringify(err));
    }
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}