/**
 * 知识图谱页（C1.2）：文化主题聚合 + 个人知识库构建
 *
 * 职责：页面状态管理 + UI 布局，Canvas 绘制与弹层拆分为独立组件
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
import { recommendHeritages } from '../utils/Recommendation';
import { MOCK_HERITAGES } from '../data/MockHeritages';
import { GraphCanvas } from '../components/graph/GraphCanvas';
import { HeritageCard } from '../components/graph/HeritageCard';
import { ThemeEditorSheet } from '../components/graph/ThemeEditorSheet';
import { ManageSheet } from '../components/graph/ManageSheet';
import { ConfirmDeleteSheet } from '../components/graph/ConfirmDeleteSheet';

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

  /** 主题变化处理器 */
  private themeChangedHandler: () => void = (): void => {
    this.loadThemes();
  };
  /** 收藏变化处理器 */
  private favChangedHandler: () => void = (): void => {
    this.refreshSelected();
  };

  /** 父页面刷新信号 */
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

  /** 加载预置遗产数据构建映射表 */
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

  /** 从 ThemeService 加载主题 */
  private loadThemes(): void {
    const themes: Theme[] = ThemeService.getAllThemes();
    this.themes = themes;
    if (this.selectedThemeId === '') {
      if (themes.length > 0) {
        this.selectedThemeId = themes[0].id;
      }
    } else if (!this.containsTheme(themes, this.selectedThemeId)) {
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

  /** 重建选中主题下的图谱数据 */
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
  }

  /** 选择主题 */
  private selectTheme(id: string): void {
    if (this.selectedThemeId === id) {
      return;
    }
    this.selectedThemeId = id;
    this.refreshSelected();
  }

  /** 拓展推荐 */
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

  private saveTheme(name: string, colorIndex: number): void {
    if (this.themeEditorMode) {
      ThemeService.renameTheme(this.selectedThemeId, name);
    } else {
      const created: Theme | null = ThemeService.addTheme(name, colorIndex);
      if (created !== null) {
        this.selectedThemeId = created.id;
      }
    }
    this.closeSheet();
    this.loadThemes();
  }

  private openDeleteConfirm(): void {
    this.sheetType = SheetType.ConfirmDelete;
  }

  private confirmDeleteTheme(): void {
    ThemeService.removeTheme(this.selectedThemeId);
    this.closeSheet();
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

  private openDetail(heritageId: string): void {
    try {
      router.pushUrl({ url: 'pages/Detail', params: { id: heritageId } });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open detail failed: %{public}s', JSON.stringify(err));
    }
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
          // 空态：无主题
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
          // mock 示例数据提示条
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
              // 主题 chips
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

              // 知识图谱画布区域
              Column() {
                GraphCanvas({
                  theme: this.selectedTheme(),
                  heritages: this.themedHeritages,
                  onNodeClick: (id: string) => {
                    this.openDetail(id);
                  }
                })
              }
              .width('100%')
              .height(320)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .margin({ top: 12 })
              .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 })

              if (this.selectedThemeId === '') {
                Text('请选择或新建一个主题')
                  .fontSize(13)
                  .fontColor('#8D6E63')
                  .margin({ top: 24 })
              } else if (this.themedHeritages.length === 0) {
                // 空态：主题下无归类
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
                .borderRadius(16)
                .margin({ top: 12 })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetX: 0, offsetY: 2 })
              } else {
                // 主题操作行
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

                // 已归类遗址
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
                      .fontColor('#3E2723')
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

      // 弹层
      if (this.sheetType !== SheetType.None) {
        Column() {
          if (this.sheetType === SheetType.ThemeEditor) {
            ThemeEditorSheet({
              isRename: this.themeEditorMode,
              initialName: this.themeNameInput,
              initialColorIndex: this.themeColorIndex,
              onSave: (name: string, colorIndex: number) => {
                this.saveTheme(name, colorIndex);
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
