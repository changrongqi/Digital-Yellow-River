/**
 * 主页（M1.3）：Tabs 容器
 * - 发现：Discovery（rawfile 数据列表）
 * - 收藏：Favorites（M2.2 收藏列表，按标签分组）
 * - 同步：SyncPanel（M3.3 分布式同步状态面板）
 * - 图谱：KnowledgeGraph（C1.2 文化主题聚合 + 知识节点网络可视化）
 */

import { Discovery } from './Discovery';
import { Favorites } from './Favorites';
import { SyncPanel } from './SyncPanel';
import { KnowledgeGraph } from './KnowledgeGraph';
import { FavoriteService } from '../service/FavoriteService';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  /** 收藏页刷新信号：onPageShow（含从详情页返回）时 +1，经 @Prop @Watch 驱动 Favorites 重载数据 */
  @State favoriteRefreshTick: number = 0;

  aboutToAppear(): void {
    // 提前初始化用户数据服务（幂等）：注册 SyncService 远端变更合并处理器，
    // 避免 TabContent 懒加载导致收藏 Tab 未打开时远端变更无人合并（M3.2）
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      FavoriteService.init(context);
    }
    // 用户数据变化（本地 CRUD 与远端 LWW 合并后均会触发）→ 刷新收藏页（M3.2 列表联动）
    FavoriteService.onDataChanged(() => {
      this.favoriteRefreshTick += 1;
    });
  }

  /**
   * 页面重新显示（含从详情页收藏/取消收藏后返回）：通知收藏页刷新列表（M2.4 列表联动）。
   * 收藏 Tab 的 aboutToAppear 只在首次构建时执行一次，若不做此联动，
   * 从详情页返回后收藏页不会感知 FavoriteService 的数据变化。
   */
  onPageShow(): void {
    this.favoriteRefreshTick += 1;
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Discovery()
      }
      .tabBar(this.TabLabel('发现', 0))

      TabContent() {
        Favorites({ refreshTick: this.favoriteRefreshTick })
      }
      .tabBar(this.TabLabel('收藏', 1))

      TabContent() {
        SyncPanel()
      }
      .tabBar(this.TabLabel('同步', 2))

      TabContent() {
        KnowledgeGraph({ refreshTick: this.favoriteRefreshTick })
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
        .fontColor(this.currentIndex === index ? '#6D4C41' : '#BCAAA4')
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }
}
