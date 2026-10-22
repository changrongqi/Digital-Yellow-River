/**
 * 主页（M1.3）：Tabs 容器
 * - 发现：Discovery（rawfile 数据列表）
 * - 收藏：Favorites（M2.2 收藏列表，按标签分组）
 * - 同步：SyncPanel（M3.3 分布式同步状态面板）
 * - 图谱：KnowledgeGraph（C1.2 文化主题聚合 + 知识节点网络可视化）
 *
 * M6.10（M5）：数据刷新改为各 Tab 直接订阅业务服务（单通道）；
 * 本页只负责服务初始化与 Tab 容器，不再中转刷新信号。
 */

import { Discovery } from './Discovery';
import { Favorites } from './Favorites';
import { SyncPanel } from './SyncPanel';
import { KnowledgeGraph } from './KnowledgeGraph';
import { FavoriteService } from '../service/FavoriteService';
import { ThemeService } from '../service/ThemeService';
import { SyncService } from '../service/SyncService';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    // 提前初始化用户数据服务（幂等）：注册 SyncService 远端变更合并处理器，
    // 避免 TabContent 懒加载导致收藏 Tab 未打开时远端变更无人合并（M3.2）
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      FavoriteService.init(context);
      // M6.2：主题也提前初始化，保证 KV ready 后的初次 PULL 有 Theme 合并监听，
      // 避免用户未打开图谱 Tab 时远端主题变更被丢弃。
      ThemeService.init(context);
      // M6.2：两个业务监听都注册后再补一次追赶。KV 可能早于页面就绪，
      // 此时 SyncService 会挂起 initialSyncPending，这里负责真正发起。
      SyncService.syncWhenOnline();
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Discovery()
      }
      .tabBar(this.TabLabel('发现', 0))

      TabContent() {
        Favorites()
      }
      .tabBar(this.TabLabel('收藏', 1))

      TabContent() {
        SyncPanel()
      }
      .tabBar(this.TabLabel('同步', 2))

      TabContent() {
        KnowledgeGraph()
      }
      .tabBar(this.TabLabel('图谱', 3))
    }
    .barWidth('100%')
    .barHeight(56)
    .divider({ strokeWidth: 0.5, color: '#E0D6CC' })
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  /**
   * 底部标签。
   *
   * ⚠️ 硬约束（踩坑清单第 15 条）：active 状态必须在 @Builder 内部**直接读 this.currentIndex**，
   * 禁止改成「把选中状态当参数传进来」（如 TabLabel(title, active)）—— @Builder 按值传递，
   * 参数一旦是状态派生值，状态变化就不会引起标签刷新（发现页筛选 chips 曾因此高亮失灵）。
   * 这里保留直读写法，是因为 tabBar 只接受 CustomBuilder，无法直接放自定义组件用 @Prop 绑定。
   * 同理，新增标签时 index 必须与 TabContent 的先后顺序一致。
   */
  @Builder
  TabLabel(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? '#6D4C41' : '#77635C')
        .accessibilitySelected(this.currentIndex === index)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }
}
