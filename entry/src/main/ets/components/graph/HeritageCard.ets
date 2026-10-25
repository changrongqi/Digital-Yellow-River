/**
 * 遗址卡片（已归类 / 拓展推荐共用）
 */

import { Heritage } from '../../model/Heritage';
import { getEraTheme } from '../../utils/EraTheme';
import { ThemeTokens } from '../../utils/ThemeTokens';

@Component
export struct HeritageCard {
  @Prop heritage: Heritage;
  @Prop isDark: boolean = false;
  onTap: () => void = () => {};

  build() {
    Column() {
      Text(this.heritage.name)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(this.heritage.summary)
        .fontSize(12)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
      Text(`${this.heritage.era} · ${this.heritage.city}`)
        .fontSize(10)
        .fontColor(getEraTheme(this.heritage.era).deep)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })
    }
    .width(150)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(getEraTheme(this.heritage.era).soft)
    .borderRadius(10)
    .border({ width: 1, color: ThemeTokens.DIVIDER })
    .margin({ right: 10 })
    .onClick(() => {
      this.onTap();
    })
  }
}
