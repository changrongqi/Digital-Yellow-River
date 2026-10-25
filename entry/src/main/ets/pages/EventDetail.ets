/**
 * 事件子详情页（M1.8）。
 *
 * 路由：遗址详情页「事件」页签经 utils/RouterUtil.push('pages/EventDetail',
 * { heritageId, eventIndex }) 进入；本页按 heritageId 从 HeritageRepository 重新取数
 * （数据单一来源，与 Detail 页一致），再取 events[eventIndex] 做专题讲解。
 *
 * 专题结构（计划书 M1.8 要求，M1.9 增补）：
 * - 英雄横幅：遗址年代主题色渐变 + 事件年份/标题/一句话概述；
 * - 背景（background）/ 经过（process）/ 影响（impact）三段正文，字段为空则隐藏小节；
 * - 深度解说（commentary，M1.9 新增）：延伸知识点/官方研究细节，独立段落；
 * - 相关人物（figures chips）+ 相关文物（artifacts 卡片）；
 * - 延伸阅读（furtherReading 来源出处）。
 *
 * 兜底策略（与 Detail 页一致）：加载中转圈；rawfile 失败注入 mock；
 * 找不到条目 / 事件越界 / 无详情字段 → 对应占位，不崩溃。
 */

import { Heritage, HeritageEvent } from '../model/Heritage';
import { HeritageRepository, HeritageLoadResult } from '../data/HeritageRepository';
import { getEraTheme } from '../utils/EraTheme';
import { ImageGallery } from '../components/ImageGallery';
import { ThemeTokens } from '../utils/ThemeTokens';
import { RouterUtil } from '../utils/RouterUtil';

@Entry
@Component
struct EventDetail {
  @State heritage: Heritage | null = null;
  @State isLoading: boolean = true;
  @State isMockData: boolean = false;
  /** 当前事件（由 heritage.detail.events[eventIndex] 取数） */
  @State event: HeritageEvent | null = null;
  private heritageId: string = '';
  private eventIndex: number = 0;

  aboutToAppear(): void {
    const params = RouterUtil.getParams();
    if (params !== undefined) {
      const idObj: Object | undefined = params['heritageId'];
      if (idObj !== undefined && idObj !== null) {
        this.heritageId = String(idObj);
      }
      const idxObj: Object | undefined = params['eventIndex'];
      if (idxObj !== undefined && idxObj !== null) {
        this.eventIndex = Number(idxObj);
      }
    }
    this.loadData();
  }

  private async loadData(): Promise<void> {
    // M4：统一走 HeritageRepository（rawfile 优先、失败注入 mock、id 映射缓存）。
    const result: HeritageLoadResult = await HeritageRepository.load(this.getUIContext().getHostContext());
    const found: Heritage | undefined = result.byId.get(this.heritageId);
    this.heritage = found === undefined ? null : found;
    this.isMockData = result.isMock;
    this.isLoading = false;
    this.event = this.pickEvent();
  }

  /** 从当前遗址取 events[eventIndex]，越界/缺失返回 null（不崩溃） */
  private pickEvent(): HeritageEvent | null {
    if (this.heritage === null) {
      return null;
    }
    const events: HeritageEvent[] = this.heritage.detail.events;
    if (this.eventIndex < 0 || this.eventIndex >= events.length) {
      return null;
    }
    return events[this.eventIndex];
  }

  /** 小节标题（背景/经过/影响等） */
  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeTokens.TEXT_PRIMARY)
      .width('100%')
      .margin({ top: 18, bottom: 8 })
  }

  /** 正文段落（分段符 \n 保留排版） */
  @Builder
  BodyParagraph(content: string) {
    Text(content)
      .fontSize(15)
      .fontColor(ThemeTokens.TEXT_PRIMARY)
      .lineHeight(26)
      .textAlign(TextAlign.JUSTIFY)
      .width('100%')
  }

  /** 相关人物 chips（主题色浅底） */
  @Builder
  FiguresChips(figures: string[]) {
    if (figures.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(figures, (name: string) => {
          Text(name)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).soft)
            .borderRadius(12)
            .margin({ right: 8, bottom: 8 })
        }, (name: string) => name)
      }
      .width('100%')
    }
  }

  /** 相关文物卡（白底，主题色名称 + 说明） */
  @Builder
  ArtifactsList(artifacts: string[]) {
    if (artifacts.length > 0) {
      Column() {
        ForEach(artifacts, (name: string) => {
          Text(name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(ThemeTokens.BG_PAGE)
            .borderRadius(8)
            .margin({ top: 8 })
        }, (name: string) => name)
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      // 顶部导航栏：返回 + 所属遗址名 + 事件标识
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
            RouterUtil.back();
          })
        Text(this.heritage === null ? '事件专题' : `${this.heritage.name} · 事件专题`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 8 })
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
          Text('正在加载事件专题…')
            .fontSize(14)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else if (this.event === null) {
        Column() {
          Text('未找到该事件')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.PRIMARY)
          Text('数据可能已更新，请返回列表重试')
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
          Text('示例数据 · 预览调试专用（rawfile 加载失败）')
            .fontSize(12)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .backgroundColor(ThemeTokens.BG_WARNING)
            .margin({ bottom: 8 })
        }

        Scroll() {
          Column() {
            // 英雄横幅：遗址年代主题色渐变 + 年份徽标 + 标题 + 概述
            Column() {
              Text(this.event.year)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor('rgba(62,39,35,0.30)')
                .borderRadius(10)
              Text(this.event.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                .lineHeight(30)
                .margin({ top: 12 })
              if (this.event.summary.length > 0) {
                Text(this.event.summary)
                  .fontSize(13)
                  .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                  .lineHeight(21)
                  .margin({ top: 12 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(20)
            .linearGradient({
              angle: 135,
              colors: [[getEraTheme(this.heritage === null ? '' : this.heritage.era).deep, 0.0],
              [getEraTheme(this.heritage === null ? '' : this.heritage.era).mid, 1.0]]
            })

            // 正文主体：背景 / 经过 / 影响（字段为空隐藏小节）
            Column() {
              if (this.event.background.length > 0) {
                this.SectionTitle('背景')
                this.BodyParagraph(this.event.background)
              }
              if (this.event.process.length > 0) {
                this.SectionTitle('经过')
                this.BodyParagraph(this.event.process)
              }
              if (this.event.impact.length > 0) {
                this.SectionTitle('影响')
                this.BodyParagraph(this.event.impact)
              }

              // 深度解说（M1.9 新增：延伸知识点/官方研究细节）
              if (this.event.commentary.length > 0) {
                Text('深度解说')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).deep)
                  .width('100%')
                  .margin({ top: 18, bottom: 8 })
                Text(this.event.commentary)
                  .fontSize(14)
                  .fontColor(ThemeTokens.TEXT_BODY)
                  .lineHeight(25)
                  .textAlign(TextAlign.JUSTIFY)
                  .width('100%')
                  .padding(12)
                  .backgroundColor(getEraTheme(this.heritage === null ? '' : this.heritage.era).soft)
                  .borderRadius(10)
              }

              // 相关人物
              if (this.event.figures.length > 0) {
                this.SectionTitle('相关人物')
                this.FiguresChips(this.event.figures)
              }

              // 相关文物
              if (this.event.artifacts.length > 0) {
                this.SectionTitle('相关文物')
                this.ArtifactsList(this.event.artifacts)
              }

              // 事件图集（M1.10：真实图片占位 + 点击放大，动态布局）
              if (this.event.images.length > 0) {
                Text('图集')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeTokens.TEXT_PRIMARY)
                  .width('100%')
                  .margin({ top: 18, bottom: 8 })
                ImageGallery({ images: this.event.images })
              }

              // 延伸阅读（来源出处）
              if (this.event.furtherReading.length > 0) {
                Text('延伸阅读')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ThemeTokens.TEXT_PRIMARY)
                  .width('100%')
                  .margin({ top: 18, bottom: 8 })
                Text(this.event.furtherReading)
                  .fontSize(12)
                  .fontColor(ThemeTokens.TEXT_SECONDARY)
                  .lineHeight(19)
                  .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.BG_PAGE)
  }
}
