/**
 * 详情页（M1.5 建立骨架，M4.0 信息架构与视觉改版）。
 *
 * 路由：发现页/收藏页/我的笔记列表点击 router.pushUrl('pages/Detail', { id }) 进入；
 * 本页按 id 从 HeritageDataLoader 重新取数（数据单一来源，便于 M2/M3 联动）。
 *
 * M4.0 改版（用户反馈「详情页简陋」，方向经确认：布局重构 + 年代主题色，克制低饱和）：
 * - 英雄横幅：按年代取主题色渐变（utils/EraTheme：仰韶彩陶红/龙山黑陶灰/夏商青铜绿/
 *   周玄青/汉唐鎏金赭/宋青瓷），大号名称 + 半透明白底徽标 + 简介，一屏建立年代记忆点；
 * - 五层级 + 笔记改为顶部页签（Tabs + SubTabBarStyle，官方推荐「信息较多时分类聚焦」）：
 *   介绍 / 考古 / 事件 / 诗词 / 文旅 / 笔记，支持左右滑动切换，横幅常驻不随内容滚动；
 * - 历史事件 → 时间轴（年份高亮 + 可点击条目，M1.8 起点击跳转事件子详情页做专题讲解）；
 * - 相关诗词 → 古风卡（浅主题底 + 标题作者居中 + 引文排版）；
 * - M4.1 起推荐区块将接入「介绍」页签（预留结构位置）。
 *
 * 兜底策略（与发现页一致）：
 * - 加载中：转圈提示；rawfile 加载失败（预览器）：注入 mock 再按 id 匹配；
 * - 找不到条目 / 单层内容为空：对应页签显示占位，不崩溃。
 *
 * M2.4/M3.2 逻辑（改版后原样保留）：
 * - 导航栏收藏按钮（toggleFavorite 同步切换）；「笔记」页签列表 + 写笔记入口 + 点击编辑；
 * - onPageShow / onDataChanged 刷新收藏状态与笔记列表；aboutToDisappear 注销监听防泄漏。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage, HeritageEvent, SpecItem, Artifact } from '../model/Heritage';
import { Note } from '../model/Note';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { FavoriteService } from '../service/FavoriteService';
import { getEraTheme } from '../utils/EraTheme';
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
  /** 用户数据变化监听句柄（远端合并/本地变更时刷新本页，M3.2；消失时注销防泄漏） */
  private dataChangedHandler: () => void = (): void => {};

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
    // M3.2：远端 LWW 合并（或其他页面变更）时刷新收藏状态与笔记列表
    this.dataChangedHandler = (): void => {
      this.isFav = FavoriteService.isFavorite(this.targetId);
      this.notes = FavoriteService.getNotesByItem(this.targetId);
    };
    FavoriteService.onDataChanged(this.dataChangedHandler);
    this.loadData();
  }

  aboutToDisappear(): void {
    FavoriteService.offDataChanged(this.dataChangedHandler);
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
   * 打开事件子详情页（M1.8：每个历史事件都可点击，做专题讲解）。
   * 传 heritageId + eventIndex，子页按 id 从加载器重新取数（数据单一来源）。
   */
  private openEventDetail(index: number): void {
    if (this.heritage === null) {
      return;
    }
    try {
      router.pushUrl({
        url: 'pages/EventDetail',
        params: { heritageId: this.heritage.id, eventIndex: index }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open event detail failed: %{public}s', JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // 顶部导航栏：返回 + 标题 + 收藏（M4.0 改版保持不变）
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
        // mock 示例数据提示条（仅加载失败兜底时出现）
        if (this.isMockData) {
          Text('示例数据 · 预览调试专用（rawfile 加载失败）')
            .fontSize(12)
            .fontColor('#8D6E63')
            .width('100%')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .backgroundColor('#FFF3E0')
            .margin({ bottom: 8 })
        }

        // 英雄横幅：年代主题色渐变 + 名称 + 徽标 + 简介（M4.0）
        Column() {
          Text(this.heritage.name)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            this.HeroTag(this.heritage.era)
            this.HeroTag(this.heritage.type)
            this.HeroTag(this.heritage.city)
          }
          .margin({ top: 12 })
          Text(this.heritage.summary)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.92)')
            .lineHeight(21)
            .margin({ top: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })
        .linearGradient({
          angle: 135,
          colors: [[getEraTheme(this.heritage.era).deep, 0.0], [getEraTheme(this.heritage.era).mid, 1.0]]
        })

        // 五层级 + 笔记：顶部页签（官方推荐信息分类方式），左右滑动切换（M4.0）
        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.IntroTab()
          }
          .tabBar(SubTabBarStyle.of('介绍'))

          TabContent() {
            this.ArchTab()
          }
          .tabBar(SubTabBarStyle.of('考古'))

          TabContent() {
            this.TimelineTab(this.heritage.detail.events)
          }
          .tabBar(SubTabBarStyle.of('事件'))

          TabContent() {
            this.BodyTab(this.heritage.detail.tourism)
          }
          .tabBar(SubTabBarStyle.of('文旅'))

          TabContent() {
            this.NotesTab()
          }
          .tabBar(SubTabBarStyle.of('笔记'))
        }
        .layoutWeight(1)
        .width('100%')
        .barWidth('100%')
        .barMode(BarMode.Fixed)
        .scrollable(true)
        .onChange((index: number) => {
          hilog.info(DOMAIN, TAG, 'detail tab %{public}d', index);
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  /** 横幅徽标（年代/类型/城市）：半透明白底 + 白字（M4.0） */
  @Builder
  HeroTag(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor('#FFFFFF')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('rgba(255,255,255,0.22)')
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

  /**
   * 介绍页签（M1.7）：核心看点 chips + 正文 + 遗址档案卡。
   * ⚠️ 无参数、内部直读 this.heritage（踩坑 15）。
   */
  @Builder
  IntroTab() {
    Scroll() {
      Column() {
        // 核心看点（有数据才显示；主题色浅底 chips）
        if (this.heritage !== null && this.heritage.detail.highlights.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.heritage.detail.highlights, (point: string) => {
              Text(point)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).soft)
                .borderRadius(10)
                .margin({ right: 8, bottom: 8 })
            }, (point: string) => point)
          }
          .width('100%')
          .margin({ bottom: 14 })
        }

        // 正文（数据中含 \n 分段）
        if (this.heritage !== null) {
          if (this.heritage.detail.intro.length === 0) {
            Text('暂无内容')
              .fontSize(14)
              .fontColor('#BCAAA4')
              .padding({ top: 40 })
          } else {
            Text(this.heritage.detail.intro)
              .fontSize(15)
              .fontColor('#3E2723')
              .lineHeight(26)
              .textAlign(TextAlign.JUSTIFY)
          }
        }

        // 遗址档案卡（键值行）
        if (this.heritage !== null && this.heritage.detail.specs.length > 0) {
          Column() {
            Text('遗址档案')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#3E2723')
              .width('100%')
            ForEach(this.heritage.detail.specs, (spec: SpecItem) => {
              Row() {
                Text(spec.label)
                  .fontSize(13)
                  .fontColor('#8D6E63')
                  .width(88)
                Text(spec.value)
                  .fontSize(13)
                  .fontColor('#3E2723')
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: '#F0EBE5' })
            }, (spec: SpecItem) => spec.label)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ top: 20 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * 考古页签（M1.7）：考古发现正文 + 代表性出土文物卡。
   * ⚠️ 无参数、内部直读 this.heritage（踩坑 15）。
   */
  @Builder
  ArchTab() {
    Scroll() {
      Column() {
        if (this.heritage !== null) {
          if (this.heritage.detail.discovery.length === 0) {
            Text('暂无内容')
              .fontSize(14)
              .fontColor('#BCAAA4')
              .padding({ top: 40 })
          } else {
            Text(this.heritage.detail.discovery)
              .fontSize(15)
              .fontColor('#3E2723')
              .lineHeight(26)
              .textAlign(TextAlign.JUSTIFY)
          }
        }

        // 代表性出土文物卡
        if (this.heritage !== null && this.heritage.detail.artifacts.length > 0) {
          Column() {
            Text('代表性出土文物')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#3E2723')
              .width('100%')
            ForEach(this.heritage.detail.artifacts, (artifact: Artifact) => {
              Column() {
                Text(artifact.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
                Text(artifact.desc)
                  .fontSize(13)
                  .fontColor('#6D4C41')
                  .lineHeight(21)
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).soft)
              .borderRadius(8)
              .margin({ top: 10 })
            }, (artifact: Artifact) => artifact.name)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ top: 20 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  /** 通用正文页签（文旅）：白卡 + 长文排版，空层占位（M4.0） */
  @Builder
  BodyTab(content: string) {
    Scroll() {
      Column() {
        if (content.length === 0) {
          Text('暂无内容')
            .fontSize(14)
            .fontColor('#BCAAA4')
            .padding({ top: 40 })
        } else {
          Text(content)
            .fontSize(15)
            .fontColor('#3E2723')
            .lineHeight(26)
            .textAlign(TextAlign.JUSTIFY)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * 历史事件页签：年份时间线（纯内容驱动，无拉伸，适配任意设备宽度）。
   *
   * M1.8：events 已升级为结构化对象（HeritageEvent），年份取 year、正文取 title，
   * 不再依赖正则二次解析；每个条目可点击，跳转事件子详情页做专题讲解。
   *
   * 布局要点（解决「条目间大段留白」回归）：
   * - 不用「竖线 + layoutWeight 轨道」——Column 无高度约束时 layoutWeight 会把竖线无限撑高，
   *   导致每个条目 Row 被拉高、条目间出现巨大空隙（截图实测 280pt）；
   * - 改为「年份徽标 + 正文 + 详情箭头」一行、条目间用 Divider 分隔：高度完全由文字内容决定；
   * - 宽度全部自适应（年份列固定 64，正文 layoutWeight 吃掉剩余），平板/手机自动适配；
   * - 条目末尾显示「整理中」引导，把数据稀疏的底部变成有语义的收尾而非纯空白。
   */
  @Builder
  TimelineTab(events: HeritageEvent[]) {
    Scroll() {
      Column() {
        if (events.length === 0) {
          Text('暂无内容')
            .fontSize(14)
            .fontColor('#BCAAA4')
            .padding({ top: 40 })
        } else {
          ForEach(events, (item: HeritageEvent, idx: number) => {
            Column() {
              Row() {
                // 年份徽标：主题色底圆角胶囊，宽度固定、内容驱动
                Text(item.year)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .backgroundColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
                  .borderRadius(10)

                // 正文：换行自适应，吃满剩余宽度（设备自适应）
                Text(item.title)
                  .fontSize(14)
                  .fontColor('#3E2723')
                  .lineHeight(22)
                  .layoutWeight(1)
                  .margin({ left: 12 })

                // 可点击入口提示（M1.8）
                Text('›')
                  .fontSize(18)
                  .fontColor('#A1887F')
                  .margin({ left: 8 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.openEventDetail(idx);
              })

              // 条目间分隔线（最后一条不加，避免多余空行）
              if (idx < events.length - 1) {
                Divider()
                  .color('#EFE9E2')
                  .strokeWidth(1)
                  .margin({ top: 14, bottom: 14 })
              }
            }
            .width('100%')
          }, (item: HeritageEvent, idx: number) => `${item.year}-${item.title}-${idx}`)
        }

        // 数据稀疏时的语义收尾：把底部留白变成「整理中」说明
        if (events.length > 0 && events.length < 4) {
          Text('更多考古进程正在整理中')
            .fontSize(12)
            .fontColor('#BCAAA4')
            .margin({ top: 20, bottom: 8 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * 笔记页签（M2.4 的「我的笔记」区块，M4.0 并入页签）。
   * ⚠️ 无参数、内部直读 @State（notes），规避踩坑 15 的参数按值传递失联。
   */
  @Builder
  NotesTab() {
    Scroll() {
      Column() {
        Row() {
          Text('我的笔记')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
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
            .margin({ top: 12 })
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
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }
}
