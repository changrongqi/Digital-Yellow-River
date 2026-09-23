/**
 * 发现页（M1.3）：渲染 rawfile 预置文化条目列表。
 *
 * 兜底策略（踩坑清单第 1 条）：
 * - 加载中：转圈提示；
 * - 解析失败 / 空数据：占位文案，不崩溃。
 *
 * 筛选 + 检索属于 M1.4，本页当前只负责列表展示。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage } from '../model/Heritage';
import { HeritageDataLoader } from '../data/HeritageDataLoader';

const DOMAIN = 0x0000;
const TAG = 'Discovery';

@Component
export struct Discovery {
  @State heritageList: Heritage[] = [];
  @State isLoading: boolean = true;
  @State loadFailed: boolean = false;

  aboutToAppear(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        throw new Error('host context unavailable');
      }
      const list: Heritage[] = await HeritageDataLoader.loadHeritageList(hostContext);
      this.heritageList = list;
      this.loadFailed = false;
      hilog.info(DOMAIN, TAG, 'render %{public}d heritages', list.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', JSON.stringify(err));
      this.heritageList = [];
      this.loadFailed = true;
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('黄河记忆')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')
        Blank()
        Text(`${this.heritageList.length} 处遗产`)
          .fontSize(13)
          .fontColor('#8D6E63')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

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
      } else if (this.loadFailed || this.heritageList.length === 0) {
        Column() {
          Text('暂无数据')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#6D4C41')
          Text(this.loadFailed ? '预置数据解析失败，请检查 rawfile 数据文件' : '预置数据为空')
            .fontSize(13)
            .fontColor('#8D6E63')
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 12 }) {
          ForEach(this.heritageList, (item: Heritage) => {
            ListItem() {
              this.HeritageCard(item)
            }
          }, (item: Heritage) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  @Builder
  HeritageCard(item: Heritage) {
    Row() {
      // 封面占位（coverImage 当前全为空，用文字徽标占位；后续接入 rawfile 图片）
      Column() {
        Text(item.city)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text(item.era)
          .fontSize(11)
          .fontColor('#FFE0B2')
          .margin({ top: 4 })
      }
      .justifyContent(FlexAlign.Center)
      .width(72)
      .height(72)
      .borderRadius(10)
      .backgroundColor('#8D6E63')

      Column() {
        Text(item.name)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3E2723')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.summary)
          .fontSize(13)
          .fontColor('#6D4C41')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
        Row() {
          Text(item.type)
            .fontSize(11)
            .fontColor('#8D6E63')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('#EFEBE9')
            .borderRadius(6)
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}
