/**
 * 归类管理弹层：已归类（✕ 移除）/ 未归类收藏（＋ 加入）
 */

import { Heritage } from '../../model/Heritage';
import { ThemeTokens } from '../../utils/ThemeTokens';

@Component
export struct ManageSheet {
  /** 主题名称 */
  @Prop themeName: string = '';
  /** 已归类列表 */
  @Prop included: Heritage[] = [];
  /** 未归类收藏列表 */
  @Prop available: Heritage[] = [];
  /** 移除回调 */
  onRemove: (itemId: string) => void = () => {};
  /** 加入回调 */
  onAdd: (itemId: string) => void = () => {};
  /** 完成回调 */
  onDone: () => void = () => {};

  build() {
    Column() {
      Text('归类管理')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(this.themeName)
        .fontSize(13)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })

      Text('已归类（点击 ✕ 移除）')
        .fontSize(13)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          if (this.included.length === 0) {
            Text('暂无，从下方收藏中添加')
              .fontSize(12)
              .fontColor(ThemeTokens.TEXT_MUTED)
              .padding({ top: 4, bottom: 4 })
          }
          ForEach(this.included, (h: Heritage) => {
            Row() {
              Text(h.name)
                .fontSize(13)
                .fontColor(ThemeTokens.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('✕')
                .fontSize(12)
                .fontColor(ThemeTokens.DANGER)
                .padding({ left: 6, right: 2 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .constraintSize({ minHeight: 44 })
            .backgroundColor('#FBE9E7')
            .borderRadius(14)
            .border({ width: 1, color: '#FFCCBC' })
            .margin({ right: 8, bottom: 8 })
            .accessibilityText(`将 ${h.name} 移出主题`)
            .accessibilityLevel('yes')
            .onClick(() => {
              this.onRemove(h.id);
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
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          if (this.available.length === 0) {
            Text('没有可加入的收藏（全部已归类或暂无收藏）')
              .fontSize(12)
              .fontColor(ThemeTokens.TEXT_MUTED)
              .padding({ top: 4, bottom: 4 })
          }
          ForEach(this.available, (h: Heritage) => {
            Row() {
              Text(h.name)
                .fontSize(13)
                .fontColor(ThemeTokens.PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('＋')
                .fontSize(13)
                .fontColor('#2E7D32')
                .padding({ left: 6, right: 2 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .constraintSize({ minHeight: 44 })
            .backgroundColor('#E8F5E9')
            .borderRadius(14)
            .border({ width: 1, color: '#A5D6A7' })
            .margin({ right: 8, bottom: 8 })
            .accessibilityText(`将 ${h.name} 加入主题`)
            .accessibilityLevel('yes')
            .onClick(() => {
              this.onAdd(h.id);
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
        .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
        .backgroundColor(ThemeTokens.PRIMARY)
        .width('100%')
        .height(44)
        .margin({ top: 16 })
        .onClick(() => {
          this.onDone();
        })
    }
    .width('88%')
    .padding(20)
    .backgroundColor(ThemeTokens.BG_CARD)
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }
}
