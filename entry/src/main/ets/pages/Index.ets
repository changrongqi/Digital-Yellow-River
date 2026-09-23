/**
 * 主页（M1.3）：Tabs 容器
 * - 发现：Discovery（rawfile 数据列表）
 * - 收藏：占位（M2 实现）
 * - 同步：占位（M3 实现）
 */

import { Discovery } from './Discovery';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Discovery()
      }
      .tabBar(this.TabLabel('发现', 0))

      TabContent() {
        this.PlaceholderTab('收藏', '收藏与笔记功能将在 M2 里程碑上线')
      }
      .tabBar(this.TabLabel('收藏', 1))

      TabContent() {
        this.PlaceholderTab('同步', '分布式数据同步将在 M3 里程碑上线')
      }
      .tabBar(this.TabLabel('同步', 2))
    }
    .barWidth('100%')
    .barHeight(56)
    .divider({ strokeWidth: 0.5, color: '#E0D6CC' })
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  @Builder
  TabLabel(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? '#6D4C41' : '#BCAAA4')
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  PlaceholderTab(title: string, tip: string) {
    Column() {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(tip)
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
