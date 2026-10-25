/**
 * 笔记编辑页（M2.3）：文字笔记 + 自动时间戳。
 *
 * 路由：从详情页笔记入口进入（M2.4 接入），utils/RouterUtil.push('pages/NoteEdit', { id, noteId? })：
 * - id = 所属文化条目 itemId（O2 约定：统一带 id）；
 * - noteId 缺省 = 新建笔记，带 noteId = 编辑已有笔记。
 *
 * 数据流（单一数据源 = FavoriteService）：
 * - 时间戳全自动维护：新建走 addNote（自动记 createdAt/updatedAt/deviceId，踩坑 3），
 *   编辑走 updateNote（自动刷 updatedAt），页面不手写任何时间；
 * - 空正文拒绝：服务层已实现（返回 false），UI 层先行拦截并显示行内提示，双重保险；
 * - 删除走 deleteNote + 二次确认弹层（与收藏页同款 Stack 弹层模式）。
 * - M6.4 未保存退出保护：正文与载入时的原始内容不一致即视为脏数据，
 *   顶部返回与系统返回（onBackPress）统一走 handleBack；有未保存内容先弹「放弃修改」确认，
 *   取消留在本页、确认放弃才离开；保存/删除成功后直接离开，不重复拦截。
 *
 * 标签说明（计划书 M2.3 修订，动态演进首例）：标签属于收藏维度（M2.2 已在收藏页
 * 实现标签管理），Note 模型不带 tags（M3 分布式同步保持轻量）；本页聚焦纯文字编辑。
 *
 * 预览兜底：直接预览本页（无路由参数）时为新建模式、无条目语境，仅可预览 UI；
 * 完整数据流验证需 M2.4 详情页笔记入口接入后进行。
 */

import { Heritage } from '../model/Heritage';
import { Note } from '../model/Note';
import { HeritageRepository, HeritageLoadResult } from '../data/HeritageRepository';
import { FavoriteService } from '../service/FavoriteService';
import { formatDateTime } from '../utils/TimeFormat';
import { ThemeTokens } from '../utils/ThemeTokens';
import { RouterUtil } from '../utils/RouterUtil';

@Entry
@Component
struct NoteEdit {
  /** 笔记正文 */
  @State content: string = '';
  /** 所属文化条目 id（空 = 预览器无参场景，仅可预览 UI） */
  @State itemId: string = '';
  /** 编辑目标笔记 id（空 = 新建） */
  @State noteId: string = '';
  /** 条目名（语境提示行用） */
  @State itemTitle: string = '';
  /** 原笔记时间戳（编辑模式显示；新建为 0） */
  @State createdAt: number = 0;
  @State updatedAt: number = 0;
  /** 载入时的原始正文（M6.4 脏标记基准；新建为空串） */
  @State originalContent: string = '';
  /** 行内提示（空正文/保存失败；空串 = 不显示），输入即清除 */
  @State warnText: string = '';
  /** 删除确认弹层开关 */
  @State confirmDeleting: boolean = false;
  /** 未保存退出确认弹层开关（M6.4） */
  @State confirmDiscarding: boolean = false;
  /** 条目语境加载中 */
  @State isLoading: boolean = true;
  /** 已进入离开流程（保存/删除/确认放弃后），防止 RouterUtil.back 再次触发拦截 */
  private leaving: boolean = false;

  aboutToAppear(): void {
    const params = RouterUtil.getParams();
    if (params !== undefined) {
      const idObj: Object | undefined = params['id'];
      if (idObj !== undefined && idObj !== null) {
        this.itemId = String(idObj);
      }
      const noteObj: Object | undefined = params['noteId'];
      if (noteObj !== undefined && noteObj !== null) {
        this.noteId = String(noteObj);
      }
    }
    // FavoriteService 幂等初始化（主页已初始化则直接返回）
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      FavoriteService.init(hostContext);
    }
    this.loadContext();
  }

  /** 加载条目名（语境行）+ 编辑模式回填原笔记 */
  private async loadContext(): Promise<void> {
    // M4：统一走 HeritageRepository（rawfile 优先、失败注入 mock、id 映射缓存）。
    const result: HeritageLoadResult = await HeritageRepository.load(this.getUIContext().getHostContext());
    const heritage: Heritage | undefined = result.byId.get(this.itemId);
    if (heritage !== undefined) {
      this.itemTitle = heritage.name;
    }
    // 编辑模式：按 noteId 回填正文与时间戳（从服务层重新取数，数据单一来源）
    if (this.noteId !== '') {
      const notes: Note[] = FavoriteService.getNotesByItem(this.itemId);
      for (let i = 0; i < notes.length; i++) {
        if (notes[i].id === this.noteId) {
          // M6.4 复核补强：载入前用户可能已开始输入（TextArea 在加载中仍可编辑），
          // 此时不能覆盖输入内容；原始基准仍取服务层原稿，保证脏标记正确。
          if (!this.isDirty()) {
            this.content = notes[i].content;
          }
          this.originalContent = notes[i].content;
          this.createdAt = notes[i].createdAt;
          this.updatedAt = notes[i].updatedAt;
          break;
        }
      }
    }
    this.isLoading = false;
  }

  /** 保存：新建走 addNote / 编辑走 updateNote，时间戳由服务层自动维护 */
  private save(): void {
    const trimmed: string = this.content.trim();
    if (trimmed === '') {
      this.warnText = '笔记内容不能为空';
      return;
    }
    let ok: boolean = false;
    if (this.noteId === '') {
      ok = FavoriteService.addNote(this.itemId, trimmed);
    } else {
      ok = FavoriteService.updateNote(this.noteId, trimmed);
    }
    if (ok) {
      this.goBack();
    } else {
      this.warnText = '保存失败，请重试';
    }
  }

  /** 删除笔记（编辑模式，经确认弹层触发） */
  private deleteCurrent(): void {
    FavoriteService.deleteNote(this.noteId);
    this.confirmDeleting = false;
    this.goBack();
  }

  /** 是否有未保存修改（M6.4） */
  private isDirty(): boolean {
    return this.content !== this.originalContent;
  }

  /**
   * 统一返回入口（顶部返回按钮与系统返回共用，M6.4）：
   * 有未保存内容先弹确认；无修改或已确认放弃则直接离开。
   * 始终消费本次返回事件，实际导航由 goBack 显式执行，避免与 onBackPress 默认逻辑重复出栈。
   */
  private handleBack(): boolean {
    if (this.confirmDeleting) {
      this.confirmDeleting = false;
      return true;
    }
    if (this.confirmDiscarding) {
      this.confirmDiscarding = false;
      return true;
    }
    if (!this.isDirty()) {
      this.goBack();
      return true;
    }
    this.confirmDiscarding = true;
    return true;
  }

  /** 系统返回拦截（M6.4）：保存/删除后的离开流程不再重复拦截 */
  onBackPress(): boolean {
    if (this.leaving) {
      return true;
    }
    return this.handleBack();
  }

  /** 返回上一页（统一走 RouterUtil） */
  private goBack(): void {
    this.leaving = true;
    RouterUtil.back();
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏：返回 + 标题 + 删除（仅编辑模式）
        Row() {
          Text('‹')
            .fontSize(30)
            .fontColor(ThemeTokens.PRIMARY)
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .accessibilityText('返回')
            .accessibilityLevel('yes')
            .onClick(() => {
              this.handleBack();
            })
          Text(this.noteId === '' ? '新建笔记' : '编辑笔记')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
          if (this.noteId !== '') {
            Text('删除')
              .fontSize(14)
              .fontColor(ThemeTokens.DANGER)
              .constraintSize({ minHeight: 44 })
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .accessibilityText('删除笔记')
              .accessibilityLevel('yes')
              .onClick(() => {
                this.confirmDeleting = true;
              })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 20, top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)

        // 编辑区：条目语境 + 正文输入 + 时间戳
        Scroll() {
          Column() {
            if (this.itemTitle !== '') {
              Text(`关于「${this.itemTitle}」`)
                .fontSize(13)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .margin({ bottom: 8 })
            }
            TextArea({ placeholder: '记录你的想法…', text: this.content })
              .fontSize(15)
              .fontColor(ThemeTokens.TEXT_PRIMARY)
              .backgroundColor(ThemeTokens.BG_PAGE)
              .borderRadius(8)
              .constraintSize({ minHeight: 240, maxHeight: 480 })
              .onChange((value: string) => {
                this.content = value;
                if (this.warnText !== '') {
                  this.warnText = '';
                }
              })
            // 自动时间戳展示（编辑模式；新建保存后由服务层自动记录）
            if (this.createdAt > 0) {
              Column() {
                Text(`创建于 ${formatDateTime(this.createdAt)}`)
                  .fontSize(12)
                  .fontColor(ThemeTokens.TEXT_MUTED)
                Text(`最后编辑 ${formatDateTime(this.updatedAt)}`)
                  .fontSize(12)
                  .fontColor(ThemeTokens.TEXT_MUTED)
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ top: 10 })
            }
            if (this.isLoading) {
              Text('正在加载…')
                .fontSize(12)
                .fontColor(ThemeTokens.TEXT_MUTED)
                .margin({ top: 10 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        // 底部固定操作区：行内提示 + 保存按钮
        Column() {
          if (this.warnText !== '') {
            Text(this.warnText)
              .fontSize(12)
              .fontColor(ThemeTokens.DANGER)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 6 })
          }
          Button('保存')
            .fontSize(15)
            .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
            .backgroundColor(ThemeTokens.PRIMARY)
            .width('100%')
            .height(44)
            .borderRadius(22)
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.BG_PAGE)

      // 删除确认弹层（与收藏页同款模式：遮罩空 onClick 消费点击，一律显式按钮关闭）
      if (this.confirmDeleting) {
        Column() {
          Column() {
            Text('确认删除笔记')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeTokens.TEXT_PRIMARY)
            Text('删除后不可恢复')
              .fontSize(13)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .margin({ top: 10 })
            Row({ space: 12 }) {
              Button('再想想')
                .fontSize(14)
                .fontColor(ThemeTokens.PRIMARY)
                .backgroundColor(ThemeTokens.BG_SOFT)
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.confirmDeleting = false;
                })
              Button('删除')
                .fontSize(14)
                .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ThemeTokens.DANGER)
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.deleteCurrent();
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
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(62,39,35,0.45)')
        .onClick(() => {
          // 空实现消费点击：防穿透到主内容；不承担关闭（点击冒泡会误关）
        })
      }

      // 未保存退出确认弹层（M6.4：与删除弹层同款 Stack 模式，一律显式按钮关闭）
      if (this.confirmDiscarding) {
        Column() {
          Column() {
            Text('放弃未保存的修改？')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeTokens.TEXT_PRIMARY)
            Text('返回后本次编辑的内容将丢失')
              .fontSize(13)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .margin({ top: 10 })
            Row({ space: 12 }) {
              Button('继续编辑')
                .fontSize(14)
                .fontColor(ThemeTokens.PRIMARY)
                .backgroundColor(ThemeTokens.BG_SOFT)
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.confirmDiscarding = false;
                })
              Button('放弃修改')
                .fontSize(14)
                .fontColor(ThemeTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ThemeTokens.DANGER)
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.confirmDiscarding = false;
                  this.goBack();
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
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(62,39,35,0.45)')
        .onClick(() => {
          // 空实现消费点击：防穿透到主内容；不承担关闭（点击冒泡会误关）
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
