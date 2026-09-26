/**
 * 知识图谱页（C1.2）：文化主题聚合 + 个人知识库构建。
 *
 * 设计说明（计划书 M5 C1）：
 * - 主题是「文化脉络聚合」维度（如「彩陶文化」「青铜文明」），与 M2 收藏标签是两个维度；
 *   一个收藏可归入多个主题（Favorite.themeIds，多对多，归类写 FavoriteService）；
 * - UI 结构：主题 chips（选择/新建/重命名/删除）→ Canvas 知识节点网络
 *   （中心 = 选中主题、环绕 = 已归类遗址节点，圆周分布 + 连线，点击带 id 跳详情 O2）→
 *   归类管理（已归类移除 / 未归类收藏加入）→ 拓展推荐（该主题已收藏遗址的相似推荐，
 *   排除已收藏，复用 M4 utils/Recommendation 纯函数）；
 * - 知识节点网络用 ArkUI Canvas 绘制（API 12 CanvasRenderingContext2D，
 *   本机 SDK component/canvas.d.ts 双重核对：Canvas(context) + onReady/onAreaChange +
 *   arc/moveTo/lineTo/stroke/fill/fillText/textAlign 等）；绘制为命令式，主题/归类变化后
 *   手动重绘（不经 @Builder，规避踩坑 15）；命中测试用记录节点坐标，克制简洁不做 3D（用户偏好）；
 * - 数据流单一数据源：主题 = ThemeService、收藏 = FavoriteService（含 themeIds）；
 *   Heritage 预置数据用 HeritageDataLoader（预览器 mock 兜底，与发现/收藏页行为一致）；
 * - 空态兜底（工程惯例）：无主题引导新建 / 有主题无归类引导归类；
 * - 刷新时机：aboutToAppear 初始化 + ThemeService.onDataChanged（主题增删改/远端合并）
 *   + FavoriteService.onDataChanged（收藏变化与归类） + @Prop refreshTick（Index.onPageShow
 *   从详情返回后 +1，收藏切换联动）；刷新后整体赋值（踩坑 5）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Heritage } from '../model/Heritage';
import { Favorite } from '../model/Favorite';
import { Theme } from '../model/Theme';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { FavoriteService } from '../service/FavoriteService';
import { ThemeService } from '../service/ThemeService';
import { getEraTheme } from '../utils/EraTheme';
import { recommendHeritages } from '../utils/Recommendation';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'KnowledgeGraph';

/** 主题色板（colorIndex 取余兜底）：棕/红/绿/蓝/紫/橙 */
const THEME_PALETTE: string[] = ['#6D4C41', '#C0392B', '#2E7D32', '#1565C0', '#6A1B9A', '#EF6C00'];
/** 遗址节点半径 */
const NODE_RADIUS: number = 20;
/** 中心主题节点半径 */
const THEME_NODE_RADIUS: number = 34;
/** 拓展推荐条数 */
const MAX_RECOMMEND: number = 5;

/** 弹层类型 */
enum SheetType {
  None,
  ThemeEditor,   // 新建 / 重命名主题
  Manage,        // 归类管理
  ConfirmDelete
}

/** 图谱节点（Canvas 命中测试用） */
class GraphNode {
  id: string;
  label: string;
  x: number;
  y: number;
  r: number;

  constructor(id: string, label: string, x: number, y: number, r: number) {
    this.id = id;
    this.label = label;
    this.x = x;
    this.y = y;
    this.r = r;
  }
}

@Component
export struct KnowledgeGraph {
  // ==================== 数据状态 ====================
  @State themes: Theme[] = [];
  @State selectedThemeId: string = '';
  /** 选中主题下的已归类遗址 */
  @State themedHeritages: Heritage[] = [];
  /** 拓展推荐（横向卡片） */
  @State recommendations: Heritage[] = [];
  /** 全部收藏（归类管理数据源） */
  @State favorites: Favorite[] = [];
  @State isLoading: boolean = true;
  @State isMockData: boolean = false;

  // ==================== 弹层状态 ====================
  @State sheetType: SheetType = SheetType.None;
  /** 主题编辑器：true=重命名（编辑选中主题） */
  @State themeEditorMode: boolean = false;
  @State themeNameInput: string = '';
  @State themeColorIndex: number = 0;
  /** 归类管理：已归类（可移除）/ 未归类收藏（可加入） */
  @State manageIncluded: Heritage[] = [];
  @State manageAvailable: Heritage[] = [];

  // ==================== Canvas 绘制 ====================
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasW: number = 0;
  private canvasH: number = 0;
  private graphNodes: GraphNode[] = [];

  /** 预置遗产映射表与全量列表（只读；加载完成后构建） */
  private heritageMap: Map<string, Heritage> = new Map();
  private allHeritage: Heritage[] = [];

  /** 主题变化处理器（aboutToDisappear 注销） */
  private themeChangedHandler: () => void = (): void => {
    this.loadThemes();
  };
  /** 收藏变化处理器（归类/收藏切换后刷新图谱与推荐） */
  private favChangedHandler: () => void = (): void => {
    this.refreshSelected();
  };

  /**
   * 父页面刷新信号（Index.onPageShow 从详情返回后 +1，收藏切换联动；对齐 Favorites）。
   * @Watch 触发刷新；加载中不重复刷（loadHeritages 完成后自带一次 refreshSelected）。
   */
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;

  private onRefreshTick(): void {
    if (this.refreshTick > 0 && !this.isLoading) {
      this.refreshSelected();
    }
  }

  aboutToAppear(): void {
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

  /** 加载预置遗产数据构建映射表（进程内缓存；预览器失败注入 mock，与发现/收藏页一致） */
  private async loadHeritages(context: common.Context): Promise<void> {
    let list: Heritage[] = [];
    try {
      list = await HeritageDataLoader.loadHeritageList(context);
      this.isMockData = false;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'load heritages failed, fallback to mock: %{public}s', JSON.stringify(err));
      list = MOCK_HERITAGES;
      this.isMockData = true;
    }
    const map: Map<string, Heritage> = new Map();
    for (let i = 0; i < list.length; i++) {
      map.set(list[i].id, list[i]);
    }
    this.heritageMap = map;
    this.allHeritage = list;
    this.isLoading = false;
    this.loadThemes();
  }

  /** 从 ThemeService 加载主题（整体赋值），校验选中主题有效性并刷新图谱 */
  private loadThemes(): void {
    const themes: Theme[] = ThemeService.getAllThemes();
    this.themes = themes;
    if (this.selectedThemeId === '') {
      if (themes.length > 0) {
        this.selectedThemeId = themes[0].id;
      }
    } else if (!this.containsTheme(themes, this.selectedThemeId)) {
      // 选中主题已被删除/远端移除：回退到最新主题或空
      this.selectedThemeId = themes.length > 0 ? themes[0].id : '';
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

  /** 重建选中主题下的图谱数据（整体赋值，踩坑 5），并重绘 Canvas */
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
    this.drawGraph();
  }

  /** 选择主题 */
  private selectTheme(id: string): void {
    if (this.selectedThemeId === id) {
      return;
    }
    this.selectedThemeId = id;
    this.refreshSelected();
  }

  /** 拓展推荐：以选中主题第一个已归类遗址为锚，取相似推荐并排除已归类的 */
  private refreshRecommendations(): void {
    if (this.themedHeritages.length === 0 || this.allHeritage.length === 0) {
      this.recommendations = [];
      return;
    }
    const anchor: Heritage = this.themedHeritages[0];
    const favs: Favorite[] = FavoriteService.getAllFavorites();
    const favIds: string[] = [];
    for (let i = 0; i < favs.length; i++) {
      favIds.push(favs[i].itemId);
    }
    const recs: Heritage[] = recommendHeritages(this.allHeritage, anchor.id, favIds, 12);
    const result: Heritage[] = [];
    for (let i = 0; i < recs.length && result.length < MAX_RECOMMEND; i++) {
      if (!this.containsHeritage(this.themedHeritages, recs[i].id)) {
        result.push(recs[i]);
      }
    }
    this.recommendations = result;
  }

  private containsHeritage(list: Heritage[], id: string): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return true;
      }
    }
    return false;
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

  private saveTheme(): void {
    const name: string = this.themeNameInput.trim();
    if (name === '') {
      return;
    }
    if (this.themeEditorMode) {
      ThemeService.renameTheme(this.selectedThemeId, name);
    } else {
      const created: Theme | null = ThemeService.addTheme(name, this.themeColorIndex);
      if (created !== null) {
        this.selectedThemeId = created.id;
      }
    }
    this.themeNameInput = '';
    this.sheetType = SheetType.None;
    this.loadThemes();
  }

  private openDeleteConfirm(): void {
    this.sheetType = SheetType.ConfirmDelete;
  }

  private confirmDeleteTheme(): void {
    ThemeService.removeTheme(this.selectedThemeId);
    this.sheetType = SheetType.None;
    this.loadThemes();
  }

  // ==================== 归类管理 ====================

  /** 打开归类管理：重建「已归类 / 未归类」两个列表（整体赋值） */
  private openManage(): void {
    this.sheetType = SheetType.Manage;
    this.rebuildManage();
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
    this.rebuildManage();
    this.refreshSelected();
  }

  private addToTheme(itemId: string): void {
    const fav: Favorite | null = FavoriteService.getFavorite(itemId);
    if (fav === null) {
      return;
    }
    const next: string[] = fav.themeIds.slice();
    next.push(this.selectedThemeId);
    FavoriteService.updateFavoriteThemes(itemId, next);
    this.rebuildManage();
    this.refreshSelected();
  }

  private closeSheet(): void {
    this.sheetType = SheetType.None;
    this.themeNameInput = '';
  }

  // ==================== 跳转 ====================

  /** 打开遗址详情（统一带 id，O2 约定） */
  private openDetail(heritageId: string): void {
    try {
      router.pushUrl({ url: 'pages/Detail', params: { id: heritageId } });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open detail failed: %{public}s', JSON.stringify(err));
    }
  }

  // ==================== Canvas 知识节点网络 ====================

  /** 绘制知识节点网络（命令式重绘：主题/归类变化后手动调用） */
  private drawGraph(): void {
    if (this.canvasW <= 0 || this.canvasH <= 0) {
      return; // 等 onAreaChange 拿到实际尺寸后重绘
    }
    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = this.canvasW;
    const h: number = this.canvasH;
    ctx.clearRect(0, 0, w, h);
    this.graphNodes = [];
    const cx: number = w / 2;
    const cy: number = h / 2 - 8;

    // 中心主题节点
    const theme: Theme | null = this.selectedTheme();
    const themeColor: string = theme === null ? '#9E9E9E' : THEME_PALETTE[theme.colorIndex % THEME_PALETTE.length];
    ctx.beginPath();
    ctx.arc(cx, cy, THEME_NODE_RADIUS, 0, Math.PI * 2);
    ctx.fillStyle = themeColor;
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.textAlign = 'center';
    ctx.font = '13px sans-serif';
    ctx.fillText(theme === null ? '未选择' : theme.name, cx, cy + 4);
    ctx.font = '10px sans-serif';
    ctx.fillText(`${this.themedHeritages.length} 处`, cx, cy + 18);

    // 环绕遗址节点（圆周分布；N=1 时单点置右）
    const n: number = this.themedHeritages.length;
    if (n > 0) {
      const radius: number = Math.max(70, Math.min(w, h) / 2 - 56);
      for (let i = 0; i < n; i++) {
        const angle: number = (i / n) * Math.PI * 2 - Math.PI / 2;
        const x: number = cx + radius * Math.cos(angle);
        const y: number = cy + radius * Math.sin(angle);
        // 连线（中心 → 节点）
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(x, y);
        ctx.strokeStyle = '#D7CCC8';
        ctx.lineWidth = 1;
        ctx.stroke();
        // 节点圆（主题色软底 + 年代色描边，克制不做 3D）
        const h: Heritage = this.themedHeritages[i];
        ctx.beginPath();
        ctx.arc(x, y, NODE_RADIUS, 0, Math.PI * 2);
        ctx.fillStyle = getEraTheme(h.era).soft;
        ctx.fill();
        ctx.strokeStyle = getEraTheme(h.era).deep;
        ctx.lineWidth = 2;
        ctx.stroke();
        // 节点名称（节点下方）
        ctx.fillStyle = '#3E2723';
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(h.name, x, y + NODE_RADIUS + 12);
        this.graphNodes.push(new GraphNode(h.id, h.name, x, y, NODE_RADIUS));
      }
    }
  }

  /** Canvas 点击命中测试：落在遗址节点内 → 跳详情 */
  private handleCanvasTap(tx: number, ty: number): void {
    for (let i = 0; i < this.graphNodes.length; i++) {
      const node: GraphNode = this.graphNodes[i];
      const dx: number = tx - node.x;
      const dy: number = ty - node.y;
      const dist: number = Math.sqrt(dx * dx + dy * dy);
      if (dist <= node.r + 10) {
        this.openDetail(node.id);
        return;
      }
    }
  }

  private onCanvasArea(w: number, h: number): void {
    this.canvasW = w;
    this.canvasH = h;
    this.drawGraph();
  }

  // ==================== UI ====================

  build() {
    Stack() {
      Column() {
        // 顶部标题栏
        Row() {
          Text('知识图谱')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
          Blank()
          Text(`${this.themes.length} 个主题`)
            .fontSize(13)
            .fontColor('#8D6E63')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 12 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color('#A1887F')
            Text('正在构建知识库…')
              .fontSize(14)
              .fontColor('#8D6E63')
              .margin({ top: 12 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else if (this.themes.length === 0) {
          // 空态 1：无主题 → 引导新建
          Column() {
            Text('还没有文化主题')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6D4C41')
            Text('创建主题（如「彩陶文化」「青铜文明」），再归入收藏的遗址')
              .fontSize(13)
              .fontColor('#8D6E63')
              .margin({ top: 8 })
              .textAlign(TextAlign.Center)
            Button('新建主题')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#6D4C41')
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
          // mock 示例数据提示条（仅加载失败兜底时出现）
          if (this.isMockData) {
            Row() {
              Text('示例数据 · 预览调试专用（rawfile 加载失败）')
                .fontSize(12)
                .fontColor('#8D6E63')
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .backgroundColor('#FFF3E0')
                .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ bottom: 10 })
          }

          Scroll() {
            Column() {
              // 主题 chips（横向滚动；选中高亮直读 this.selectedThemeId，踩坑 15 合规）
              Scroll() {
                Row() {
                  ForEach(this.themes, (theme: Theme) => {
                    Row() {
                      Text(theme.name)
                        .fontSize(13)
                        .fontColor(this.selectedThemeId === theme.id ? '#FFFFFF' : '#6D4C41')
                    }
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                    .backgroundColor(this.selectedThemeId === theme.id ? '#6D4C41' : '#FFFFFF')
                    .borderRadius(16)
                    .border({ width: 1, color: this.selectedThemeId === theme.id ? '#6D4C41' : '#E0D6CC' })
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectTheme(theme.id);
                    })
                  }, (theme: Theme) => theme.id)
                  Row() {
                    Text('＋ 新建')
                      .fontSize(13)
                      .fontColor('#C0392B')
                  }
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(16)
                  .border({ width: 1, color: '#E0D6CC' })
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

              // 知识节点网络
              Column() {
                Canvas(this.context)
                  .width('100%')
                  .height(300)
                  .onReady(() => {
                    this.drawGraph();
                  })
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    const w: number = Number(newValue.width);
                    const h: number = Number(newValue.height);
                    if (!Number.isNaN(w) && !Number.isNaN(h) && w > 0 && h > 0) {
                      this.onCanvasArea(w, h);
                    }
                  })
                  .onClick((event: ClickEvent) => {
                    this.handleCanvasTap(event.x, event.y);
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ top: 12 })

              if (this.selectedThemeId === '') {
                // 空态 2：有主题但未选中（理论不可达，兜底）
                Text('请选择或新建一个主题')
                  .fontSize(13)
                  .fontColor('#8D6E63')
                  .margin({ top: 24 })
              } else if (this.themedHeritages.length === 0) {
                // 空态 3：主题下无归类 → 引导归类
                Column() {
                  Text('该主题下还没有收藏的遗址')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#6D4C41')
                  Text('点击「归类管理」把已收藏的遗址归入这个主题')
                    .fontSize(13)
                    .fontColor('#8D6E63')
                    .margin({ top: 6 })
                  Button('归类管理')
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#6D4C41')
                    .margin({ top: 14 })
                    .onClick(() => {
                      this.openManage();
                    })
                }
                .width('100%')
                .padding(20)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .margin({ top: 12 })
              } else {
                // 主题操作行 + 图谱 + 归类 + 拓展推荐
                Row({ space: 10 }) {
                  Button('归类管理')
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#6D4C41')
                    .layoutWeight(1)
                    .onClick(() => {
                      this.openManage();
                    })
                  Button('重命名')
                    .fontSize(13)
                    .fontColor('#6D4C41')
                    .backgroundColor('#EFEBE9')
                    .layoutWeight(1)
                    .onClick(() => {
                      this.openRenameTheme();
                    })
                  Button('删除主题')
                    .fontSize(13)
                    .fontColor('#C0392B')
                    .backgroundColor('#FDECEA')
                    .layoutWeight(1)
                    .onClick(() => {
                      this.openDeleteConfirm();
                    })
                }
                .width('100%')
                .margin({ top: 12 })

                // 已归类遗址（横向卡片，点击跳详情）
                Row() {
                  Text('主题下已归类')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#3E2723')
                  Blank()
                  Text(`${this.themedHeritages.length} 处`)
                    .fontSize(12)
                    .fontColor('#8D6E63')
                }
                .width('100%')
                .margin({ top: 16 })

                Scroll() {
                  Row() {
                    ForEach(this.themedHeritages, (h: Heritage) => {
                      this.ThemedCard(h)
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

                // 拓展推荐（基于知识结构的相似推荐，排除已收藏）
                if (this.recommendations.length > 0) {
                  Row() {
                    Text('基于此主题的拓展推荐')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#3E2723')
                  }
                  .width('100%')
                  .margin({ top: 16 })

                  Scroll() {
                    Row() {
                      ForEach(this.recommendations, (h: Heritage) => {
                        this.ThemedCard(h)
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
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FAF6F0')

      // 弹层：遮罩 + 对话框（一律经显式按钮关闭）
      if (this.sheetType !== SheetType.None) {
        Column() {
          if (this.sheetType === SheetType.ThemeEditor) {
            this.ThemeEditorSheet()
          } else if (this.sheetType === SheetType.Manage) {
            this.ManageSheet()
          } else {
            this.ConfirmDeleteSheet()
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(62,39,35,0.45)')
        .onClick(() => {
          // 空实现消费点击：防止穿透到主内容；不承担「点遮罩关闭」（子组件冒泡误关，同 Favorites）
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 遗址卡（已归类 / 拓展推荐共用；内容静态来自列表，@Builder 参数化渲染安全，踩坑 15） */
  @Builder
  ThemedCard(h: Heritage) {
    Column() {
      Text(h.name)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(h.summary)
        .fontSize(12)
        .fontColor('#8D6E63')
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      Text(`${h.era} · ${h.city}`)
        .fontSize(10)
        .fontColor(getEraTheme(h.era).deep)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })
    }
    .width(150)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(getEraTheme(h.era).soft)
    .borderRadius(10)
    .border({ width: 1, color: '#F0EBE5' })
    .margin({ right: 10 })
    .onClick(() => {
      this.openDetail(h.id);
    })
  }

  /** 主题编辑器（新建 / 重命名共用；themeEditorMode 区分） */
  @Builder
  ThemeEditorSheet() {
    Column() {
      Text(this.themeEditorMode ? '重命名主题' : '新建主题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      TextInput({ placeholder: '主题名称（如「彩陶文化」「青铜文明」）', text: this.themeNameInput })
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor('#FAF6F0')
        .borderRadius(8)
        .margin({ top: 16 })
        .onChange((value: string) => {
          this.themeNameInput = value;
        })
      if (!this.themeEditorMode) {
        Text('选择主题颜色')
          .fontSize(13)
          .fontColor('#8D6E63')
          .margin({ top: 16 })
          .alignSelf(ItemAlign.Start)
        Row() {
          ForEach(THEME_PALETTE, (color: string, index: number) => {
            Row()
              .width(26)
              .height(26)
              .borderRadius(13)
              .backgroundColor(color)
              .border({ width: 2, color: this.themeColorIndex === index ? '#3E2723' : '#E0D6CC' })
              .margin({ right: 10 })
              .onClick(() => {
                this.themeColorIndex = index;
              })
          }, (color: string, index: number) => `${color}-${index}`)
        }
        .width('100%')
        .margin({ top: 10 })
      }
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#6D4C41')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick(() => {
            this.closeSheet();
          })
        Button('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#6D4C41')
          .layoutWeight(1)
          .onClick(() => {
            this.saveTheme();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('88%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  /** 归类管理：已归类（✕ 移除）/ 未归类收藏（＋ 加入） */
  @Builder
  ManageSheet() {
    Column() {
      Text('归类管理')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(this.selectedThemeName())
        .fontSize(13)
        .fontColor('#8D6E63')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })

      Text('已归类（点击 ✕ 移除）')
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          if (this.manageIncluded.length === 0) {
            Text('暂无，从下方收藏中添加')
              .fontSize(12)
              .fontColor('#BCAAA4')
              .padding({ top: 4, bottom: 4 })
          }
          ForEach(this.manageIncluded, (h: Heritage) => {
            Row() {
              Text(h.name)
                .fontSize(13)
                .fontColor('#3E2723')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('✕')
                .fontSize(12)
                .fontColor('#C0392B')
                .padding({ left: 6, right: 2 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#FBE9E7')
            .borderRadius(14)
            .border({ width: 1, color: '#FFCCBC' })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.removeFromTheme(h.id);
            })
          }, (h: Heritage) => h.id)
        }
        .width('100%')
      }
      .align(Alignment.Start)
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 140 })
      .margin({ top: 8 })

      Text('未归类收藏（点击加入）')
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          if (this.manageAvailable.length === 0) {
            Text('没有可加入的收藏（全部已归类或暂无收藏）')
              .fontSize(12)
              .fontColor('#BCAAA4')
              .padding({ top: 4, bottom: 4 })
          }
          ForEach(this.manageAvailable, (h: Heritage) => {
            Row() {
              Text(h.name)
                .fontSize(13)
                .fontColor('#6D4C41')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('＋')
                .fontSize(13)
                .fontColor('#2E7D32')
                .padding({ left: 6, right: 2 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#E8F5E9')
            .borderRadius(14)
            .border({ width: 1, color: '#A5D6A7' })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.addToTheme(h.id);
            })
          }, (h: Heritage) => h.id)
        }
        .width('100%')
      }
      .align(Alignment.Start)
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 140 })
      .margin({ top: 8 })

      Button('完成')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#6D4C41')
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => {
          this.closeSheet();
        })
    }
    .width('88%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  /** 删除主题确认（主题删除不删收藏，文案注明） */
  @Builder
  ConfirmDeleteSheet() {
    Column() {
      Text('确认删除主题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(`「${this.selectedThemeName()}」删除后仅移除主题归类，收藏与笔记保留`)
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)
      Row({ space: 12 }) {
        Button('再想想')
          .fontSize(14)
          .fontColor('#6D4C41')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick(() => {
            this.closeSheet();
          })
        Button('删除主题')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#C0392B')
          .layoutWeight(1)
          .onClick(() => {
            this.confirmDeleteTheme();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('76%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
  }
}
