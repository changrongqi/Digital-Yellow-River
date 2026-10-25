/**
 * 我的笔记页（M2.5，体验补强）：按「遗址」聚合所有笔记，快速找回写过笔记的遗址。
 *
 * 背景（用户反馈）：未收藏的遗址下写了笔记后，退出详情页难以再次找到该遗址——
 * 收藏页只有收藏、发现页需逐个翻找。本页按遗址聚合全部笔记（含未收藏的），
 * 点击直达详情页，解决「写了笔记却找不到」的体验缺口。
 *
 * 数据流（单一数据源 = FavoriteService，分层约定 §3）：
 * - 从 getAllNotes()（updatedAt 倒序）按 itemId 聚合出 NoteGroup[]：
 *   遗址名（heritageMap 映射，缺失显示「数据缺失」）+ 笔记数 + 最后编辑时间；
 * - 排序按最后编辑时间倒序（最近写的遗址在最前）；
 * - onPageShow 刷新（从 NoteEdit 返回后更新）；M3（第二轮）起订阅
 *   FavoriteService.onDataChanged，页面停留时远端合并/其它页面变更立即刷新，
 *   aboutToDisappear 注销监听防泄漏；
 *   点击行跳详情页带 id（O2）。
 *
 * 预览兜底：rawfile 加载失败（预览器）时由 HeritageRepository 注入 MOCK_HERITAGES 构建映射表（只读），
 * 顶部提示条与收藏页行为一致；本页无路由入参，直接预览可看空态/数据态。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { Heritage } from '../model/Heritage';
import { Note } from '../model/Note';
import { HeritageRepository, HeritageLoadResult } from '../data/HeritageRepository';
import { FavoriteService } from '../service/FavoriteService';
import { formatDateTime } from '../utils/TimeFormat';
import { ThemeTokens } from '../utils/ThemeTokens';

const DOMAIN = 0x0000;
const TAG = 'MyNotes';

/** 遗址级笔记聚合显示模型 */
class NoteGroup {
  itemId: string;      // 遗址 id
  name: string;        // 遗址名
  noteCount: number;   // 该遗址笔记条数
  lastUpdatedAt: number; // 最后编辑时间（排序用）

  constructor(itemId: string, name: string, noteCount: number, lastUpdatedAt: number) {
    this.itemId = itemId;
    this.name = name;
    this.noteCount = noteCount;
    this.lastUpdatedAt = lastUpdatedAt;
  }
}

@Entry
@Component
struct MyNotes {
  /** 遗址级聚合列表（@State 整体赋值刷新，踩坑 5） */
  @State groups: NoteGroup[] = [];
  /** 笔记总数（标题栏展示） */
  @State totalNotes: number = 0;
  @State isLoading: boolean = true;
  /** 预览示例数据标注（rawfile 加载失败注入 mock 时为 true） */
  @State isMockData: boolean = false;

  /** itemId → Heritage 映射表（只读；预置数据加载完成后一次构建） */
  private heritageMap: Map<string, Heritage> = new Map();
  /**
   * 收藏/笔记数据变化处理器（M3）：远端合并或其它页面新增/删除笔记时，
   * 页面停留期间也能立即刷新聚合列表。
   */
  private dataChangedHandler: () => void = (): void => {
    this.refreshList();
  };

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      hilog.error(DOMAIN, TAG, 'host context unavailable');
      this.isLoading = false;
      this.refreshList();
      return;
    }
    FavoriteService.init(context);
    // M3：订阅数据变化（收藏页/详情页/远端合并都可能增删笔记），卸载时注销。
    FavoriteService.onDataChanged(this.dataChangedHandler);
    this.loadHeritages(context);
  }

  aboutToDisappear(): void {
    FavoriteService.offDataChanged(this.dataChangedHandler);
  }

  /** 页面重新显示（含从 NoteEdit 返回的同页实例）：刷新聚合列表 */
  onPageShow(): void {
    this.refreshList();
  }

  private async loadHeritages(context: common.Context): Promise<void> {
    const result: HeritageLoadResult = await HeritageRepository.load(context);
    this.heritageMap = result.byId;
    this.isMockData = result.isMock;
    this.isLoading = false;
    this.refreshList();
  }

  /** 从 FavoriteService 按 itemId 聚合全部笔记（整体赋值刷新）；按最后编辑时间倒序 */
  private refreshList(): void {
    const all: Note[] = FavoriteService.getAllNotes(); // updatedAt 倒序
    const indexByItem: Map<string, number> = new Map();
    const groups: NoteGroup[] = [];
    for (let i = 0; i < all.length; i++) {
      const note: Note = all[i];
      const idx: number | undefined = indexByItem.get(note.itemId);
      if (idx === undefined) {
        const heritage: Heritage | undefined = this.heritageMap.get(note.itemId);
        const name: string = heritage === undefined ? `数据缺失 (${note.itemId})` : heritage.name;
        groups.push(new NoteGroup(note.itemId, name, 1, note.updatedAt));
        indexByItem.set(note.itemId, groups.length - 1);
      } else {
        const group: NoteGroup = groups[idx];
        group.noteCount += 1;
        if (note.updatedAt > group.lastUpdatedAt) {
          group.lastUpdatedAt = note.updatedAt;
        }
      }
    }
    groups.sort((a: NoteGroup, b: NoteGroup): number => b.lastUpdatedAt - a.lastUpdatedAt);
    this.groups = groups;
    this.totalNotes = all.length;
  }

  /** 打开详情页（router.pushUrl 唯一调用点，收敛 deprecate 告警；统一带 id，O2） */
  private openDetail(itemId: string): void {
    try {
      router.pushUrl({ url: 'pages/Detail', params: { id: itemId } });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open detail failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 返回上一页（router.back 唯一调用点，收敛 deprecate 告警） */
  private goBack(): void {
    router.back();
  }

  build() {
    Column() {
      // 顶部导航栏：返回 + 标题 + 总数
      Row() {
        Text('‹')
          .fontSize(30)
          .fontColor(ThemeTokens.PRIMARY)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .accessibilityText('返回')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.goBack();
          })
        Text('我的笔记')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .layoutWeight(1)
          .margin({ left: 8 })
        Text(`${this.totalNotes} 条`)
          .fontSize(13)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
      .width('100%')
      .padding({ left: 12, right: 20, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(ThemeTokens.ACCENT_MUTED)
          Text('正在加载笔记…')
            .fontSize(14)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.totalNotes === 0) {
        // 空态兜底（工程惯例：无数据需明确提示）
        Column() {
          Text('还没有笔记')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.PRIMARY)
          Text('在任意遗址详情页点击「写笔记」，之后可在这里快速找回')
            .fontSize(13)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else {
        // mock 示例数据提示条（仅加载失败兜底时出现）
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

        List({ space: 12 }) {
          ForEach(this.groups, (group: NoteGroup) => {
            ListItem() {
              // 遗址聚合卡片：徽标（笔记数）+ 遗址名 + 最后编辑
              Row() {
                Column() {
                  Text(`${group.noteCount}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                  Text('笔记')
                    .fontSize(10)
                    .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                    .margin({ top: 2 })
                }
                .justifyContent(FlexAlign.Center)
                .width(56)
                .height(56)
                .borderRadius(10)
                .backgroundColor(ThemeTokens.ACCENT_FALLBACK)

                Column() {
                  Text(group.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ThemeTokens.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`最后编辑 ${formatDateTime(group.lastUpdatedAt)}`)
                    .fontSize(12)
                    .fontColor(ThemeTokens.TEXT_SECONDARY)
                    .margin({ top: 6 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })

                Text('›')
                  .fontSize(22)
                  .fontColor(ThemeTokens.TEXT_MUTED)
                  .margin({ left: 8 })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(ThemeTokens.BG_CARD)
              .borderRadius(12)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.openDetail(group.itemId);
              })
            }
          }, (group: NoteGroup) => `${group.itemId}-${group.noteCount}-${group.lastUpdatedAt}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.BG_PAGE)
  }
}
