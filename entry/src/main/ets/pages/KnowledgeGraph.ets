/**
 * 知识图谱页（C1.2 主题聚合 + C1.4 图谱交互重构）：文化主题聚合 + 个人知识库构建
 *
 * 职责：页面状态管理 + 业务数据组装 + UI 布局；
 * 图模型与布局在 components/graph/GraphLayout.ets（纯函数），Canvas 绘制与手势在 GraphCanvas.ets。
 *
 * C1.4 交互设计（参考 relation-graph / Trilium Notes / Obsidian）：
 * - 画布：点按节点选中并展示信息卡；点按空白取消；拖动空白平移；拖动节点移动；双指缩放；
 * - 编码：实心=已归类、空心=拓展推荐、细曲线=同类关联（同年代/同城市）；
 * - 推荐：聚合主题下所有遗址的相似推荐，排除全部已收藏条目（「拓展」= 发现新遗址）；
 * - 空主题：也可重命名/删除（修复 O10）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Heritage } from '../model/Heritage';
import { Favorite } from '../model/Favorite';
import { Theme, getThemeColor } from '../model/Theme';
import { HeritageRepository, HeritageLoadResult } from '../data/HeritageRepository';
import { FavoriteService } from '../service/FavoriteService';
import { ThemeService } from '../service/ThemeService';
import { buildThemeRecommendations } from '../utils/ThemeRecommendation';
import { getEraTheme } from '../utils/EraTheme';
import { GraphNodeKind } from '../components/graph/GraphNode';
import { GraphCanvas } from '../components/graph/GraphCanvas';
import { NodeInfoPanel } from '../components/graph/NodeInfoPanel';
import { findBestAnchor, buildRecommendReason } from '../components/graph/GraphLayout';
import { HeritageCard } from '../components/graph/HeritageCard';
import { ThemeEditorSheet } from '../components/graph/ThemeEditorSheet';
import { ManageSheet } from '../components/graph/ManageSheet';
import { ConfirmDeleteSheet } from '../components/graph/ConfirmDeleteSheet';
import { ThemeTokens } from '../utils/ThemeTokens';
import { RouterUtil } from '../utils/RouterUtil';

const DOMAIN = 0x0000;
const TAG = 'KnowledgeGraph';
const MAX_RECOMMEND: number = 5;

/** 弹层类型 */
enum SheetType {
  None,
  ThemeEditor,
  Manage,
  ConfirmDelete
}

@Component
export struct KnowledgeGraph {
  // ==================== 数据状态 ====================
  @State themes: Theme[] = [];
  @State selectedThemeId: string = '';
  @State themedHeritages: Heritage[] = [];
  @State recommendations: Heritage[] = [];
  @State favorites: Favorite[] = [];
  @State isLoading: boolean = true;
  @State isMockData: boolean = false;

  // ==================== 图谱交互状态 ====================
  /** 显示同类关联线（同年代/同城市） */
  @State showAffinity: boolean = true;
  /** 在图谱中显示拓展推荐节点（默认关闭，保持主图清晰） */
  @State showRecommendInGraph: boolean = false;
  /** 当前选中的节点业务 id */
  @State selectedNodeId: string = '';
  /** 当前选中的节点种类 */
  @State selectedNodeKind: GraphNodeKind = GraphNodeKind.NONE;
  /** 图数据版本：触发 Canvas 重新读取数据；是否重建布局由内容签名决定 */
  @State graphVersion: number = 0;
  /** 画布高度（按屏幕宽度自适应：手机 360vp、平板最高 520vp） */
  @State graphHeight: number = 360;

  // ==================== 弹层状态 ====================
  @State sheetType: SheetType = SheetType.None;
  @State themeEditorMode: boolean = false;
  @State themeNameInput: string = '';
  @State themeColorIndex: number = 0;
  @State manageIncluded: Heritage[] = [];
  @State manageAvailable: Heritage[] = [];

  /** 预置遗产映射表与全量列表 */
  private heritageMap: Map<string, Heritage> = new Map();
  private allHeritage: Heritage[] = [];

  // ==================== 信息卡滚动定位（M8） ====================
  /** 页面纵向滚动控制器 */
  private pageScroller: Scroller = new Scroller();
  /** 信息卡在滚动内容中的纵向位置（vp，父容器坐标系；0 = 尚未测量） */
  private infoCardTop: number = 0;
  /** 滚动视口高度（vp；0 = 尚未测量） */
  private scrollViewportHeight: number = 0;
  /** 首次布局测量完成后需要补做一次滚动 */
  private revealPending: boolean = false;

  // ==================== 推荐节点收藏并归类（M9） ====================
  /** 收藏 + 归类期间暂挂收藏订阅，结束后统一刷新一次（M6.10 单通道约定） */
  private addingRecommend: boolean = false;

  /** 主题变化处理器 */
  private themeChangedHandler: () => void = (): void => {
    this.loadThemes();
  };
  /** 收藏变化处理器（M9：推荐节点收藏并归类期间暂挂，见 addRecommendToTheme） */
  private favChangedHandler: () => void = (): void => {
    if (this.addingRecommend) {
      return;
    }
    this.refreshSelected();
  };

  aboutToAppear(): void {
    this.updateGraphHeight();
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      hilog.error(DOMAIN, TAG, 'host context unavailable');
      this.isLoading = false;
      this.loadThemes();
      return;
    }
    FavoriteService.init(context);
    ThemeService.init(context);
    ThemeService.onDataChanged(this.themeChangedHandler);
    FavoriteService.onDataChanged(this.favChangedHandler);
    this.loadHeritages(context);
  }

  aboutToDisappear(): void {
    ThemeService.offDataChanged(this.themeChangedHandler);
    FavoriteService.offDataChanged(this.favChangedHandler);
  }

  /** 画布高度自适应：按屏幕宽度计算，平板获得更大的图谱区（失败时保持 360vp） */
  private updateGraphHeight(): void {
    try {
      const widthPx: number = display.getDefaultDisplaySync().width;
      const widthVp: number = this.getUIContext().px2vp(widthPx);
      const next: number = Math.min(520, Math.max(360, (widthVp - 32) * 0.92));
      this.graphHeight = Math.round(next);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'compute graph height failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 加载预置遗产数据构建映射表（M4：repository 统一加载并缓存 id 映射） */
  private async loadHeritages(context: common.Context): Promise<void> {
    const result: HeritageLoadResult = await HeritageRepository.load(context);
    this.heritageMap = result.byId;
    this.allHeritage = result.list;
    this.isMockData = result.isMock;
    this.isLoading = false;
    this.loadThemes();
  }

  /** 从 ThemeService 加载主题 */
  private loadThemes(): void {
    const themes: Theme[] = ThemeService.getAllThemes();
    this.themes = themes;
    if (this.selectedThemeId === '') {
      if (themes.length > 0) {
        this.selectedThemeId = themes[0].id;
        this.clearSelection();
      }
    } else if (!this.containsTheme(themes, this.selectedThemeId)) {
      this.selectedThemeId = themes.length > 0 ? themes[0].id : '';
      this.clearSelection();
    }
    this.refreshSelected();
  }

  private containsTheme(themes: Theme[], id: string): boolean {
    for (let i = 0; i < themes.length; i++) {
      if (themes[i].id === id) {
        return true;
      }
    }
    return false;
  }

  /** 重建选中主题下的图谱数据；selection 失效时自动清除 */
  private refreshSelected(): void {
    const favs: Favorite[] = FavoriteService.getFavoritesByTheme(this.selectedThemeId);
    const hers: Heritage[] = [];
    for (let i = 0; i < favs.length; i++) {
      const h: Heritage | undefined = this.heritageMap.get(favs[i].itemId);
      if (h !== undefined) {
        hers.push(h);
      }
    }
    this.themedHeritages = hers;
    this.favorites = FavoriteService.getAllFavorites();
    this.refreshRecommendations();
    this.syncSelection();
    this.graphVersion += 1;
  }

  /** 选择主题 */
  private selectTheme(id: string): void {
    if (this.selectedThemeId === id) {
      return;
    }
    this.selectedThemeId = id;
    this.clearSelection();
    this.refreshSelected();
  }

  /** 拓展推荐：规则与去重逻辑在 utils/ThemeRecommendation（纯函数），页面只同步结果 */
  private refreshRecommendations(): void {
    this.recommendations = buildThemeRecommendations(this.allHeritage, this.themedHeritages,
      this.favorites, MAX_RECOMMEND);
  }

  private containsHeritage(list: Heritage[], id: string): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return true;
      }
    }
    return false;
  }

  // ==================== 图谱选中 ====================

  private handleNodeSelect(itemId: string, kind: GraphNodeKind): void {
    if (itemId === '' || kind === GraphNodeKind.NONE) {
      this.clearSelection();
      return;
    }
    this.selectedNodeId = itemId;
    this.selectedNodeKind = kind;
    this.revealInfoCard();
  }

  /**
   * M8：把选中节点的信息卡滚入视野（手机首屏下方卡片此前需要手动下滑）。
   * 信息卡已在视口内时不滚动，避免连续点选节点时画布被反复推走；
   * 首次渲染尚未测量到位置时挂起，等 onAreaChange 回调后再滚。
   */
  private revealInfoCard(): void {
    if (this.infoCardTop <= 0) {
      this.revealPending = true;
      return;
    }
    try {
      const offset: OffsetResult = this.pageScroller.currentOffset();
      const visibleTop: number = offset.yOffset + 8;
      const visibleBottom: number = offset.yOffset + this.scrollViewportHeight - 48;
      if (this.scrollViewportHeight > 0 && this.infoCardTop >= visibleTop &&
        this.infoCardTop <= visibleBottom) {
        return;
      }
      this.pageScroller.scrollTo({
        xOffset: 0,
        yOffset: Math.max(0, this.infoCardTop - 12),
        animation: { duration: 240, curve: Curve.EaseOut }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'reveal info card failed: %{public}s', JSON.stringify(err));
    }
  }

  private clearSelection(): void {
    this.selectedNodeId = '';
    this.selectedNodeKind = GraphNodeKind.NONE;
  }

  /** 数据变化后校验选中项是否还存在（被移出主题 / 推荐消失 / 切换主题） */
  private syncSelection(): void {
    if (this.selectedNodeKind === GraphNodeKind.NONE) {
      return;
    }
    if (this.selectedNodeKind === GraphNodeKind.THEME) {
      if (this.selectedNodeId !== this.selectedThemeId) {
        this.clearSelection();
      }
    } else if (this.selectedNodeKind === GraphNodeKind.HERITAGE) {
      if (!this.containsHeritage(this.themedHeritages, this.selectedNodeId)) {
        this.clearSelection();
      }
    } else if (this.selectedNodeKind === GraphNodeKind.RECOMMEND) {
      if (!this.containsHeritage(this.recommendations, this.selectedNodeId)) {
        this.clearSelection();
      }
    }
  }

  /** 当前选中遗址（主题选中或未选中返回 null） */
  private findSelectedHeritage(): Heritage | null {
    if (this.selectedNodeKind === GraphNodeKind.HERITAGE) {
      for (let i = 0; i < this.themedHeritages.length; i++) {
        if (this.themedHeritages[i].id === this.selectedNodeId) {
          return this.themedHeritages[i];
        }
      }
    } else if (this.selectedNodeKind === GraphNodeKind.RECOMMEND) {
      for (let i = 0; i < this.recommendations.length; i++) {
        if (this.recommendations[i].id === this.selectedNodeId) {
          return this.recommendations[i];
        }
      }
    }
    return null;
  }

  private selectedNodeTitle(): string {
    if (this.selectedNodeKind === GraphNodeKind.THEME) {
      return this.selectedThemeName();
    }
    const heritage: Heritage | null = this.findSelectedHeritage();
    return heritage === null ? '' : heritage.name;
  }

  private selectedNodeColor(): string {
    if (this.selectedNodeKind === GraphNodeKind.THEME) {
      const theme: Theme | null = this.selectedTheme();
      return theme === null ? ThemeTokens.ACCENT_FALLBACK : getThemeColor(theme.colorIndex);
    }
    const heritage: Heritage | null = this.findSelectedHeritage();
    return heritage === null ? ThemeTokens.ACCENT_FALLBACK : getEraTheme(heritage.era).deep;
  }

  private selectedHeritageMeta(): string {
    const heritage: Heritage | null = this.findSelectedHeritage();
    if (heritage === null) {
      return '';
    }
    return `${heritage.era} · ${heritage.type} · ${heritage.city}`;
  }

  private selectedHeritageSummary(): string {
    const heritage: Heritage | null = this.findSelectedHeritage();
    return heritage === null ? '' : heritage.summary;
  }

  /** 选中节点类型徽标：区分主题 / 已归类 / 拓展推荐 */
  private selectedNodeKindLabel(): string {
    if (this.selectedNodeKind === GraphNodeKind.THEME) {
      return '主题';
    }
    if (this.selectedNodeKind === GraphNodeKind.HERITAGE) {
      return '已归类';
    }
    if (this.selectedNodeKind === GraphNodeKind.RECOMMEND) {
      return '拓展推荐';
    }
    return '';
  }

  /** 选中遗址的核心看点（最多 2 条，无则空串） */
  private selectedHeritageHighlights(): string {
    const heritage: Heritage | null = this.findSelectedHeritage();
    if (heritage === null) {
      return '';
    }
    const highlights: string[] = heritage.detail.highlights;
    if (highlights.length === 0) {
      return '';
    }
    let text: string = '';
    const limit: number = Math.min(2, highlights.length);
    for (let i = 0; i < limit; i++) {
      if (i > 0) {
        text += ' · ';
      }
      text += highlights[i];
    }
    return text;
  }

  /** 推荐依据：与图上虚线的锚点同源，解释「为什么推荐」 */
  private selectedRecommendationReason(): string {
    if (this.selectedNodeKind !== GraphNodeKind.RECOMMEND) {
      return '';
    }
    const recommendation: Heritage | null = this.findSelectedHeritage();
    if (recommendation === null) {
      return '';
    }
    const anchor: Heritage | null = findBestAnchor(recommendation, this.themedHeritages);
    if (anchor === null) {
      return '';
    }
    return buildRecommendReason(recommendation, anchor);
  }

  /** 主题覆盖：已归类遗址数 + 年代数 + 城市数（仅主题节点需要） */
  private themeCoverageText(): string {
    if (this.selectedNodeKind !== GraphNodeKind.THEME) {
      return '';
    }
    const eras: string[] = [];
    const cities: string[] = [];
    for (let i = 0; i < this.themedHeritages.length; i++) {
      const heritage: Heritage = this.themedHeritages[i];
      if (eras.indexOf(heritage.era) < 0) {
        eras.push(heritage.era);
      }
      if (cities.indexOf(heritage.city) < 0) {
        cities.push(heritage.city);
      }
    }
    return `${this.themedHeritages.length} 处遗址 · ${eras.length} 个年代 · ${cities.length} 座城市`;
  }

  /** 推荐图层开关：关闭时同步清除已选推荐节点，避免信息卡指向已不存在的节点 */
  private toggleRecommendLayer(): void {
    this.showRecommendInGraph = !this.showRecommendInGraph;
    if (!this.showRecommendInGraph && this.selectedNodeKind === GraphNodeKind.RECOMMEND) {
      this.clearSelection();
    }
  }

  /** 选中遗址移出当前主题（不影响收藏本身） */
  private removeSelectedFromTheme(): void {
    if (this.selectedNodeKind !== GraphNodeKind.HERITAGE || this.selectedNodeId === '') {
      return;
    }
    this.removeFromTheme(this.selectedNodeId);
    this.clearSelection();
  }

  /**
   * M9：拓展推荐节点一键「收藏并归入当前主题」。
   * 推荐节点按定义不在收藏中；收藏与归类两次服务写入在同一交互内完成，
   * 期间用 addingRecommend 暂挂收藏订阅，结束后 refreshSelected 整体刷新一次。
   * 成功后选中项由「拓展推荐」切到「已归类」，信息卡与图谱即时更新（闭环）。
   */
  private addRecommendToTheme(): void {
    if (this.selectedNodeKind !== GraphNodeKind.RECOMMEND || this.selectedNodeId === '' ||
      this.selectedThemeId === '') {
      return;
    }
    const itemId: string = this.selectedNodeId;
    const themeId: string = this.selectedThemeId;
    this.addingRecommend = true;
    try {
      if (!FavoriteService.isFavorite(itemId)) {
        FavoriteService.addFavorite(itemId, []);
      }
      const fav: Favorite | null = FavoriteService.getFavorite(itemId);
      if (fav !== null && fav.themeIds.indexOf(themeId) < 0) {
        const next: string[] = fav.themeIds.slice();
        next.push(themeId);
        FavoriteService.updateFavoriteThemes(itemId, next);
      }
    } finally {
      this.addingRecommend = false;
    }
    // 归类成功后该条目已从推荐列表移除并进入当前主题：切换选中种类保持信息卡可见
    this.selectedNodeKind = GraphNodeKind.HERITAGE;
    this.refreshSelected();
  }

  // ==================== 主题操作 ====================

  private openCreateTheme(): void {
    this.themeEditorMode = false;
    this.themeNameInput = '';
    this.themeColorIndex = 0;
    this.sheetType = SheetType.ThemeEditor;
  }

  private openRenameTheme(): void {
    this.themeEditorMode = true;
    this.themeNameInput = this.selectedThemeName();
    this.themeColorIndex = this.selectedThemeColor();
    this.sheetType = SheetType.ThemeEditor;
  }

  private selectedTheme(): Theme | null {
    for (let i = 0; i < this.themes.length; i++) {
      if (this.themes[i].id === this.selectedThemeId) {
        return this.themes[i];
      }
    }
    return null;
  }

  private selectedThemeName(): string {
    const theme: Theme | null = this.selectedTheme();
    return theme === null ? '' : theme.name;
  }

  private selectedThemeColor(): number {
    const theme: Theme | null = this.selectedTheme();
    return theme === null ? 0 : theme.colorIndex;
  }

  /** @return false=名称重复等原因未保存，弹层保持打开并显示错误 */
  private saveTheme(name: string, colorIndex: number): boolean {
    if (this.themeEditorMode) {
      const renamed: boolean = ThemeService.renameTheme(this.selectedThemeId, name, colorIndex);
      if (!renamed) {
        return false;
      }
    } else {
      const created: Theme | null = ThemeService.addTheme(name, colorIndex);
      if (created === null) {
        return false;
      }
      this.selectedThemeId = created.id;
      this.clearSelection();
    }
    this.closeSheet();
    this.loadThemes();
    return true;
  }

  private openDeleteConfirm(): void {
    this.sheetType = SheetType.ConfirmDelete;
  }

  private confirmDeleteTheme(): void {
    ThemeService.removeTheme(this.selectedThemeId);
    this.closeSheet();
    this.clearSelection();
    this.loadThemes();
  }

  // ==================== 归类管理 ====================

  private openManage(): void {
    this.rebuildManage();
    this.sheetType = SheetType.Manage;
  }

  private rebuildManage(): void {
    const included: Heritage[] = this.themedHeritages.slice();
    const available: Heritage[] = [];
    const favs: Favorite[] = this.favorites;
    for (let i = 0; i < favs.length; i++) {
      if (this.containsHeritage(included, favs[i].itemId)) {
        continue;
      }
      const h: Heritage | undefined = this.heritageMap.get(favs[i].itemId);
      if (h !== undefined) {
        available.push(h);
      }
    }
    this.manageIncluded = included;
    this.manageAvailable = available;
  }

  private removeFromTheme(itemId: string): void {
    const fav: Favorite | null = FavoriteService.getFavorite(itemId);
    if (fav === null) {
      return;
    }
    const next: string[] = [];
    for (let i = 0; i < fav.themeIds.length; i++) {
      if (fav.themeIds[i] !== this.selectedThemeId) {
        next.push(fav.themeIds[i]);
      }
    }
    FavoriteService.updateFavoriteThemes(itemId, next);
    // M6.10：图谱数据由 FavoriteService.onDataChanged 单通道刷新，这里只重建弹层候选。
    this.rebuildManage();
  }

  private addToTheme(itemId: string): void {
    const fav: Favorite | null = FavoriteService.getFavorite(itemId);
    if (fav === null) {
      return;
    }
    const next: string[] = fav.themeIds.slice();
    next.push(this.selectedThemeId);
    FavoriteService.updateFavoriteThemes(itemId, next);
    // M6.10：图谱数据由 FavoriteService.onDataChanged 单通道刷新，这里只重建弹层候选。
    this.rebuildManage();
  }

  private closeSheet(): void {
    this.sheetType = SheetType.None;
    this.themeNameInput = '';
  }

  // ==================== 跳转 ====================

  private openDetail(heritageId: string): void {
    RouterUtil.push('pages/Detail', { id: heritageId });
  }

  // ==================== UI ====================

  /** 主题操作行（有主题就显示；空主题也可重命名/删除，O10 修复） */
  @Builder
  themeActionRow() {
    Row({ space: 10 }) {
      Button('归类管理')
        .fontSize(13)
        .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
        .backgroundColor(ThemeTokens.PRIMARY)
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.openManage();
        })
      Button('编辑主题')
        .fontSize(13)
        .fontColor(ThemeTokens.PRIMARY)
        .backgroundColor(ThemeTokens.BG_SOFT)
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.openRenameTheme();
        })
      Button('删除主题')
        .fontSize(13)
        .fontColor(ThemeTokens.DANGER)
        .backgroundColor(ThemeTokens.BG_DANGER_SOFT)
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.openDeleteConfirm();
        })
    }
    .width('100%')
    .margin({ top: 12 })
  }

  build() {
    Stack() {
      Column() {
        // 顶部标题栏
        Row() {
          Text('知识图谱')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
          Blank()
          Text(`${this.themes.length} 个主题`)
            .fontSize(13)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(ThemeTokens.ACCENT_MUTED)
            Text('正在构建知识库…')
              .fontSize(14)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .margin({ top: 12 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else if (this.themes.length === 0) {
          // 空态：无主题
          Column() {
            Text('还没有文化主题')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.PRIMARY)
            Text('创建主题（如「彩陶文化」「青铜文明」），再归入收藏的遗址')
              .fontSize(13)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .margin({ top: 8 })
              .textAlign(TextAlign.Center)
            Button('新建主题')
              .fontSize(14)
              .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ThemeTokens.PRIMARY)
              .height(44)
              .margin({ top: 16 })
              .onClick(() => {
                this.openCreateTheme();
              })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 32, right: 32 })
        } else {
          // mock 示例数据提示条
          if (this.isMockData) {
            Row() {
              Text('示例数据 · 预览调试专用（rawfile 加载失败）')
                .fontSize(12)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .backgroundColor(ThemeTokens.BG_WARNING)
                .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ bottom: 10 })
          }

          Scroll(this.pageScroller) {
            Column() {
              // 主题 chips
              Scroll() {
                Row() {
                  ForEach(this.themes, (theme: Theme) => {
                    Row() {
                      Text(theme.name)
                        .fontSize(13)
                        .fontColor(this.selectedThemeId === theme.id ? ThemeTokens.TEXT_ON_PRIMARY : ThemeTokens.PRIMARY)
                    }
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                    .constraintSize({ minHeight: 44 })
                    .backgroundColor(this.selectedThemeId === theme.id ? getThemeColor(theme.colorIndex) : ThemeTokens.BG_CARD)
                    .borderRadius(16)
                    .border({
                      width: 1,
                      color: this.selectedThemeId === theme.id ? getThemeColor(theme.colorIndex) : ThemeTokens.BORDER
                    })
                    .margin({ right: 8 })
                    .accessibilitySelected(this.selectedThemeId === theme.id)
                    .onClick(() => {
                      this.selectTheme(theme.id);
                    })
                  }, (theme: Theme) => theme.id)
                  Row() {
                    Text('＋ 新建')
                      .fontSize(13)
                      .fontColor(ThemeTokens.DANGER)
                  }
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .constraintSize({ minHeight: 44 })
                  .backgroundColor(ThemeTokens.BG_CARD)
                  .borderRadius(16)
                  .border({ width: 1, color: ThemeTokens.BORDER })
                  .onClick(() => {
                    this.openCreateTheme();
                  })
                }
                .width('100%')
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')

              // 图谱标题 + 图层开关
              if (this.selectedThemeId !== '') {
                Row() {
                  Text('知识网络')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ThemeTokens.TEXT_PRIMARY)
                  Blank()
                  Row() {
                    Text('同类关联')
                      .fontSize(12)
                      .fontColor(this.showAffinity ? ThemeTokens.TEXT_PRIMARY : ThemeTokens.TEXT_SECONDARY)
                  }
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .constraintSize({ minHeight: 44 })
                  .backgroundColor(this.showAffinity ? ThemeTokens.BG_SOFT : ThemeTokens.BG_CARD)
                  .borderRadius(14)
                  .border({ width: 1, color: this.showAffinity ? ThemeTokens.BORDER_STRONG : ThemeTokens.BORDER })
                  .accessibilitySelected(this.showAffinity)
                  .onClick(() => {
                    this.showAffinity = !this.showAffinity;
                  })
                  if (this.recommendations.length > 0) {
                    Row() {
                      Text('拓展推荐')
                        .fontSize(12)
                        .fontColor(this.showRecommendInGraph ? ThemeTokens.TEXT_PRIMARY : ThemeTokens.TEXT_SECONDARY)
                    }
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .constraintSize({ minHeight: 44 })
                    .backgroundColor(this.showRecommendInGraph ? ThemeTokens.BG_SOFT : ThemeTokens.BG_CARD)
                    .borderRadius(14)
                    .border({ width: 1, color: this.showRecommendInGraph ? ThemeTokens.BORDER_STRONG : ThemeTokens.BORDER })
                    .margin({ left: 8 })
                    .accessibilitySelected(this.showRecommendInGraph)
                    .onClick(() => {
                      this.toggleRecommendLayer();
                    })
                  }
                }
                .width('100%')
                .margin({ top: 12 })
              }

              // 知识图谱画布区域
              Column() {
                GraphCanvas({
                  theme: this.selectedTheme(),
                  heritages: this.themedHeritages,
                  recommendations: this.recommendations,
                  showAffinity: this.showAffinity,
                  showRecommend: this.showRecommendInGraph,
                  selectedId: this.selectedNodeId,
                  graphVersion: this.graphVersion,
                  onSelect: (itemId: string, kind: GraphNodeKind) => {
                    this.handleNodeSelect(itemId, kind);
                  }
                })
              }
              .width('100%')
              .height(this.graphHeight)
              .backgroundColor(ThemeTokens.BG_CANVAS)
              .borderRadius(16)
              .clip(true)
              .margin({ top: 10 })
              .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 })

              Text(this.showRecommendInGraph
                ? '实心=已归类 · 空心=拓展推荐 · 双指缩放查看'
                : '点按节点查看 · 拖动平移 · 双指缩放 · 拖动节点可调整位置')
                .fontSize(11)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 8 })

              if (this.selectedThemeId === '') {
                Text('请选择或新建一个主题')
                  .fontSize(13)
                  .fontColor(ThemeTokens.TEXT_SECONDARY)
                  .margin({ top: 24 })
              } else {
                // 选中节点信息卡（展示值与回调传入独立组件，页面不承载信息卡 UI）
                if (this.selectedNodeKind !== GraphNodeKind.NONE) {
                  // M8：外层包裹仅用于测量信息卡在滚动内容中的位置，不改变卡片视觉
                  Column() {
                    NodeInfoPanel({
                      kind: this.selectedNodeKind,
                      title: this.selectedNodeTitle(),
                      nodeColor: this.selectedNodeColor(),
                      kindLabel: this.selectedNodeKindLabel(),
                      coverage: this.themeCoverageText(),
                      meta: this.selectedHeritageMeta(),
                      summary: this.selectedHeritageSummary(),
                      highlights: this.selectedHeritageHighlights(),
                      reason: this.selectedRecommendationReason(),
                      onClose: () => {
                        this.clearSelection();
                      },
                      onOpenManage: () => {
                        this.openManage();
                      },
                      onOpenDetail: () => {
                        this.openDetail(this.selectedNodeId);
                      },
                      onRemove: () => {
                        this.removeSelectedFromTheme();
                      },
                      onAddToTheme: () => {
                        this.addRecommendToTheme();
                      }
                    })
                  }
                  .width('100%')
                  .onAreaChange((_oldArea: Area, newArea: Area) => {
                    const cardTop: Length | undefined = newArea.position.y;
                    if (typeof cardTop === 'number') {
                      this.infoCardTop = cardTop;
                    }
                    if (this.revealPending) {
                      this.revealPending = false;
                      this.revealInfoCard();
                    }
                  })
                }

                // 主题操作行：空主题也可重命名/删除
                this.themeActionRow()

                if (this.themedHeritages.length === 0) {
                  // 空态：主题下无归类
                  Column() {
                    Text('该主题下还没有收藏的遗址')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ThemeTokens.PRIMARY)
                    Text('点击「归类管理」把已收藏的遗址归入这个主题')
                      .fontSize(13)
                      .fontColor(ThemeTokens.TEXT_SECONDARY)
                      .margin({ top: 6 })
                  }
                  .width('100%')
                  .padding(20)
                  .backgroundColor(ThemeTokens.BG_CARD)
                  .borderRadius(16)
                  .margin({ top: 12 })
                  .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 })
                } else {
                  // 已归类遗址
                  Row() {
                    Text('主题下已归类')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ThemeTokens.TEXT_PRIMARY)
                    Blank()
                    Text(`${this.themedHeritages.length} 处`)
                      .fontSize(12)
                      .fontColor(ThemeTokens.TEXT_SECONDARY)
                  }
                  .width('100%')
                  .margin({ top: 16 })

                  Scroll() {
                    Row() {
                      ForEach(this.themedHeritages, (h: Heritage) => {
                        HeritageCard({ heritage: h, onTap: () => {
                          this.openDetail(h.id);
                        } })
                      }, (h: Heritage) => h.id)
                    }
                    .alignItems(VerticalAlign.Top)
                    .padding({ top: 10 })
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .edgeEffect(EdgeEffect.Spring)
                  .width('100%')
                  .height(128)

                  // 拓展推荐
                  if (this.recommendations.length > 0) {
                    Row() {
                      Text('基于此主题的拓展推荐')
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(ThemeTokens.TEXT_PRIMARY)
                    }
                    .width('100%')
                    .margin({ top: 16 })

                    Scroll() {
                      Row() {
                        ForEach(this.recommendations, (h: Heritage) => {
                          HeritageCard({ heritage: h, onTap: () => {
                            this.openDetail(h.id);
                          } })
                        }, (h: Heritage) => h.id)
                      }
                      .alignItems(VerticalAlign.Top)
                      .padding({ top: 10 })
                    }
                    .scrollable(ScrollDirection.Horizontal)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                    .width('100%')
                    .height(128)
                  }
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const height: Length = newArea.height;
            if (typeof height === 'number') {
              this.scrollViewportHeight = height;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.BG_PAGE)

      // 弹层
      if (this.sheetType !== SheetType.None) {
        Column() {
          if (this.sheetType === SheetType.ThemeEditor) {
            ThemeEditorSheet({
              isRename: this.themeEditorMode,
              initialName: this.themeNameInput,
              initialColorIndex: this.themeColorIndex,
              onSave: (name: string, colorIndex: number) => {
                return this.saveTheme(name, colorIndex);
              },
              onCancel: () => {
                this.closeSheet();
              }
            })
          } else if (this.sheetType === SheetType.Manage) {
            ManageSheet({
              themeName: this.selectedThemeName(),
              included: this.manageIncluded,
              available: this.manageAvailable,
              onRemove: (itemId: string) => {
                this.removeFromTheme(itemId);
              },
              onAdd: (itemId: string) => {
                this.addToTheme(itemId);
              },
              onDone: () => {
                this.closeSheet();
              }
            })
          } else {
            ConfirmDeleteSheet({
              themeName: this.selectedThemeName(),
              onConfirm: () => {
                this.confirmDeleteTheme();
              },
              onCancel: () => {
                this.closeSheet();
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(62,39,35,0.45)')
        .onClick(() => {
          // 消费点击防穿透
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
