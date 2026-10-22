/**
 * 主题编辑器弹层（新建 / 编辑共用；C1.5 起重命名也可改主题色）
 */

import { THEME_PALETTE } from '../../model/Theme';

@Component
export struct ThemeEditorSheet {
  /** true=重命名模式 */
  @Prop isRename: boolean = false;
  /** 初始名称（重命名时传入） */
  @Prop initialName: string = '';
  /** 初始颜色索引（重命名时传入） */
  @Prop initialColorIndex: number = 0;
  /** 保存回调：返回 false 表示名称重复等原因未保存，弹层保持打开并显示行内错误 */
  onSave: (name: string, colorIndex: number) => boolean = () => false;
  /** 取消回调 */
  onCancel: () => void = () => {};

  @State themeNameInput: string = '';
  @State themeColorIndex: number = 0;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.themeNameInput = this.initialName;
    this.themeColorIndex = this.initialColorIndex;
    this.errorText = '';
  }

  private handleSave(): void {
    const name: string = this.themeNameInput.trim();
    if (name === '') {
      this.errorText = '主题名称不能为空';
      return;
    }
    const saved: boolean = this.onSave(name, this.themeColorIndex);
    if (!saved) {
      this.errorText = '主题名称已存在，请换一个';
    }
  }

  build() {
    Column() {
      Text(this.isRename ? '编辑主题' : '新建主题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')

      TextInput({ placeholder: '主题名称（如「彩陶文化」「青铜文明」）', text: this.themeNameInput })
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor('#FAF6F0')
        .borderRadius(8)
        .margin({ top: 16 })
        .onChange((value: string) => {
          this.themeNameInput = value;
          if (this.errorText !== '') {
            this.errorText = '';
          }
        })

      if (this.errorText !== '') {
        Text(this.errorText)
          .fontSize(11)
          .fontColor('#C0392B')
          .margin({ top: 6 })
          .alignSelf(ItemAlign.Start)
      }

      Text('主题颜色')
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 16 })
        .alignSelf(ItemAlign.Start)
      Row() {
        ForEach(THEME_PALETTE, (color: string, index: number) => {
          Row()
            .width(26)
            .height(26)
            .borderRadius(13)
            .backgroundColor(color)
            .border({ width: 2, color: this.themeColorIndex === index ? '#3E2723' : '#E0D6CC' })
            .margin({ right: 10 })
            .onClick(() => {
              this.themeColorIndex = index;
            })
        }, (color: string, index: number) => `${color}-${index}`)
      }
      .width('100%')
      .margin({ top: 10 })

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#6D4C41')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick(() => {
            this.onCancel();
          })
        Button('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#6D4C41')
          .layoutWeight(1)
          .onClick(() => {
            this.handleSave();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('88%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }
}
