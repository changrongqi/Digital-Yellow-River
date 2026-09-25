/**
 * 笔记编辑页（M2.3）：文字笔记 + 自动时间戳。
 *
 * 路由：从详情页笔记入口进入（M2.4 接入），router.pushUrl('pages/NoteEdit', { id, noteId? })：
 * - id = 所属文化条目 itemId（O2 约定：统一带 id）；
 * - noteId 缺省 = 新建笔记，带 noteId = 编辑已有笔记。
 *
 * 数据流（单一数据源 = FavoriteService）：
 * - 时间戳全自动维护：新建走 addNote（自动记 createdAt/updatedAt/deviceId，踩坑 3），
 *   编辑走 updateNote（自动刷 updatedAt），页面不手写任何时间；
 * - 空正文拒绝：服务层已实现（返回 false），UI 层先行拦截并显示行内提示，双重保险；
 * - 删除走 deleteNote + 二次确认弹层（与收藏页同款 Stack 弹层模式）。
 *
 * 标签说明（计划书 M2.3 修订，动态演进首例）：标签属于收藏维度（M2.2 已在收藏页
 * 实现标签管理），Note 模型不带 tags（M3 分布式同步保持轻量）；本页聚焦纯文字编辑。
 *
 * 预览兜底：直接预览本页（无路由参数）时为新建模式、无条目语境，仅可预览 UI；
 * 完整数据流验证需 M2.4 详情页笔记入口接入后进行。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage } from '../model/Heritage';
import { Note } from '../model/Note';
import { HeritageDataLoader } from '../data/HeritageDataLoader';
import { FavoriteService } from '../service/FavoriteService';
import { MOCK_HERITAGES } from '../data/MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'NoteEdit';

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
  /** 行内提示（空正文/保存失败；空串 = 不显示），输入即清除 */
  @State warnText: string = '';
  /** 删除确认弹层开关 */
  @State confirmDeleting: boolean = false;
  /** 条目语境加载中 */
  @State isLoading: boolean = true;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
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
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      hilog.error(DOMAIN, TAG, 'host context unavailable');
      this.isLoading = false;
      return;
    }
    let list: Heritage[] = [];
    try {
      list = await HeritageDataLoader.loadHeritageList(hostContext);
    } catch (err) {
      // 预览器无法读取 rawfile：注入示例数据兜底（与发现页/收藏页行为一致，只读）
      hilog.error(DOMAIN, TAG, 'load failed, fallback to mock: %{public}s', JSON.stringify(err));
      list = MOCK_HERITAGES;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.itemId) {
        this.itemTitle = list[i].name;
        break;
      }
    }
    // 编辑模式：按 noteId 回填正文与时间戳（从服务层重新取数，数据单一来源）
    if (this.noteId !== '') {
      const notes: Note[] = FavoriteService.getNotesByItem(this.itemId);
      for (let i = 0; i < notes.length; i++) {
        if (notes[i].id === this.noteId) {
          this.content = notes[i].content;
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

  /** 返回上一页（router.back 唯一调用点，收敛 deprecate 告警） */
  private goBack(): void {
    router.back();
  }

  /** 毫秒时间戳 → yyyy-MM-dd HH:mm */
  private formatDateTime(ts: number): string {
    const d: Date = new Date(ts);
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: number = d.getHours();
    const minute: number = d.getMinutes();
    const monthStr: string = month < 10 ? `0${month}` : `${month}`;
    const dayStr: string = day < 10 ? `0${day}` : `${day}`;
    const hourStr: string = hour < 10 ? `0${hour}` : `${hour}`;
    const minuteStr: string = minute < 10 ? `0${minute}` : `${minute}`;
    return `${d.getFullYear()}-${monthStr}-${dayStr} ${hourStr}:${minuteStr}`;
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏：返回 + 标题 + 删除（仅编辑模式）
        Row() {
          Text('‹')
            .fontSize(30)
            .fontColor('#6D4C41')
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.goBack();
            })
          Text(this.noteId === '' ? '新建笔记' : '编辑笔记')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2723')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
          if (this.noteId !== '') {
            Text('删除')
              .fontSize(14)
              .fontColor('#C0392B')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
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
                .fontColor('#8D6E63')
                .margin({ bottom: 8 })
            }
            TextArea({ placeholder: '记录你的想法…', text: this.content })
              .fontSize(15)
              .fontColor('#3E2723')
              .backgroundColor('#FAF6F0')
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
                Text(`创建于 ${this.formatDateTime(this.createdAt)}`)
                  .fontSize(12)
                  .fontColor('#BCAAA4')
                Text(`最后编辑 ${this.formatDateTime(this.updatedAt)}`)
                  .fontSize(12)
                  .fontColor('#BCAAA4')
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ top: 10 })
            }
            if (this.isLoading) {
              Text('正在加载…')
                .fontSize(12)
                .fontColor('#BCAAA4')
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
              .fontColor('#C0392B')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 6 })
          }
          Button('保存')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor('#6D4C41')
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
      .backgroundColor('#FAF6F0')

      // 删除确认弹层（与收藏页同款模式：遮罩空 onClick 消费点击，一律显式按钮关闭）
      if (this.confirmDeleting) {
        Column() {
          Column() {
            Text('确认删除笔记')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#3E2723')
            Text('删除后不可恢复')
              .fontSize(13)
              .fontColor('#8D6E63')
              .margin({ top: 10 })
            Row({ space: 12 }) {
              Button('再想想')
                .fontSize(14)
                .fontColor('#6D4C41')
                .backgroundColor('#EFEBE9')
                .layoutWeight(1)
                .onClick(() => {
                  this.confirmDeleting = false;
                })
              Button('删除')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .backgroundColor('#C0392B')
                .layoutWeight(1)
                .onClick(() => {
                  this.deleteCurrent();
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
