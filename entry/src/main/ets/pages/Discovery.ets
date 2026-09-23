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
 * - 年代/类型/城市三个维度可组合，默认「全部」（哨兵值 ALL_FILTER，即空串）；
 * - 关键词匹配名称与简介（子串包含，忽略首尾空格）；
 * - 筛选选项直接取自枚举值（中文字符串），避免与 Types.ets 漂移；
 * - 单一数据源：chips 高亮、结果计数、列表内容全部由同一组 @State 派生，
 *   三者不会各自为政（详见 FilterRow 组件注释）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { Heritage } from '../model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../model/Types';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'Discovery';

/** 「全部」哨兵值：三个筛选维度统一用它表示未筛选，避免 null 与空串两套语义 */
const ALL_FILTER: string = '';

/**
 * 单维度筛选行：维度标签 + 横向滚动 chips（含「全部」）。
 *
 * 为什么做成子组件而不是 @Builder（踩坑清单第 15 条）：
 * @Builder 默认「按值传递」参数，状态变量的改变不会引起其内部 UI 刷新。
 * 之前筛选逻辑放在 @Builder 里，导致列表已按新条件筛选、chips 高亮却停在初始值。
 * 这里用 @Prop 把选中值与父组件状态单向绑定，父组件状态一变，子组件即可重新渲染，
 * 从而保证「列表结果」与「按钮高亮」始终同源同步。
 */
@Component
struct FilterRow {
  label: string = '';
  options: string[] = [];
  /** 选中值，ALL_FILTER（空串）表示「全部」 */
  @Prop selected: string = ALL_FILTER;
  onSelect: (value: string) => void = () => {};

  /** 选项列表：首位插入「全部」哨兵，与父组件筛选语义保持一致 */
  private chipOptions(): string[] {
    const result: string[] = [ALL_FILTER];
    for (let i = 0; i < this.options.length; i++) {
      result.push(this.options[i]);
    }
    return result;
  }

  build() {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor('#8D6E63')
        .width(40)
      Scroll() {
        Row() {
          ForEach(this.chipOptions(), (opt: string) => {
            Text(opt === ALL_FILTER ? '全部' : opt)
              .fontSize(13)
              .fontColor(this.selected === opt ? '#FFFFFF' : '#6D4C41')
              .backgroundColor(this.selected === opt ? '#6D4C41' : '#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .border({ width: 1, color: this.selected === opt ? '#6D4C41' : '#E0D6CC' })
              .margin({ right: 8 })
              .onClick(() => {
                this.onSelect(opt);
              })
          }, (opt: string) => `${opt}-${this.selected === opt}`)
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
}

@Component
export struct Discovery {
  @State heritageList: Heritage[] = [];
  @State isLoading: boolean = true;
  @State loadFailed: boolean = false;
  @State isMockData: boolean = false;
  // 检索关键词（匹配名称/简介）
  @State keyword: string = '';
  // 三维度筛选，ALL_FILTER（空串）表示「全部」；值为枚举的中文字符串
  @State selectedEra: string = ALL_FILTER;
  @State selectedType: string = ALL_FILTER;
  @State selectedCity: string = ALL_FILTER;

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
      if (this.selectedEra !== ALL_FILTER && item.era !== this.selectedEra) {
        continue;
      }
      if (this.selectedType !== ALL_FILTER && item.type !== this.selectedType) {
        continue;
      }
      if (this.selectedCity !== ALL_FILTER && item.city !== this.selectedCity) {
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

      // 三维度筛选：子组件 @Prop 绑定父组件状态，chips 高亮与列表结果同源
      Column({ space: 8 }) {
        FilterRow({
          label: '年代',
          options: this.eraOptions,
          selected: this.selectedEra,
          onSelect: (v: string) => {
            this.selectedEra = v;
          }
        })
        FilterRow({
          label: '类型',
          options: this.typeOptions,
          selected: this.selectedType,
          onSelect: (v: string) => {
            this.selectedType = v;
          }
        })
        FilterRow({
          label: '城市',
          options: this.cityOptions,
          selected: this.selectedCity,
          onSelect: (v: string) => {
            this.selectedCity = v;
          }
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
