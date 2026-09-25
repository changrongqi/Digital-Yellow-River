/**
 * 收藏页（M2.2）：收藏列表按标签分组 + 自定义标签管理。
 *
 * 数据流（单一数据源 = FavoriteService，计划书 §3 分层约定）：
 * - aboutToAppear：FavoriteService.init(context)（幂等）→ 加载预置遗产映射表
 *   （HeritageDataLoader 进程内缓存）→ 组装分组显示模型；groups 用 @State 整体赋值刷新（踩坑 5）；
 * - 一切变更（取消收藏/编辑标签/删除自定义标签）走 FavoriteService，完成后重新组装 groups；
 * - 卡片点击统一带 id 跳详情页（O2 约定）；
 * - 取消收藏不级联删除笔记（项目约定，确认弹层文案中注明）。
 *
 * UI 结构：
 * - 分组列表：每个「使用中的标签」一个 ListItemGroup（内置在前、自定义按首次出现顺序），
 *   末尾「未分组」收纳无标签收藏；空分组不显示（页面保持简洁）；
 * - 卡片 = 文字徽标（城市/年代，数据源缺失时灰色）+ 名称/摘要/标签 chips/收藏时间/笔记数；
 * - 弹层（操作菜单 / 标签编辑 / 取消收藏确认）用页内 Stack + 条件渲染实现：
 *   ① 全部状态留在本组件内，规避 @Builder 参数按值传递的刷新失联（踩坑 15）；
 *   ② 遮罩 onClick 空实现只消费点击（防穿透到主内容），不承担关闭——
 *      子组件点击事件会冒泡，若遮罩可点关会造成标签编辑中误关；
 *   ③ 卡片「点主区域跳详情」与「⋯ 菜单按钮」是兄弟节点，避免嵌套点击冒泡。
 *
 * 预览兜底：rawfile 加载失败（预览器）时注入 MOCK_HERITAGES 构建映射表（只读、不写用户数据），
 * 顶部提示条与发现页行为一致；真机不受影响。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Heritage } from '../model/Heritage';
import { Favorite } from '../model/Favorite';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { FavoriteService } from '../service/FavoriteService';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'Favorites';

/** 无标签收藏的分组名 */
const TAG_UNGROUPED: string = '未分组';

/** 卡片标签 chips 显示上限，超出显示「+N」 */
const MAX_VISIBLE_TAGS: number = 3;

/** 弹层类型 */
enum SheetType {
  None,
  Menu,
  TagEditor,
  ConfirmRemove
}

/** 收藏卡片显示模型：收藏记录 + 关联 Heritage（null = 数据源缺失）+ 笔记数 */
class FavoriteCard {
  favorite: Favorite;
  heritage: Heritage | null;
  noteCount: number;

  constructor(favorite: Favorite, heritage: Heritage | null, noteCount: number) {
    this.favorite = favorite;
    this.heritage = heritage;
    this.noteCount = noteCount;
  }
}

/** 标签分组：每个使用中的标签一组（含「未分组」） */
class TagGroup {
  tag: string;
  cards: FavoriteCard[];

  constructor(tag: string, cards: FavoriteCard[]) {
    this.tag = tag;
    this.cards = cards;
  }
}

@Component
export struct Favorites {
  /** 分组显示数据（@State 整体赋值刷新，踩坑 5） */
  @State groups: TagGroup[] = [];
  @State favoriteCount: number = 0;
  @State isLoading: boolean = true;
  /** 预览示例数据标注（rawfile 加载失败注入 mock 时为 true） */
  @State isMockData: boolean = false;
  /** 当前弹层类型（None = 无弹层） */
  @State sheetType: SheetType = SheetType.None;
  /** 弹层目标的收藏 itemId 与显示名 */
  @State sheetItemId: string = '';
  @State sheetItemName: string = '';
  /** 标签编辑器：全部候选标签（内置 ∪ 使用中的自定义） */
  @State editorAllTags: string[] = [];
  /** 标签编辑器：当前已勾选标签 */
  @State editorSelected: string[] = [];
  /** 标签编辑器：新标签输入框内容 */
  @State newTagInput: string = '';

  /** itemId → Heritage 映射表（只读；预置数据加载完成后一次构建） */
  private heritageMap: Map<string, Heritage> = new Map();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      // 极端环境异常：仍渲染（空）列表，不阻塞页面
      hilog.error(DOMAIN, TAG, 'host context unavailable');
      this.isLoading = false;
      this.refreshGroups();
      return;
    }
    FavoriteService.init(context);
    this.loadHeritages(context);
  }

  /** 加载预置遗产数据构建映射表（进程内缓存，发现页加载过一次后此处纯内存取数） */
  private async loadHeritages(context: common.Context): Promise<void> {
    let list: Heritage[] = [];
    try {
      list = await HeritageDataLoader.loadHeritageList(context);
      this.isMockData = false;
    } catch (err) {
      // 预览器无法读取 rawfile：注入示例数据仅作预览调试（只读，不写用户数据），与发现页行为一致
      hilog.error(DOMAIN, TAG, 'load heritages failed, fallback to mock: %{public}s', JSON.stringify(err));
      list = MOCK_HERITAGES;
      this.isMockData = true;
    }
    const map: Map<string, Heritage> = new Map();
    for (let i = 0; i < list.length; i++) {
      map.set(list[i].id, list[i]);
    }
    this.heritageMap = map;
    this.isLoading = false;
    this.refreshGroups();
  }

  /**
   * 从 FavoriteService 重新组装分组显示数据（整体赋值触发刷新）。
   * 分组顺序 = getAllTags 顺序（内置在前、自定义按首次出现），「未分组」殿后；空分组不显示。
   */
  private refreshGroups(): void {
    const favorites: Favorite[] = FavoriteService.getAllFavorites();
    const tags: string[] = FavoriteService.getAllTags();
    const groups: TagGroup[] = [];
    for (let i = 0; i < tags.length; i++) {
      const tag: string = tags[i];
      const cards: FavoriteCard[] = [];
      for (let j = 0; j < favorites.length; j++) {
        const fav: Favorite = favorites[j];
        if (fav.tags.indexOf(tag) >= 0) {
          cards.push(this.makeCard(fav));
        }
      }
      if (cards.length > 0) {
        groups.push(new TagGroup(tag, cards));
      }
    }
    const untagged: FavoriteCard[] = [];
    for (let i = 0; i < favorites.length; i++) {
      const fav: Favorite = favorites[i];
      if (fav.tags.length === 0) {
        untagged.push(this.makeCard(fav));
      }
    }
    if (untagged.length > 0) {
      groups.push(new TagGroup(TAG_UNGROUPED, untagged));
    }
    this.groups = groups;
    this.favoriteCount = favorites.length;
  }

  private makeCard(fav: Favorite): FavoriteCard {
    const heritage: Heritage | undefined = this.heritageMap.get(fav.itemId);
    return new FavoriteCard(
      fav,
      heritage === undefined ? null : heritage,
      FavoriteService.getNotesByItem(fav.itemId).length
    );
  }

  private cardName(card: FavoriteCard): string {
    return card.heritage === null ? `数据缺失 (${card.favorite.itemId})` : card.heritage.name;
  }

  /** 毫秒时间戳 → yyyy-MM-dd */
  private formatDate(ts: number): string {
    const d: Date = new Date(ts);
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const monthStr: string = month < 10 ? `0${month}` : `${month}`;
    const dayStr: string = day < 10 ? `0${day}` : `${day}`;
    return `${d.getFullYear()}-${monthStr}-${dayStr}`;
  }

  /** 卡片标签显示上限截取 */
  private visibleTags(tags: string[]): string[] {
    return tags.slice(0, MAX_VISIBLE_TAGS);
  }

  /** 分组键：含组内全部 itemId，内容变化即重建节点 */
  private groupKey(group: TagGroup): string {
    let key: string = group.tag;
    for (let i = 0; i < group.cards.length; i++) {
      key = `${key}-${group.cards[i].favorite.itemId}`;
    }
    return key;
  }

  /** 卡片键：itemId + updatedAt（标签变更）+ noteCount（笔记增删） */
  private cardKey(card: FavoriteCard): string {
    return `${card.favorite.itemId}-${card.favorite.updatedAt}-${card.noteCount}`;
  }

  private isBuiltInTag(tag: string): boolean {
    return FavoriteService.BUILT_IN_TAGS.indexOf(tag) >= 0;
  }

  // ==================== 弹层状态与操作 ====================

  private openMenu(itemId: string, name: string): void {
    this.sheetItemId = itemId;
    this.sheetItemName = name;
    this.sheetType = SheetType.Menu;
  }

  private openTagEditor(): void {
    const fav: Favorite | null = FavoriteService.getFavorite(this.sheetItemId);
    if (fav === null) {
      // 目标已不存在（如刚被取消收藏），不打开编辑器
      this.closeSheet();
      return;
    }
    this.editorAllTags = FavoriteService.getAllTags();
    this.editorSelected = fav.tags.slice();
    this.newTagInput = '';
    this.sheetType = SheetType.TagEditor;
  }

  private closeSheet(): void {
    this.sheetType = SheetType.None;
    this.sheetItemId = '';
    this.sheetItemName = '';
    this.editorAllTags = [];
    this.editorSelected = [];
    this.newTagInput = '';
  }

  /** 勾选/取消勾选标签（整体赋值，踩坑 5） */
  private toggleEditorTag(tag: string): void {
    const idx: number = this.editorSelected.indexOf(tag);
    const next: string[] = this.editorSelected.slice();
    if (idx >= 0) {
      next.splice(idx, 1);
    } else {
      next.push(tag);
    }
    this.editorSelected = next;
  }

  /** 删除自定义标签：removeTag 全局移除使用处；内置标签不提供删除（removeTag 只清使用处、内置候选保留，UI 上易造成误解） */
  private removeEditorTag(tag: string): void {
    if (this.isBuiltInTag(tag)) {
      return;
    }
    FavoriteService.removeTag(tag);
    this.refreshGroups();
    const allIdx: number = this.editorAllTags.indexOf(tag);
    if (allIdx >= 0) {
      const nextAll: string[] = this.editorAllTags.slice();
      nextAll.splice(allIdx, 1);
      this.editorAllTags = nextAll;
    }
    const selIdx: number = this.editorSelected.indexOf(tag);
    if (selIdx >= 0) {
      const nextSel: string[] = this.editorSelected.slice();
      nextSel.splice(selIdx, 1);
      this.editorSelected = nextSel;
    }
  }

  /** 新增自定义标签：非空去重后立即勾选（保存时随勾选集合持久化到该收藏） */
  private addNewTag(): void {
    const name: string = this.newTagInput.trim();
    if (name === '') {
      return;
    }
    if (this.editorAllTags.indexOf(name) < 0) {
      const nextAll: string[] = this.editorAllTags.slice();
      nextAll.push(name);
      this.editorAllTags = nextAll;
    }
    if (this.editorSelected.indexOf(name) < 0) {
      const nextSel: string[] = this.editorSelected.slice();
      nextSel.push(name);
      this.editorSelected = nextSel;
    }
    this.newTagInput = '';
  }

  private saveTags(): void {
    FavoriteService.updateFavoriteTags(this.sheetItemId, this.editorSelected);
    this.refreshGroups();
    this.closeSheet();
  }

  private confirmRemove(): void {
    FavoriteService.removeFavorite(this.sheetItemId);
    this.refreshGroups();
    this.closeSheet();
  }

  build() {
    Stack() {
      Column() {
        // 顶部标题栏
        Row() {
          Text('我的收藏')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
          Blank()
          Text(`${this.favoriteCount} 处`)
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
            Text('正在加载收藏…')
              .fontSize(14)
              .fontColor('#8D6E63')
              .margin({ top: 12 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else if (this.favoriteCount === 0) {
          // 空态兜底（工程惯例：无数据需明确提示）
          Column() {
            Text('暂无收藏')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6D4C41')
            Text('去发现页探索黄河文化遗产')
              .fontSize(13)
              .fontColor('#8D6E63')
              .margin({ top: 8 })
            Text('在详情页点击收藏后，可回到这里按标签查看')
              .fontSize(13)
              .fontColor('#8D6E63')
              .margin({ top: 4 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else {
          // mock 示例数据提示条（仅加载失败兜底时出现）
          if (this.isMockData) {
            Row() {
              Text('示例数据 · 预览调试专用（rawfile 加载失败）')
                .fontSize(12)
                .fontColor('#8D6E63')
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .backgroundColor('#FFF3E0')
                .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ bottom: 10 })
          }

          List() {
            ForEach(this.groups, (group: TagGroup) => {
              ListItemGroup({ header: this.GroupHeaderView(group.tag, group.cards.length), space: 12 }) {
                ForEach(group.cards, (card: FavoriteCard) => {
                  ListItem() {
                    this.FavoriteCardView(card)
                  }
                }, (card: FavoriteCard) => this.cardKey(card))
              }
            }, (group: TagGroup) => this.groupKey(group))
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

      // 弹层：遮罩 + 对话框（一律经显式按钮关闭）
      if (this.sheetType !== SheetType.None) {
        Column() {
          if (this.sheetType === SheetType.Menu) {
            this.MenuSheet()
          } else if (this.sheetType === SheetType.TagEditor) {
            this.TagEditorSheet()
          } else {
            this.ConfirmRemoveSheet()
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(62,39,35,0.45)')
        .onClick(() => {
          // 空实现消费点击：防止穿透到主内容；
          // 不能承担「点遮罩关闭」——子组件点击事件冒泡至此，会造成标签编辑中被误关。
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 分组头（tag/count 均为派生数据，groups 整体重建时随之刷新，无踩坑 15 风险） */
  @Builder
  GroupHeaderView(tag: string, count: number) {
    Row() {
      Text(tag)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(`${count} 处`)
        .fontSize(12)
        .fontColor('#8D6E63')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 4 })
  }

  /** 收藏卡片：主区域点击跳详情；⋯ 按钮与主区域为兄弟节点，避免嵌套点击冒泡 */
  @Builder
  FavoriteCardView(card: FavoriteCard) {
    Row() {
      // 主内容区域（点击跳详情，统一带 id，O2 约定）
      Row() {
        // 文字徽标（城市/年代；数据源缺失时灰色 + '?'）
        Column() {
          Text(card.heritage === null ? '?' : card.heritage.city)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          if (card.heritage !== null) {
            Text(card.heritage.era)
              .fontSize(11)
              .fontColor('#FFE0B2')
              .margin({ top: 4 })
          }
        }
        .justifyContent(FlexAlign.Center)
        .width(72)
        .height(72)
        .borderRadius(10)
        .backgroundColor(card.heritage === null ? '#9E9E9E' : '#8D6E63')

        Column() {
          Text(this.cardName(card))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (card.heritage !== null) {
            Text(card.heritage.summary)
              .fontSize(13)
              .fontColor('#6D4C41')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 6 })
          }
          // 标签 chips（最多 3 个 + 「+N」）
          Row() {
            ForEach(this.visibleTags(card.favorite.tags), (t: string) => {
              Text(t)
                .fontSize(11)
                .fontColor('#8D6E63')
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor('#EFEBE9')
                .borderRadius(6)
                .margin({ right: 6 })
            }, (t: string) => t)
            if (card.favorite.tags.length > MAX_VISIBLE_TAGS) {
              Text(`+${card.favorite.tags.length - MAX_VISIBLE_TAGS}`)
                .fontSize(11)
                .fontColor('#8D6E63')
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor('#EFEBE9')
                .borderRadius(6)
            }
          }
          .margin({ top: 8 })
          .alignItems(VerticalAlign.Center)

          // 收藏时间 + 笔记数
          Row() {
            Text(`收藏于 ${this.formatDate(card.favorite.createdAt)}`)
              .fontSize(11)
              .fontColor('#BCAAA4')
            if (card.noteCount > 0) {
              Text(`${card.noteCount} 条笔记`)
                .fontSize(11)
                .fontColor('#BCAAA4')
                .margin({ left: 12 })
            }
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .layoutWeight(1)
      .onClick(() => {
        if (card.heritage !== null) {
          router.pushUrl({ url: 'pages/Detail', params: { id: card.favorite.itemId } });
        }
      })

      // 「⋯」菜单按钮（兄弟节点，点击不会冒泡到主区域的跳转 onClick）
      Text('⋯')
        .fontSize(22)
        .fontColor('#8D6E63')
        .padding({ left: 8, right: 4, top: 4, bottom: 4 })
        .margin({ left: 4 })
        .onClick(() => {
          this.openMenu(card.favorite.itemId, this.cardName(card));
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  /** 操作菜单：管理标签 / 取消收藏 */
  @Builder
  MenuSheet() {
    Column() {
      Text('管理标签')
        .fontSize(16)
        .fontColor('#3E2723')
        .padding({ top: 14, bottom: 14 })
        .onClick(() => {
          this.openTagEditor();
        })
      Divider()
        .color('#E0D6CC')
        .margin({ left: 16, right: 16 })
      Text('取消收藏')
        .fontSize(16)
        .fontColor('#C0392B')
        .padding({ top: 14, bottom: 14 })
        .onClick(() => {
          this.sheetType = SheetType.ConfirmRemove;
        })
    }
    .width('64%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .clip(true)
  }

  /** 标签编辑器：候选 chips 多选 + 自定义标签删除 + 新增标签 */
  @Builder
  TagEditorSheet() {
    Column() {
      Text('管理标签')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(this.sheetItemName)
        .fontSize(13)
        .fontColor('#8D6E63')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })

      Text('选择标签')
        .fontSize(13)
        .fontColor('#8D6E63')
        .margin({ top: 16 })
        .alignSelf(ItemAlign.Start)

      // 候选标签：整块 chips 多选（复用发现页 chips 风格）；自定义标签带 ✕ 删除
      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.editorAllTags, (tag: string) => {
            Row() {
              Text(tag)
                .fontSize(13)
                .fontColor(this.editorSelected.indexOf(tag) >= 0 ? '#FFFFFF' : '#6D4C41')
                .onClick(() => {
                  this.toggleEditorTag(tag);
                })
              if (!this.isBuiltInTag(tag)) {
                Text('✕')
                  .fontSize(12)
                  .fontColor(this.editorSelected.indexOf(tag) >= 0 ? '#FFCCBC' : '#BCAAA4')
                  .padding({ left: 6, right: 2 })
                  .onClick(() => {
                    this.removeEditorTag(tag);
                  })
              }
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.editorSelected.indexOf(tag) >= 0 ? '#6D4C41' : '#FFFFFF')
            .borderRadius(14)
            .border({ width: 1, color: this.editorSelected.indexOf(tag) >= 0 ? '#6D4C41' : '#E0D6CC' })
            .margin({ right: 8, bottom: 8 })
          }, (tag: string) => `${tag}-${this.editorSelected.indexOf(tag) >= 0}-${this.isBuiltInTag(tag)}`)
        }
        .width('100%')
      }
      .align(Alignment.Start)
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 180 })
      .margin({ top: 8 })

      // 新增自定义标签
      Row({ space: 8 }) {
        TextInput({ placeholder: '自定义标签名', text: this.newTagInput })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#FAF6F0')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newTagInput = value;
          })
        Button('新增')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#6D4C41')
          .height(36)
          .onClick(() => {
            this.addNewTag();
          })
      }
      .width('100%')
      .margin({ top: 8 })

      // 操作按钮
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#6D4C41')
          .backgroundColor('#EFEBE9')
          .layoutWeight(1)
          .onClick(() => {
            this.closeSheet();
          })
        Button('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#6D4C41')
          .layoutWeight(1)
          .onClick(() => {
            this.saveTags();
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

  /** 取消收藏确认（文案注明笔记保留，对齐服务层约定） */
  @Builder
  ConfirmRemoveSheet() {
    Column() {
      Text('确认取消收藏')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3E2723')
      Text(`「${this.sheetItemName}」取消收藏后，相关笔记将保留不删除`)
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
            this.closeSheet();
          })
        Button('取消收藏')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#C0392B')
          .layoutWeight(1)
          .onClick(() => {
            this.confirmRemove();
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
