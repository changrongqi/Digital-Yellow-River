/**
 * 业务服务层（M2.1）：收藏与笔记 CRUD + 标签管理 + Preferences 本地持久化。
 *
 * 设计说明：
 * 1. 存储选型 Preferences（计划书 M2.1「Preferences/RDB」二选一）：
 *    收藏/笔记是小体量用户数据（预计几十条），整表 JSON 存取简单可靠，重启不丢。
 * 2. 全同步 API（getPreferencesSync/putSync/flushSync，API 12 SDK 实测存在）：
 *    进程内缓存 + 同步落盘，页面层调用免 async/await；
 *    所有会抛异常的 SDK 调用均包 try/catch（对齐告警基线，不新增 may throw 告警）。
 * 3. 踩坑 3：所有写入自动维护 deviceId + updatedAt（M3 LWW 冲突判定直接复用）。
 *    deviceId 首次生成 UUID 后持久化，单机阶段稳定不变；M3 可由 SyncService 换成分布式设备标识。
 * 4. 踩坑 1/2/4：从 Preferences 读回的 JSON 必须逐字段显式转换 + 合法性校验，
 *    非法条目跳过并记日志；全程不用 any、不用解构赋值。
 * 5. 降级策略：Preferences 初始化失败（极端场景）时不崩溃——内存缓存照常工作，
 *    仅无法持久化（每次重启回到空数据），并记错误日志。
 * 6. 分层约定（计划书 §3）：pages 只做 UI，收藏/笔记读写一律走本服务；
 *    返回的数组是拷贝、对象按只读约定使用，修改必须走本服务的变更方法。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Favorite } from '../model/Favorite';
import { Note } from '../model/Note';

const DOMAIN = 0x0000;
const TAG = 'FavoriteService';

export class FavoriteService {
  /** Preferences 实例名 */
  private static readonly STORE_NAME = 'yellow_river_user_data';
  /** 收藏整表存储键（JSON 数组文本） */
  private static readonly KEY_FAVORITES = 'favorites_json';
  /** 笔记整表存储键（JSON 数组文本） */
  private static readonly KEY_NOTES = 'notes_json';
  /** 本机设备标识存储键 */
  private static readonly KEY_DEVICE_ID = 'device_id';

  /** 内置标签（与 model/Favorite.ets 约定一致） */
  static readonly BUILT_IN_TAGS: string[] = ['待实地探访', '已去过', '研究资料'];

  /** Preferences 实例（null = 未初始化或初始化失败，降级为纯内存） */
  private static pref: preferences.Preferences | null = null;
  /** 收藏内存缓存（唯一数据源，变更后同步落盘） */
  private static favoritesCache: Favorite[] = [];
  /** 笔记内存缓存（唯一数据源，变更后同步落盘） */
  private static notesCache: Note[] = [];
  /** 本机设备标识（M3 冲突判定兜底用） */
  private static device: string = '';

  /**
   * 初始化：加载 Preferences 并把历史数据读入内存缓存。
   * 页面 aboutToAppear 调用即可，重复调用无副作用。
   */
  static init(context: common.Context): void {
    if (FavoriteService.pref !== null) {
      return;
    }
    try {
      const options: preferences.Options = { name: FavoriteService.STORE_NAME };
      FavoriteService.pref = preferences.getPreferencesSync(context, options);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init preferences failed, degrade to memory only: %{public}s', JSON.stringify(err));
      FavoriteService.pref = null;
      return;
    }
    FavoriteService.favoritesCache =
      FavoriteService.parseFavorites(FavoriteService.readStored(FavoriteService.KEY_FAVORITES));
    FavoriteService.notesCache =
      FavoriteService.parseNotes(FavoriteService.readStored(FavoriteService.KEY_NOTES));
    FavoriteService.ensureDeviceId();
    hilog.info(DOMAIN, TAG, 'init ok: %{public}d favorites, %{public}d notes',
      FavoriteService.favoritesCache.length, FavoriteService.notesCache.length);
  }

  // ==================== 收藏查询 ====================

  /** 是否已收藏（未初始化/无数据返回 false） */
  static isFavorite(itemId: string): boolean {
    return FavoriteService.findFavorite(itemId) !== null;
  }

  /** 按 itemId 取收藏记录（无则 null），返回对象按只读约定使用 */
  static getFavorite(itemId: string): Favorite | null {
    return FavoriteService.findFavorite(itemId);
  }

  /** 全部收藏（拷贝），按收藏时间倒序（最近在前） */
  static getAllFavorites(): Favorite[] {
    const copy: Favorite[] = FavoriteService.favoritesCache.slice();
    copy.sort((a: Favorite, b: Favorite): number => b.createdAt - a.createdAt);
    return copy;
  }

  /** 按标签筛选收藏（拷贝），按收藏时间倒序 */
  static getFavoritesByTag(tag: string): Favorite[] {
    const result: Favorite[] = [];
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      const fav: Favorite = FavoriteService.favoritesCache[i];
      if (fav.tags.indexOf(tag) >= 0) {
        result.push(fav);
      }
    }
    result.sort((a: Favorite, b: Favorite): number => b.createdAt - a.createdAt);
    return result;
  }

  // ==================== 收藏变更 ====================

  /**
   * 切换收藏状态（详情页收藏按钮入口，M2.4 使用）。
   * @return 切换后是否处于已收藏状态
   */
  static toggleFavorite(itemId: string): boolean {
    if (FavoriteService.isFavorite(itemId)) {
      FavoriteService.removeFavorite(itemId);
      return false;
    }
    return FavoriteService.addFavorite(itemId, []);
  }

  /**
   * 新增收藏。
   * @return 是否成功（itemId 重复返回 false）
   */
  static addFavorite(itemId: string, tags: string[]): boolean {
    if (itemId === '' || FavoriteService.findFavorite(itemId) !== null) {
      return false;
    }
    const now: number = Date.now();
    const fav: Favorite = {
      id: util.generateRandomUUID(false),
      itemId: itemId,
      tags: FavoriteService.normalizeTags(tags),
      createdAt: now,
      updatedAt: now,
      deviceId: FavoriteService.ensureDeviceId()
    };
    FavoriteService.favoritesCache.push(fav);
    FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    return true;
  }

  /**
   * 取消收藏（只删收藏记录本身，不级联删除笔记：笔记是独立用户数据，
   * 详情页笔记区按 itemId 展示，与是否收藏无关，避免误销毁用户内容）。
   */
  static removeFavorite(itemId: string): boolean {
    const before: number = FavoriteService.favoritesCache.length;
    FavoriteService.favoritesCache = FavoriteService.filterOutFavorite(FavoriteService.favoritesCache, itemId);
    const removed: boolean = FavoriteService.favoritesCache.length < before;
    if (removed) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    }
    return removed;
  }

  /** 更新收藏的标签集合（全量替换，自动去重去空） */
  static updateFavoriteTags(itemId: string, tags: string[]): boolean {
    const fav: Favorite | null = FavoriteService.findFavorite(itemId);
    if (fav === null) {
      return false;
    }
    fav.tags = FavoriteService.normalizeTags(tags);
    fav.updatedAt = Date.now();
    FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    return true;
  }

  // ==================== 标签管理 ====================

  /** 全部标签 = 内置标签 + 使用中的自定义标签（按首次出现顺序，去重） */
  static getAllTags(): string[] {
    const result: string[] = FavoriteService.BUILT_IN_TAGS.slice();
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      const tags: string[] = FavoriteService.favoritesCache[i].tags;
      for (let j = 0; j < tags.length; j++) {
        const tag: string = tags[j];
        if (result.indexOf(tag) < 0) {
          result.push(tag);
        }
      }
    }
    return result;
  }

  /**
   * 删除标签：从所有收藏记录中移除该标签（含内置标签——只清使用处，
   * 内置标签仍作为 getAllTags 的常量候选保留，可再次选用）。
   */
  static removeTag(tag: string): void {
    let changed: boolean = false;
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      const fav: Favorite = FavoriteService.favoritesCache[i];
      const idx: number = fav.tags.indexOf(tag);
      if (idx >= 0) {
        const next: string[] = fav.tags.slice();
        next.splice(idx, 1);
        fav.tags = next;
        fav.updatedAt = Date.now();
        changed = true;
      }
    }
    if (changed) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    }
  }

  // ==================== 笔记查询 ====================

  /** 某条目下的笔记（拷贝），按更新时间倒序（最近在前） */
  static getNotesByItem(itemId: string): Note[] {
    const result: Note[] = [];
    for (let i = 0; i < FavoriteService.notesCache.length; i++) {
      if (FavoriteService.notesCache[i].itemId === itemId) {
        result.push(FavoriteService.notesCache[i]);
      }
    }
    result.sort((a: Note, b: Note): number => b.updatedAt - a.updatedAt);
    return result;
  }

  /** 全部笔记（拷贝），按更新时间倒序 */
  static getAllNotes(): Note[] {
    const copy: Note[] = FavoriteService.notesCache.slice();
    copy.sort((a: Note, b: Note): number => b.updatedAt - a.updatedAt);
    return copy;
  }

  // ==================== 笔记变更 ====================

  /**
   * 新增笔记（笔记编辑页入口，M2.3 使用）。
   * @return 是否成功（空正文返回 false；不要求条目已收藏，允许先记笔记后收藏）
   */
  static addNote(itemId: string, content: string): boolean {
    const trimmed: string = content.trim();
    if (itemId === '' || trimmed === '') {
      return false;
    }
    const now: number = Date.now();
    const note: Note = {
      id: util.generateRandomUUID(false),
      itemId: itemId,
      content: trimmed,
      createdAt: now,
      updatedAt: now,
      deviceId: FavoriteService.ensureDeviceId()
    };
    FavoriteService.notesCache.push(note);
    FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
    return true;
  }

  /** 修改笔记正文（更新 updatedAt，M3 LWW 依据） */
  static updateNote(noteId: string, content: string): boolean {
    const trimmed: string = content.trim();
    const note: Note | null = FavoriteService.findNote(noteId);
    if (note === null || trimmed === '') {
      return false;
    }
    note.content = trimmed;
    note.updatedAt = Date.now();
    FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
    return true;
  }

  /** 删除笔记 */
  static deleteNote(noteId: string): boolean {
    const before: number = FavoriteService.notesCache.length;
    FavoriteService.notesCache = FavoriteService.filterOutNote(FavoriteService.notesCache, noteId);
    const removed: boolean = FavoriteService.notesCache.length < before;
    if (removed) {
      FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
    }
    return removed;
  }

  // ==================== 内部实现 ====================

  private static findFavorite(itemId: string): Favorite | null {
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      if (FavoriteService.favoritesCache[i].itemId === itemId) {
        return FavoriteService.favoritesCache[i];
      }
    }
    return null;
  }

  private static findNote(noteId: string): Note | null {
    for (let i = 0; i < FavoriteService.notesCache.length; i++) {
      if (FavoriteService.notesCache[i].id === noteId) {
        return FavoriteService.notesCache[i];
      }
    }
    return null;
  }

  private static filterOutFavorite(list: Favorite[], itemId: string): Favorite[] {
    const result: Favorite[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].itemId !== itemId) {
        result.push(list[i]);
      }
    }
    return result;
  }

  private static filterOutNote(list: Note[], noteId: string): Note[] {
    const result: Note[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== noteId) {
        result.push(list[i]);
      }
    }
    return result;
  }

  /** 标签集合规整：去空串、去重（保持首次出现顺序） */
  private static normalizeTags(tags: string[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < tags.length; i++) {
      const tag: string = tags[i].trim();
      if (tag !== '' && result.indexOf(tag) < 0) {
        result.push(tag);
      }
    }
    return result;
  }

  /** 取本机设备标识：优先读已持久化值，否则生成 UUID 并落盘 */
  private static ensureDeviceId(): string {
    if (FavoriteService.device !== '') {
      return FavoriteService.device;
    }
    let stored: string = '';
    if (FavoriteService.pref !== null) {
      try {
        const value = FavoriteService.pref.getSync(FavoriteService.KEY_DEVICE_ID, '');
        stored = String(value);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'read device id failed: %{public}s', JSON.stringify(err));
      }
    }
    if (stored === '') {
      stored = util.generateRandomUUID(false);
      if (FavoriteService.pref !== null) {
        try {
          FavoriteService.pref.putSync(FavoriteService.KEY_DEVICE_ID, stored);
          FavoriteService.pref.flushSync();
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'persist device id failed: %{public}s', JSON.stringify(err));
        }
      }
    }
    FavoriteService.device = stored;
    return stored;
  }

  /** 整表序列化落盘（失败仅记日志，内存数据不受影响） */
  private static persist(key: string, data: object[]): void {
    const pref = FavoriteService.pref;
    if (pref === null) {
      return;
    }
    try {
      pref.putSync(key, JSON.stringify(data));
      pref.flushSync();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist %{public}s failed: %{public}s', key, JSON.stringify(err));
    }
  }

  /** 读取已存储的字符串值（未初始化/异常返回空串） */
  private static readStored(key: string): string {
    const pref = FavoriteService.pref;
    if (pref === null) {
      return '';
    }
    try {
      const value = pref.getSync(key, '');
      return String(value);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read %{public}s failed: %{public}s', key, JSON.stringify(err));
      return '';
    }
  }

  // ==================== 持久化数据解析（踩坑 1/2/4） ====================

  private static parseFavorites(text: string): Favorite[] {
    const result: Favorite[] = [];
    if (text === '') {
      return result;
    }
    let parsed: object[] = [];
    try {
      parsed = JSON.parse(text) as object[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'favorites parse failed: %{public}s', JSON.stringify(err));
      return result;
    }
    for (let i = 0; i < parsed.length; i++) {
      const fav: Favorite | null = FavoriteService.parseFavorite(parsed[i], i);
      if (fav !== null) {
        result.push(fav);
      }
    }
    return result;
  }

  private static parseFavorite(obj: object, index: number): Favorite | null {
    try {
      const rec = obj as Record<string, Object>;
      const id: string = FavoriteService.getStr(rec, 'id');
      const itemId: string = FavoriteService.getStr(rec, 'itemId');
      if (id === '' || itemId === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid favorite #%{public}d', index);
        return null;
      }
      const fav: Favorite = {
        id: id,
        itemId: itemId,
        tags: FavoriteService.getStrArray(rec, 'tags'),
        createdAt: FavoriteService.getNum(rec, 'createdAt'),
        updatedAt: FavoriteService.getNum(rec, 'updatedAt'),
        deviceId: FavoriteService.getStr(rec, 'deviceId')
      };
      return fav;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse favorite #%{public}d error: %{public}s', index, JSON.stringify(err));
      return null;
    }
  }

  private static parseNotes(text: string): Note[] {
    const result: Note[] = [];
    if (text === '') {
      return result;
    }
    let parsed: object[] = [];
    try {
      parsed = JSON.parse(text) as object[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'notes parse failed: %{public}s', JSON.stringify(err));
      return result;
    }
    for (let i = 0; i < parsed.length; i++) {
      const note: Note | null = FavoriteService.parseNote(parsed[i], i);
      if (note !== null) {
        result.push(note);
      }
    }
    return result;
  }

  private static parseNote(obj: object, index: number): Note | null {
    try {
      const rec = obj as Record<string, Object>;
      const id: string = FavoriteService.getStr(rec, 'id');
      const itemId: string = FavoriteService.getStr(rec, 'itemId');
      const content: string = FavoriteService.getStr(rec, 'content');
      if (id === '' || itemId === '' || content === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid note #%{public}d', index);
        return null;
      }
      const note: Note = {
        id: id,
        itemId: itemId,
        content: content,
        createdAt: FavoriteService.getNum(rec, 'createdAt'),
        updatedAt: FavoriteService.getNum(rec, 'updatedAt'),
        deviceId: FavoriteService.getStr(rec, 'deviceId')
      };
      return note;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse note #%{public}d error: %{public}s', index, JSON.stringify(err));
      return null;
    }
  }

  private static getStr(rec: Record<string, Object>, key: string): string {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return '';
    }
    return String(v);
  }

  private static getNum(rec: Record<string, Object>, key: string): number {
    const v: Object | undefined = rec[key];
    if (typeof v === 'number') {
      return v as number;
    }
    return 0;
  }

  private static getStrArray(rec: Record<string, Object>, key: string): string[] {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return [];
    }
    const arr = v as Object[];
    const result: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      result.push(String(arr[i]));
    }
    return result;
  }
}
