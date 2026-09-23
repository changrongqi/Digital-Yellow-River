/**
 * 发现页：rawfile 预置文化条目列表（M1.3）+ 三维度筛选与关键词检索（M1.4）。
 *
 * 兜底策略（踩坑清单第 1 条）：
 * - 加载中：转圈提示；
 * - 解析失败 / 空数据：占位文案，不崩溃；
 * - 加载失败时注入 mock 示例数据渲染列表（DevEco 预览器无法读取 rawfile，
 *   便于预览器调试 UI；真机正常走 rawfile，不受影响），列表顶部标注「示例数据」。
 *
 * 筛选说明（M1.4）：
 * - 年代/类型/城市三个维度可组合，默认「全部」（null）；
 * - 关键词匹配名称与简介（子串包含，忽略首尾空格）；
 * - 筛选选项直接取自枚举值（中文字符串），避免与 Types.ets 漂移。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { Heritage } from '../model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../model/Types';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'Discovery';

@Component
export struct Discovery {
  @State heritageList: Heritage[] = [];
  @State isLoading: boolean = true;
  @State loadFailed: boolean = false;
  @State isMockData: boolean = false;
  // 检索关键词（匹配名称/简介）
  @State keyword: string = '';
  // 三维度筛选，null 表示「全部」；值为枚举的中文字符串
  @State selectedEra: string | null = null;
  @State selectedType: string | null = null;
  @State selectedCity: string | null = null;

  // 筛选选项直接取自枚举值，避免与 Types.ets 漂移
  private readonly eraOptions: string[] = [
    HeritageEra.YANGSHAO, HeritageEra.LONGSHAN, HeritageEra.XIA_SHANG,
    HeritageEra.ZHOU, HeritageEra.HAN_TANG, HeritageEra.SONG
  ];
  private readonly typeOptions: string[] = [
    HeritageType.CAPITAL_SITE, HeritageType.TOMB_GROUP,
    HeritageType.KILN_SITE, HeritageType.ANCIENT_BUILDING
  ];
  private readonly cityOptions: string[] = [
    HeritageCity.SANMENXIA, HeritageCity.LUOYANG, HeritageCity.ZHENGZHOU,
    HeritageCity.KAIFENG, HeritageCity.PUYANG, HeritageCity.ANYANG
  ];

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

  /**
   * 三维度组合筛选 + 关键词检索。
   * 在 build 中调用，@State 变更自动触发重算。
   */
  private filterList(): Heritage[] {
    const kw: string = this.keyword.trim();
    const result: Heritage[] = [];
    for (let i = 0; i < this.heritageList.length; i++) {
      const item: Heritage = this.heritageList[i];
      if (this.selectedEra !== null && item.era !== this.selectedEra) {
        continue;
      }
      if (this.selectedType !== null && item.type !== this.selectedType) {
        continue;
      }
      if (this.selectedCity !== null && item.city !== this.selectedCity) {
        continue;
      }
      if (kw.length > 0 && !item.name.includes(kw) && !item.summary.includes(kw)) {
        continue;
      }
      result.push(item);
    }
    return result;
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
        Text(`${this.filterList().length} 处遗产`)
          .fontSize(13)
          .fontColor('#8D6E63')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 关键词检索框
      Row() {
        Search({ placeholder: '搜索遗址名称 / 简介关键词' })
          .width('100%')
          .height(40)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .onChange((value: string) => {
            this.keyword = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 10 })

      // 三维度筛选
      Column({ space: 8 }) {
        this.FilterRow('年代', this.eraOptions, this.selectedEra, (v: string | null) => {
          this.selectedEra = v;
        })
        this.FilterRow('类型', this.typeOptions, this.selectedType, (v: string | null) => {
          this.selectedType = v;
        })
        this.FilterRow('城市', this.cityOptions, this.selectedCity, (v: string | null) => {
          this.selectedCity = v;
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 10 })

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

        if (this.filterList().length === 0) {
          // 有数据但筛选/检索无结果
          Column() {
            Text('没有符合条件的遗产')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6D4C41')
            Text('试试调整筛选条件或更换关键词')
              .fontSize(13)
              .fontColor('#8D6E63')
              .margin({ top: 8 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else {
          List({ space: 12 }) {
            ForEach(this.filterList(), (item: Heritage) => {
              ListItem() {
                this.HeritageCard(item)
              }
              .onClick(() => {
                // M1.5：点击跳转详情页，传遗址 id，详情页按 id 重新取数
                router.pushUrl({ url: 'pages/Detail', params: { id: item.id } });
              })
            }, (item: Heritage) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF6F0')
  }

  /**
   * 单维度筛选行：维度标签 + 横向滚动 chips（含「全部」）。
   */
  @Builder
  FilterRow(label: string, options: string[], selected: string | null, onSelect: (value: string | null) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#8D6E63')
        .width(40)
      Scroll() {
        Row() {
          this.FilterChip('全部', selected === null, () => {
            onSelect(null);
          })
          ForEach(options, (opt: string) => {
            this.FilterChip(opt, selected === opt, () => {
              onSelect(opt);
            })
          }, (opt: string) => opt)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  FilterChip(title: string, selected: boolean, onSelect: () => void) {
    Text(title)
      .fontSize(13)
      .fontColor(selected ? '#FFFFFF' : '#6D4C41')
      .backgroundColor(selected ? '#6D4C41' : '#FFFFFF')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .border({ width: 1, color: selected ? '#6D4C41' : '#E0D6CC' })
      .margin({ right: 8 })
      .onClick(onSelect)
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
