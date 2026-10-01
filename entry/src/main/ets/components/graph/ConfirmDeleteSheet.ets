/**
 * 删除主题确认弹层
 */

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
        .fontColor('#3E2723')
      Text(`「${this.themeName}」删除后仅移除主题归类，收藏与笔记保留`)
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
            this.onCancel();
          })
        Button('删除主题')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#C0392B')
          .layoutWeight(1)
          .onClick(() => {
            this.onConfirm();
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
