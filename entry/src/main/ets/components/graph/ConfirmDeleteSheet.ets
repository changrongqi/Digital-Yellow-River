/**
 * 删除主题确认弹层
 */
import { ThemeTokens } from '../../utils/ThemeTokens';

@Component
export struct ConfirmDeleteSheet {
  /** 主题名称 */
  @Prop themeName: string = '';
  /** 确认删除回调 */
  onConfirm: () => void = () => {};
  /** 取消回调 */
  onCancel: () => void = () => {};

  build() {
    Column() {
      Text('确认删除主题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(`「${this.themeName}」删除后仅移除主题归类，收藏与笔记保留`)
        .fontSize(13)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)
      Row({ space: 12 }) {
        Button('再想想')
          .fontSize(14)
          .fontColor(ThemeTokens.PRIMARY)
          .backgroundColor(ThemeTokens.BG_SOFT)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.onCancel();
          })
        Button('删除主题')
          .fontSize(14)
          .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ThemeTokens.DANGER)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.onConfirm();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('76%')
    .padding(20)
    .backgroundColor(ThemeTokens.BG_CARD)
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
  }
}
