/**
 * 图谱节点信息卡（C1.6 从 KnowledgeGraph 抽出的展示组件）
 *
 * 只负责展示与回调，不持有业务状态：
 * - 主题节点：覆盖统计 + 归类管理入口；
 * - 已归类遗址：元信息 / 简介 / 核心看点 + 查看详情 / 移出主题；
 * - 拓展推荐：在简介前增加「推荐依据」，解释图上虚线关系；M9 起提供
 *   「收藏并归类」主操作（收藏 + 归入当前主题），查看详情降为次要操作。
 *
 * 展示值由页面计算后经 @Prop 传入；页面状态变化会驱动本组件刷新，
 * 避免 @Builder 按值传递导致的局部 UI 不刷新（踩坑 15）。
 */

import { GraphNodeKind } from './GraphNode';
import { ThemeTokens } from '../../utils/ThemeTokens';

@Component
export struct NodeInfoPanel {
  /** 节点种类（NONE 时不应实例化本组件） */
  @Prop kind: GraphNodeKind = GraphNodeKind.NONE;
  /** 节点标题 */
  @Prop title: string = '';
  /** 标题前的色点（主题色 / 年代色） */
  @Prop nodeColor: string = ThemeTokens.ACCENT_FALLBACK;
  /** 类型徽标：主题 / 已归类 / 拓展推荐 */
  @Prop kindLabel: string = '';
  /** 主题覆盖统计（仅主题节点） */
  @Prop coverage: string = '';
  /** 遗址元信息：年代 · 类型 · 城市 */
  @Prop meta: string = '';
  /** 一句话简介 */
  @Prop summary: string = '';
  /** 核心看点（最多 2 条，空串隐藏） */
  @Prop highlights: string = '';
  /** 推荐依据（仅拓展推荐节点） */
  @Prop reason: string = '';

  onClose: () => void = () => {};
  onOpenManage: () => void = () => {};
  onOpenDetail: () => void = () => {};
  onRemove: () => void = () => {};
  /** M9：拓展推荐节点「收藏并归入当前主题」 */
  onAddToTheme: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('')
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.nodeColor)
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .margin({ left: 8 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.kindLabel)
          .fontSize(10)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(ThemeTokens.BG_BADGE)
          .borderRadius(6)
          .margin({ left: 6 })
        Text('✕')
          .fontSize(16)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .accessibilityText('关闭节点信息')
          .accessibilityLevel('yes')
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')

      if (this.kind === GraphNodeKind.THEME) {
        Text(this.coverage)
          .fontSize(12)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .margin({ top: 6 })
        Button('归类管理')
          .fontSize(13)
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ThemeTokens.PRIMARY)
          .width('100%')
          .height(44)
          .margin({ top: 12 })
          .onClick(() => {
            this.onOpenManage();
          })
      } else {
        Text(this.meta)
          .fontSize(11)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .margin({ top: 6 })
        if (this.kind === GraphNodeKind.RECOMMEND) {
          Text(this.reason)
            .fontSize(11)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .lineHeight(17)
            .maxLines(3)
            .width('100%')
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .backgroundColor(ThemeTokens.BG_NOTE)
            .borderRadius(6)
            .margin({ top: 8 })
        }
        Text(this.summary)
          .fontSize(12)
          .fontColor(ThemeTokens.PRIMARY)
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })
        if (this.highlights !== '') {
          Text(`看点：${this.highlights}`)
            .fontSize(11)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
        }
        Row({ space: 10 }) {
          if (this.kind === GraphNodeKind.RECOMMEND) {
            // M9：推荐节点主操作为收藏并归入当前主题（实心），查看详情降为次要（浅底）
            Button('收藏并归类')
              .fontSize(13)
              .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ThemeTokens.PRIMARY)
              .layoutWeight(1)
              .height(44)
              .accessibilityText('收藏并归入当前主题')
              .onClick(() => {
                this.onAddToTheme();
              })
            Button('查看详情')
              .fontSize(13)
              .fontColor(ThemeTokens.PRIMARY)
              .backgroundColor(ThemeTokens.BG_SOFT)
              .layoutWeight(1)
              .height(44)
              .onClick(() => {
                this.onOpenDetail();
              })
          } else {
            Button('查看详情')
              .fontSize(13)
              .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ThemeTokens.PRIMARY)
              .layoutWeight(1)
              .height(44)
              .onClick(() => {
                this.onOpenDetail();
              })
            if (this.kind === GraphNodeKind.HERITAGE) {
              Button('移出主题')
                .fontSize(13)
                .fontColor(ThemeTokens.PRIMARY)
                .backgroundColor(ThemeTokens.BG_SOFT)
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.onRemove();
                })
            }
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ThemeTokens.BG_CARD)
    .borderRadius(14)
    .margin({ top: 10 })
    .shadow({ radius: 6, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 2 })
  }
}
