/**
 * 发现页（M1.3）：渲染 rawfile 预置文化条目列表。
 *
 * 兜底策略（踩坑清单第 1 条）：
 * - 加载中：转圈提示；
 * - 解析失败 / 空数据：占位文案，不崩溃；
 * - 加载失败时注入 mock 示例数据渲染列表（DevEco 预览器无法读取 rawfile，
 *   便于预览器调试 UI；真机正常走 rawfile，不受影响），列表顶部标注「示例数据」。
 *
 * 筛选 + 检索属于 M1.4，本页当前只负责列表展示。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage } from '../model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../model/Types';
import { HeritageDataLoader } from '../data/HeritageDataLoader';

const DOMAIN = 0x0000;
const TAG = 'Discovery';

/**
 * 预览环境兜底示例数据（与 heritage_data.json 字段一致）。
 * 仅在 rawfile 加载失败时注入（典型场景：预览器无资源访问能力）。
 */
const MOCK_HERITAGES: Heritage[] = [
  {
    id: 'mock-yangshao',
    name: '仰韶村遗址',
    era: HeritageEra.YANGSHAO,
    type: HeritageType.KILN_SITE,
    city: HeritageCity.SANMENXIA,
    coverImage: '',
    summary: '中国现代考古学的诞生地，仰韶文化命名地，出土大量彩陶器物的新石器时代聚落遗址。',
    detail: { intro: '', discovery: '', events: [], poems: [], tourism: '' }
  },
  {
    id: 'mock-erlitou',
    name: '二里头遗址',
    era: HeritageEra.XIA_SHANG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.LUOYANG,
    coverImage: '',
    summary: '被誉为「最早的中国」，学界公认的夏朝中晚期都城遗址，发现中国最早的宫城、青铜礼器群与绿松石龙形器。',
    detail: { intro: '', discovery: '', events: [], poems: [], tourism: '' }
  },
  {
    id: 'mock-yinxu',
    name: '殷墟',
    era: HeritageEra.XIA_SHANG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.ANYANG,
    coverImage: '',
    summary: '商代晚期都城遗址，中国历史上第一个有文献可考并为考古证实的都城，甲骨文的发现地，世界文化遗产。',
    detail: { intro: '', discovery: '', events: [], poems: [], tourism: '' }
  },
  {
    id: 'mock-tokyo',
    name: '北宋东京城遗址',
    era: HeritageEra.SONG,
    type: HeritageType.CAPITAL_SITE,
    city: HeritageCity.KAIFENG,
    coverImage: '',
    summary: '北宋都城汴京故城遗址，州桥石壁浮雕与汴河遗址印证「东京梦华」，世界城市史上罕见的「城摞城」。',
    detail: { intro: '', discovery: '', events: [], poems: [], tourism: '' }
  }
];

@Component
export struct Discovery {
  @State heritageList: Heritage[] = [];
  @State isLoading: boolean = true;
  @State loadFailed: boolean = false;
  @State isMockData: boolean = false;

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
      this.isMockData = false;
      hilog.info(DOMAIN, TAG, 'render %{public}d heritages', list.length);
    } catch (err) {
      // 预览器无法访问 rawfile 时会走到这里：注入示例数据保证 UI 可调试。
      // 真机正常走 rawfile，不受影响；万一真机失败，列表顶部有「示例数据」标注。
      hilog.error(DOMAIN, TAG, 'load failed, fallback to mock: %{public}s', JSON.stringify(err));
      this.heritageList = MOCK_HERITAGES;
      this.loadFailed = true;
      this.isMockData = true;
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
      } else if (this.heritageList.length === 0) {
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
        // mock 示例数据提示条（仅加载失败兜底时出现）
        if (this.isMockData) {
          Row() {
            Row() {
              Text('示例数据 · 预览调试专用（rawfile 加载失败）')
                .fontSize(12)
                .fontColor('#8D6E63')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .backgroundColor('#FFF3E0')
            .borderRadius(8)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 10 })
        }

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
