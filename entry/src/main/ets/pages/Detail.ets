/**
 * 详情页（M1.5）：文化条目五层级内容展示。
 *
 * 路由：发现页列表点击 router.pushUrl('pages/Detail', { id }) 进入；
 * 本页按 id 从 HeritageDataLoader 重新取数（数据单一来源，便于 M2/M3 联动）。
 *
 * 兜底策略（与发现页一致）：
 * - 加载中：转圈提示；
 * - rawfile 加载失败（典型场景：预览器）：注入 mock 示例数据再按 id 匹配；
 * - 找不到对应条目 / 单层内容为空：对应区块显示占位，不崩溃。
 *
 * 五层级：图文介绍 intro / 考古发现 discovery / 历史事件 events / 相关诗词 poems / 现代文旅 tourism。
 *
 * M2.4：
 * - 顶部导航栏收藏按钮，状态切换走 FavoriteService.toggleFavorite；
 * - 五层级之后「我的笔记」区块：列表（按最后编辑时间倒序）+ 写笔记入口 + 点击编辑；
 * - 从 NoteEdit 返回（同页实例）时 onPageShow 刷新笔记列表与收藏状态；
 * - 从本页返回主页时 Index.onPageShow 驱动收藏页刷新（列表联动）。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage, Poem } from '../model/Heritage';
import { Note } from '../model/Note';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { FavoriteService } from '../service/FavoriteService';
import { formatDateTime } from '../utils/TimeFormat';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'Detail';

@Entry
@Component
struct Detail {
  @State heritage: Heritage | null = null;
  @State isLoading: boolean = true;
  @State isMockData: boolean = false;
  /** 当前收藏状态（M2.4：随收藏按钮切换，返回主页后收藏页联动刷新） */
  @State isFav: boolean = false;
  /** 本条目笔记列表（updatedAt 倒序，服务层已排序） */
  @State notes: Note[] = [];
  private targetId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      const idObj: Object | undefined = params['id'];
      if (idObj !== undefined && idObj !== null) {
        this.targetId = String(idObj);
      }
    }
    // FavoriteService 幂等初始化（主页已初始化则直接返回），
    // 保证用户直接从本页冷启动（如通知/深链）时收藏功能同样可用
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      FavoriteService.init(hostContext);
    }
    this.isFav = FavoriteService.isFavorite(this.targetId);
    this.notes = FavoriteService.getNotesByItem(this.targetId);
    this.loadData();
  }

  /** 页面重新显示（含从 NoteEdit 返回的同页实例）：刷新笔记列表与收藏状态 */
  onPageShow(): void {
    this.isFav = FavoriteService.isFavorite(this.targetId);
    this.notes = FavoriteService.getNotesByItem(this.targetId);
  }

  private async loadData(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        throw new Error('host context unavailable');
      }
      const list: Heritage[] = await HeritageDataLoader.loadHeritageList(hostContext);
      this.heritage = this.findById(list, this.targetId);
      this.isMockData = false;
    } catch (err) {
      // 预览器无法访问 rawfile：注入示例数据兜底（与发现页同源）
      hilog.error(DOMAIN, TAG, 'load failed, fallback to mock: %{public}s', JSON.stringify(err));
      this.heritage = this.findById(MOCK_HERITAGES, this.targetId);
      this.isMockData = true;
    } finally {
      this.isLoading = false;
    }
  }

  private findById(list: Heritage[], id: string): Heritage | null {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return null;
  }

  build() {
    Column() {
      // 顶部导航栏：返回 + 标题
      Row() {
        Text('‹')
          .fontSize(30)
          .fontColor('#6D4C41')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text(this.heritage === null ? '遗产详情' : this.heritage.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 8 })
        this.FavButton()
      }
      .width('100%')
      .padding({ left: 12, right: 20, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#A1887F')
          Text('正在加载文化档案…')
            .fontSize(14)
            .fontColor('#8D6E63')
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.heritage === null) {
        Column() {
          Text('未找到该遗产')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6D4C41')
          Text('数据可能已更新，请返回列表重试')
            .fontSize(13)
            .fontColor('#8D6E63')
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else {
        Scroll() {
          Column() {
            if (this.isMockData) {
              Text('示例数据 · 预览调试专用（rawfile 加载失败）')
                .fontSize(12)
                .fontColor('#8D6E63')
                .width('100%')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#FFF3E0')
                .borderRadius(8)
                .margin({ bottom: 12 })
            }

            // 头部卡片：名称 + 三维标签 + 简介
            Column() {
              Text(this.heritage.name)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#3E2723')
              Row() {
                this.MetaTag(this.heritage.era)
                this.MetaTag(this.heritage.type)
                this.MetaTag(this.heritage.city)
              }
              .margin({ top: 10 })
              Text(this.heritage.summary)
                .fontSize(14)
                .fontColor('#6D4C41')
                .lineHeight(22)
                .margin({ top: 12 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)

            // 五层级内容
            this.TextSection('图文介绍', this.heritage.detail.intro)
            this.TextSection('考古发现', this.heritage.detail.discovery)
            this.EventsSection(this.heritage.detail.events)
            this.PoemsSection(this.heritage.detail.poems)
            this.TextSection('现代文旅', this.heritage.detail.tourism)

            // 我的笔记区块（M2.4）
            this.NotesSection()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  /** 头部元信息小标签（年代/类型/城市） */
  @Builder
  MetaTag(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor('#6D4C41')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#EFEBE9')
      .borderRadius(8)
      .margin({ right: 8 })
  }

  /**
   * 收藏按钮（M2.4 收藏入口）。
   * 状态区分：未收藏 = 白底棕字棕边；已收藏 = 棕底白字（主次高亮清晰区分）。
   * ⚠️ 内部直读 this.isFav（踩坑 15：@Builder 状态源必须直读，禁止参数传入）。
   */
  @Builder
  FavButton() {
    Text(this.isFav ? '已收藏' : '收藏')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.isFav ? '#FFFFFF' : '#6D4C41')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.isFav ? '#6D4C41' : '#FFFFFF')
      .borderRadius(14)
      .border({ width: 1, color: this.isFav ? '#6D4C41' : '#E0D6CC' })
      .onClick(() => {
        this.toggleFav();
      })
  }

  /** 切换收藏状态（toggleFavorite 同步完成，按钮样式随 isFav 即时反转） */
  private toggleFav(): void {
    if (this.heritage === null) {
      return;
    }
    this.isFav = FavoriteService.toggleFavorite(this.heritage.id);
  }

  /**
   * 打开笔记编辑页（router.pushUrl 唯一调用点，收敛 deprecate 告警）。
   * @param noteId 空串 = 新建；携带 = 编辑对应笔记
   */
  private openNoteEditor(noteId: string): void {
    if (this.heritage === null) {
      return;
    }
    try {
      router.pushUrl({ url: 'pages/NoteEdit', params: { id: this.heritage.id, noteId: noteId } });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open note editor failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 我的笔记区块（M2.4）：列表 + 写笔记入口 + 点击编辑。
   * ⚠️ 无参数、内部直读 @State（notes/heritage），规避踩坑 15 的参数按值传递失联。
   */
  @Builder
  NotesSection() {
    Column() {
      Row() {
        this.SectionTitle('我的笔记')
        Blank()
        Text('+ 写笔记')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6D4C41')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#EFEBE9')
          .borderRadius(14)
          .onClick(() => {
            this.openNoteEditor('');
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.notes.length === 0) {
        Text('还没有笔记，点击「写笔记」记录你的想法')
          .fontSize(13)
          .fontColor('#BCAAA4')
          .margin({ top: 10 })
      } else {
        ForEach(this.notes, (note: Note) => {
          Column() {
            Text(note.content)
              .fontSize(14)
              .fontColor('#3E2723')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .lineHeight(22)
            Text(`最后编辑 ${formatDateTime(note.updatedAt)}`)
              .fontSize(11)
              .fontColor('#BCAAA4')
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor('#FAF6F0')
          .borderRadius(8)
          .margin({ top: 10 })
          .onClick(() => {
            this.openNoteEditor(note.id);
          })
        }, (note: Note) => `${note.id}-${note.updatedAt}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  /** 通用文字区块：图文介绍 / 考古发现 / 现代文旅 */
  @Builder
  TextSection(title: string, content: string) {
    Column() {
      this.SectionTitle(title)
      if (content.length === 0) {
        Text('暂无内容')
          .fontSize(13)
          .fontColor('#BCAAA4')
          .margin({ top: 10 })
      } else {
        Text(content)
          .fontSize(14)
          .fontColor('#3E2723')
          .lineHeight(24)
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  /** 历史事件区块：时间线列表 */
  @Builder
  EventsSection(events: string[]) {
    Column() {
      this.SectionTitle('历史事件')
      if (events.length === 0) {
        Text('暂无内容')
          .fontSize(13)
          .fontColor('#BCAAA4')
          .margin({ top: 10 })
      } else {
        ForEach(events, (event: string) => {
          Row() {
            Text()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor('#8D6E63')
              .margin({ top: 8 })
            Text(event)
              .fontSize(14)
              .fontColor('#3E2723')
              .lineHeight(22)
              .layoutWeight(1)
              .margin({ left: 10 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: 10 })
        }, (event: string) => event)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  /** 相关诗词区块：卡片列表 */
  @Builder
  PoemsSection(poems: Poem[]) {
    Column() {
      this.SectionTitle('相关诗词')
      if (poems.length === 0) {
        Text('暂无内容')
          .fontSize(13)
          .fontColor('#BCAAA4')
          .margin({ top: 10 })
      } else {
        ForEach(poems, (poem: Poem) => {
          Column() {
            Row() {
              Text(poem.title)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#3E2723')
                .layoutWeight(1)
              Text(poem.author)
                .fontSize(12)
                .fontColor('#8D6E63')
            }
            .width('100%')
            Text(poem.content)
              .fontSize(14)
              .fontColor('#6D4C41')
              .lineHeight(24)
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor('#FAF6F0')
          .borderRadius(8)
          .margin({ top: 10 })
        }, (poem: Poem) => poem.title)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 12 })
  }

  /** 区块标题：左侧竖条 + 文字 */
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
