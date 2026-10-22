/**
 * 图谱节点信息卡（C1.6 从 KnowledgeGraph 抽出的展示组件）
 *
 * 只负责展示与回调，不持有业务状态：
 * - 主题节点：覆盖统计 + 归类管理入口；
 * - 已归类遗址：元信息 / 简介 / 核心看点 + 查看详情 / 移出主题；
 * - 拓展推荐：在简介前增加「推荐依据」，解释图上虚线关系。
 *
 * 展示值由页面计算后经 @Prop 传入；页面状态变化会驱动本组件刷新，
 * 避免 @Builder 按值传递导致的局部 UI 不刷新（踩坑 15）。
 */

import { GraphNodeKind } from './GraphNode';

@Component
export struct NodeInfoPanel {
  /** 节点种类（NONE 时不应实例化本组件） */
  @Prop kind: GraphNodeKind = GraphNodeKind.NONE;
  /** 节点标题 */
  @Prop title: string = '';
  /** 标题前的色点（主题色 / 年代色） */
  @Prop nodeColor: string = '#8D6E63';
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
          .fontColor('#3E2723')
          .margin({ left: 8 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.kindLabel)
          .fontSize(10)
          .fontColor('#8D6E63')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#F5EFE9')
          .borderRadius(6)
          .margin({ left: 6 })
        Text('✕')
          .fontSize(16)
          .fontColor('#8D6E63')
          .padding(4)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')

      if (this.kind === GraphNodeKind.THEME) {
        Text(this.coverage)
          .fontSize(12)
          .fontColor('#8D6E63')
          .margin({ top: 6 })
        Button('归类管理')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#6D4C41')
          .width('100%')
          .margin({ top: 12 })
          .onClick(() => {
            this.onOpenManage();
          })
      } else {
        Text(this.meta)
          .fontSize(11)
          .fontColor('#8D6E63')
          .margin({ top: 6 })
        if (this.kind === GraphNodeKind.RECOMMEND) {
          Text(this.reason)
            .fontSize(11)
            .fontColor('#8D6E63')
            .lineHeight(17)
            .maxLines(3)
            .width('100%')
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .backgroundColor('#FBF7F2')
            .borderRadius(6)
            .margin({ top: 8 })
        }
        Text(this.summary)
          .fontSize(12)
          .fontColor('#6D4C41')
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })
        if (this.highlights !== '') {
          Text(`看点：${this.highlights}`)
            .fontSize(11)
            .fontColor('#8D6E63')
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
        }
        Row({ space: 10 }) {
          Button('查看详情')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#6D4C41')
            .layoutWeight(1)
            .onClick(() => {
              this.onOpenDetail();
            })
          if (this.kind === GraphNodeKind.HERITAGE) {
            Button('移出主题')
              .fontSize(13)
              .fontColor('#6D4C41')
              .backgroundColor('#EFEBE9')
              .layoutWeight(1)
              .onClick(() => {
                this.onRemove();
              })
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ top: 10 })
    .shadow({ radius: 6, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 2 })
  }
}
