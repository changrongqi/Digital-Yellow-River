/**
 * 同步面板（M3.3）：分布式数据同步状态展示 + 手动同步入口。
 * Index 第 3 个 Tab 的内容组件（非路由页，无需注册 main_pages.json）。
 *
 * 展示项（计划书 M3.3）：
 * - 同步服务状态（分布式就绪 / 单机模式降级「等待设备上线」）；
 * - 同步进度（Progress 条）+ 最后同步时间（0 = 从未同步）；
 * - 在线（可信）设备列表与台数；
 * - 冲突记录数 + conflictLog 明细（LWW 保留结果说明）；
 * - 「立即同步」手动入口（sync PUSH_PULL，无设备/降级时给出提示文案）。
 *
 * 数据流（单一数据源 = SyncService，分层约定 §3）：
 * - aboutToAppear 读取一次快照 + 订阅 onStatusChanged（远端变更/同步完成/设备上下线
 *   均会触发刷新）；aboutToDisappear 注销防泄漏；
 * - 面板只读，一切变更经 FavoriteService → SyncService 上抛，无本地写路径。
 *
 * 环境说明（O7）：模拟器无分布式组网，本页显示降级文案与 0 台设备 = 预期行为；
 * 真实同步状态需两台真机（同华为账号 + 同 WLAN + 蓝牙）联调验证。
 */

import { common } from '@kit.AbilityKit';
import { SyncService, SyncDeviceInfo } from '../service/SyncService';
import { SyncStatus, ConflictLogItem } from '../model/SyncStatus';
import { formatDateTime } from '../utils/TimeFormat';

@Component
export struct SyncPanel {
  /** 同步状态快照（@State 整体赋值刷新，踩坑 5） */
  @State status: SyncStatus = {
    progress: 0,
    lastSyncTime: 0,
    conflictCount: 0,
    conflictLog: []
  };
  /** 在线（可信）设备列表 */
  @State devices: SyncDeviceInfo[] = [];
  /** 分布式 KV 是否就绪（false = 单机降级） */
  @State syncAvailable: boolean = false;
  /** 是否已授予分布式数据同步权限（false = 显示授权入口） */
  @State permissionGranted: boolean = false;
  /** 手动同步结果提示（空串不显示） */
  @State syncTip: string = '';
  /** 状态变化监听句柄（aboutToDisappear 注销用） */
  private statusHandler: () => void = (): void => {};

  aboutToAppear(): void {
    this.refresh();
    this.statusHandler = (): void => {
      this.refresh();
    };
    SyncService.onStatusChanged(this.statusHandler);
  }

  aboutToDisappear(): void {
    SyncService.offStatusChanged(this.statusHandler);
  }

  /** 读取服务层快照（整体赋值触发刷新） */
  private refresh(): void {
    this.status = SyncService.getStatus();
    this.devices = SyncService.getOnlineDevices();
    this.syncAvailable = SyncService.isAvailable();
    this.permissionGranted = SyncService.isPermissionGranted();
  }

  /** 手动同步：成功受理 → 等待 syncComplete 回调刷新；失败给出降级文案 */
  private doManualSync(): void {
    const ok: boolean = SyncService.manualSync();
    if (ok) {
      this.syncTip = '已发起同步，完成后将更新同步时间';
    } else {
      this.syncTip = this.syncAvailable
        ? '暂无在线设备，等待设备上线' : '同步服务未就绪（单机模式），收藏与笔记仍在本地保存';
    }
    this.refresh();
  }

  /** 服务状态文案：区分「未授权」「已授权但无组网」「已就绪」三种情况 */
  private serviceStateText(): string {
    if (this.syncAvailable) {
      return '分布式同步已就绪';
    }
    if (!this.permissionGranted) {
      return '未授权分布式同步';
    }
    return '同步服务未就绪 · 可重试';
  }

  /**
   * 授权入口（M6.1）：首次走系统权限弹窗；若用户之前拒绝过，
   * requestPermissionsFromUser 不会再次弹窗，改走 requestPermissionOnSetting。
   */
  private async doAuthorize(): Promise<void> {
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      this.syncTip = '无法获取应用上下文，请稍后重试';
      return;
    }
    const context = host as common.UIAbilityContext;
    try {
      let granted: boolean = await SyncService.requestPermission(context);
      if (!granted) {
        granted = await SyncService.requestPermissionOnSetting(context);
      }
      this.syncTip = granted
        ? '已授权分布式同步，等待设备上线' : '未获得授权，可在系统设置中开启后重试';
    } catch (err) {
      this.syncTip = '授权失败，请稍后重试';
    }
    this.refresh();
  }

  /** 初始化失败重试（M6.2）：绕过失败节流；KV ready 后状态监听会自动刷新面板 */
  private doRetryInit(): void {
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      this.syncTip = '无法获取应用上下文，请稍后重试';
      return;
    }
    SyncService.retryInit(host as common.UIAbilityContext);
    this.syncTip = '正在重试初始化，就绪后会自动刷新';
    this.refresh();
  }

  /** 冲突记录键：条目 + 时间 + 胜出设备（同条目多次冲突逐条展示） */
  private conflictKey(item: ConflictLogItem): string {
    return `${item.itemId}-${item.time}-${item.deviceId}`;
  }

  build() {
    Scroll() {
      Column() {
        // 顶部标题栏
        Row() {
          Text('同步面板')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        // ===== 同步状态卡 =====
        Column() {
          this.SectionTitle('同步状态')
          Row() {
            Text('服务状态')
              .fontSize(13)
              .fontColor('#8D6E63')
            Blank()
            Text(this.serviceStateText())
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.syncAvailable ? '#6D4C41'
                : (this.permissionGranted ? '#BCAAA4' : '#C0392B'))
          }
          .width('100%')
          .margin({ top: 12 })

          Progress({ value: this.status.progress, total: 100, type: ProgressType.Linear })
            .color('#8D6E63')
            .backgroundColor('#EFEBE9')
            .borderRadius(4)
            .height(8)
            .width('100%')
            .margin({ top: 12 })
          Text(`同步进度 ${this.status.progress}%`)
            .fontSize(11)
            .fontColor('#BCAAA4')
            .margin({ top: 4 })

          Row() {
            Text('最后同步')
              .fontSize(13)
              .fontColor('#8D6E63')
            Blank()
            Text(this.status.lastSyncTime > 0 ? formatDateTime(this.status.lastSyncTime) : '从未同步')
              .fontSize(13)
              .fontColor('#6D4C41')
          }
          .width('100%')
          .margin({ top: 12 })

          Row() {
            Text('在线设备')
              .fontSize(13)
              .fontColor('#8D6E63')
            Blank()
            Text(`${this.devices.length} 台`)
              .fontSize(13)
              .fontColor('#6D4C41')
          }
          .width('100%')
          .margin({ top: 8 })

          Row() {
            Text('冲突记录')
              .fontSize(13)
              .fontColor('#8D6E63')
            Blank()
            Text(this.status.conflictCount > 0 ? `${this.status.conflictCount} 条` : '无')
              .fontSize(13)
              .fontColor(this.status.conflictCount > 0 ? '#C0392B' : '#6D4C41')
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)

        // ===== 在线设备卡 =====
        Column() {
          this.SectionTitle('在线设备')
          if (this.devices.length === 0) {
            Text('暂无在线设备')
              .fontSize(13)
              .fontColor('#BCAAA4')
              .margin({ top: 10 })
            Text('两台设备登录同一华为账号、连接同一 WLAN 并开启蓝牙后，将自动组网出现在这里')
              .fontSize(12)
              .fontColor('#BCAAA4')
              .margin({ top: 6 })
          } else {
            ForEach(this.devices, (device: SyncDeviceInfo) => {
              Row() {
                Text(device.deviceName)
                  .fontSize(14)
                  .fontColor('#3E2723')
                  .layoutWeight(1)
                Text('可信设备')
                  .fontSize(11)
                  .fontColor('#8D6E63')
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor('#EFEBE9')
                  .borderRadius(6)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FAF6F0')
              .borderRadius(8)
              .margin({ top: 10 })
            }, (device: SyncDeviceInfo) => device.networkId)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ top: 12 })

        // ===== 手动同步卡 =====
        Column() {
          this.SectionTitle('手动同步')
          Text('日常写入后自动同步；也可在此手动发起一次全量推送与拉取（PUSH_PULL）')
            .fontSize(12)
            .fontColor('#8D6E63')
            .margin({ top: 10 })
          if (!this.permissionGranted) {
            Text('分布式同步需要「多设备数据交换」权限；未授权时收藏与笔记仍只在本地保存。')
              .fontSize(12)
              .fontColor('#C0392B')
              .lineHeight(19)
              .margin({ top: 8 })
            Button('授权分布式同步')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('#6D4C41')
              .width('100%')
              .height(44)
              .borderRadius(22)
              .margin({ top: 10 })
              .onClick(() => {
                this.doAuthorize();
              })
          }
          if (this.permissionGranted && !this.syncAvailable) {
            Text('同步服务尚未就绪，可重试初始化；本地收藏与笔记不受影响。')
              .fontSize(12)
              .fontColor('#8D6E63')
              .lineHeight(19)
              .margin({ top: 8 })
            Button('重试初始化')
              .fontSize(15)
              .fontColor('#6D4C41')
              .backgroundColor('#EFEBE9')
              .width('100%')
              .height(44)
              .borderRadius(22)
              .margin({ top: 10 })
              .onClick(() => {
                this.doRetryInit();
              })
          }
          if (this.permissionGranted && this.syncAvailable) {
            Button('立即同步')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('#6D4C41')
              .width('100%')
              .height(44)
              .borderRadius(22)
              .margin({ top: 14 })
              .onClick(() => {
                this.doManualSync();
              })
          }
          if (this.syncTip !== '') {
            Text(this.syncTip)
              .fontSize(12)
              .fontColor('#8D6E63')
              .margin({ top: 8 })
              .textAlign(TextAlign.Center)
              .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ top: 12 })

        // ===== 冲突记录卡 =====
        Column() {
          this.SectionTitle('冲突记录')
          if (this.status.conflictLog.length === 0) {
            Text('无冲突记录')
              .fontSize(13)
              .fontColor('#BCAAA4')
              .margin({ top: 10 })
          } else {
            ForEach(this.status.conflictLog, (item: ConflictLogItem) => {
              Column() {
                Row() {
                  Text(item.itemId)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#3E2723')
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(formatDateTime(item.time))
                    .fontSize(11)
                    .fontColor('#BCAAA4')
                }
                .width('100%')
                Text(item.reason)
                  .fontSize(12)
                  .fontColor('#8D6E63')
                  .margin({ top: 4 })
                if (item.deviceId !== '') {
                  Text(`最后写入设备 ${item.deviceId}`)
                    .fontSize(10)
                    .fontColor('#BCAAA4')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor('#FAF6F0')
              .borderRadius(8)
              .margin({ top: 10 })
            }, (item: ConflictLogItem) => this.conflictKey(item))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  /** 区块标题：左侧竖条 + 文字（与详情页 SectionTitle 同款样式） */
  @Builder
  SectionTitle(title: string) {
    Row() {
      Text()
        .width(4)
        .height(16)
        .borderRadius(2)
        .backgroundColor('#8D6E63')
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
        .margin({ left: 8 })
    }
    .alignItems(VerticalAlign.Center)
  }
}
