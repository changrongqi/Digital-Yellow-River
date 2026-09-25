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
 * 7. M3.2 双写与远端合并：所有变更 = 内存缓存 + Preferences 本地 + 分布式 KV 上抛
 *    （SyncService，降级时仅本地）；远端变更经 LWW 合并进缓存（updatedAt 谁新谁赢，
 *    相等 deviceId 兜底——与官方单版本 KV「同键多端修改以最新为准」语义一致）；
 *    本地变更与远端合并后均经 onDataChanged 通知页面刷新 UI。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Favorite } from '../model/Favorite';
import { Note } from '../model/Note';
import { SyncService, RemoteChanges } from './SyncService';

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
  /** 远端变更合并处理器是否已注册（init 可能重入，只注册一次） */
  private static mergeRegistered: boolean = false;
  /** 数据变更监听者（本地 CRUD 与远端合并后通知，页面订阅刷新 UI） */
  private static dataListeners: Array<() => void> = [];

  /**
   * 初始化：加载 Preferences 并把历史数据读入内存缓存。
   * 页面 aboutToAppear 调用即可，重复调用无副作用。
   */
  static init(context: common.Context): void {
    if (FavoriteService.pref !== null) {
      return;
    }
    // M3.1：激活分布式同步骨架（幂等；降级不影响下方本地逻辑）。
    SyncService.init(context);
    // M3.2：注册远端变更合并处理器（init 可能因 Preferences 失败重入，只注册一次）
    if (!FavoriteService.mergeRegistered) {
      FavoriteService.mergeRegistered = true;
      SyncService.onRemoteChange((changes: RemoteChanges) => {
        FavoriteService.mergeRemoteChanges(changes);
      });
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
    SyncService.syncFavorite(fav); // M3.2 双写：上抛分布式 KV（降级时空操作）
    FavoriteService.notifyDataChanged();
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
      SyncService.removeFavoriteSync(itemId); // M3.2 双写：移除分布式 KV 记录
      FavoriteService.notifyDataChanged();
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
    SyncService.syncFavorite(fav); // M3.2 双写
    FavoriteService.notifyDataChanged();
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
    const affected: Favorite[] = [];
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      const fav: Favorite = FavoriteService.favoritesCache[i];
      const idx: number = fav.tags.indexOf(tag);
      if (idx >= 0) {
        const next: string[] = fav.tags.slice();
        next.splice(idx, 1);
        fav.tags = next;
        fav.updatedAt = Date.now();
        affected.push(fav);
      }
    }
    if (affected.length > 0) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
      for (let i = 0; i < affected.length; i++) {
        SyncService.syncFavorite(affected[i]); // M3.2 双写：逐条上抛被更新的收藏
      }
      FavoriteService.notifyDataChanged();
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
    SyncService.syncNote(note); // M3.2 双写：上抛分布式 KV（降级时空操作）
    FavoriteService.notifyDataChanged();
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
    SyncService.syncNote(note); // M3.2 双写
    FavoriteService.notifyDataChanged();
    return true;
  }

  /** 删除笔记 */
  static deleteNote(noteId: string): boolean {
    const before: number = FavoriteService.notesCache.length;
    FavoriteService.notesCache = FavoriteService.filterOutNote(FavoriteService.notesCache, noteId);
    const removed: boolean = FavoriteService.notesCache.length < before;
    if (removed) {
      FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
      SyncService.removeNoteSync(noteId); // M3.2 双写：移除分布式 KV 记录
      FavoriteService.notifyDataChanged();
    }
    return removed;
  }

  // ==================== 页面刷新通知（M3.2） ====================

  /** 订阅用户数据变化（本地 CRUD 与远端合并后触发），页面在 aboutToAppear 注册 */
  static onDataChanged(listener: () => void): void {
    FavoriteService.dataListeners.push(listener);
  }

  /** 取消订阅（页面 aboutToDisappear 调用，传入注册时的同一函数引用） */
  static offDataChanged(listener: () => void): void {
    const idx: number = FavoriteService.dataListeners.indexOf(listener);
    if (idx >= 0) {
      FavoriteService.dataListeners.splice(idx, 1);
    }
  }

  private static notifyDataChanged(): void {
    for (let i = 0; i < FavoriteService.dataListeners.length; i++) {
      FavoriteService.dataListeners[i]();
    }
  }

  /**
   * 远端变更 LWW 合并（M3.2，SyncService 回调触发；本服务是数据唯一权威）。
   *
   * 合并规则（与官方单版本 KV「同键多端修改以最新为准」语义对齐，应用层显式化）：
   * - 远端记录本地不存在 → 直接采纳（远端新增）；
   * - 双端版本不同 → LWW（updatedAt 谁新谁赢，相等 deviceId 字典序小者胜）：
   *   远端胜 → 本地替换为远端版本 + 记 conflictLog；
   *   本机胜 → 保留本机并回写 KV（autoSync 推送让对端收敛，本机 REMOTE 订阅不会
   *   收到自己 put 的回声，无回环）+ 记 conflictLog；
   * - 版本完全一致（updatedAt 与 deviceId 均同）→ 无操作。
   * - 远端删除 → 本地移除（删除通知不带时间戳，无墓碑可比，按「删除生效」简化处理；
   *   代价是删除与本地并发修改时本地修改丢失——小体量用户数据下可接受，不记台账）。
   * 合并结果落 Preferences 并通知页面刷新。
   */
  private static mergeRemoteChanges(changes: RemoteChanges): void {
    let favChanged: boolean = false;
    for (let i = 0; i < changes.upsertFavorites.length; i++) {
      const remote: Favorite = changes.upsertFavorites[i];
      const local: Favorite | null = FavoriteService.findFavorite(remote.itemId);
      if (local === null) {
        FavoriteService.favoritesCache.push(remote);
        favChanged = true;
      } else if (local.updatedAt !== remote.updatedAt || local.deviceId !== remote.deviceId) {
        if (SyncService.lwwRemoteWins(local.updatedAt, local.deviceId, remote.updatedAt, remote.deviceId)) {
          FavoriteService.replaceFavoriteByItemId(remote.itemId, remote);
          SyncService.recordConflict(remote.itemId, '收藏双端并发修改，保留较新的远端版本');
          favChanged = true;
        } else {
          SyncService.syncFavorite(local);
          SyncService.recordConflict(remote.itemId, '收藏双端并发修改，保留较新的本机版本');
        }
      }
    }
    for (let i = 0; i < changes.deletedFavoriteItemIds.length; i++) {
      const itemId: string = changes.deletedFavoriteItemIds[i];
      if (FavoriteService.findFavorite(itemId) !== null) {
        FavoriteService.favoritesCache = FavoriteService.filterOutFavorite(FavoriteService.favoritesCache, itemId);
        favChanged = true;
      }
    }
    if (favChanged) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    }

    let noteChanged: boolean = false;
    for (let i = 0; i < changes.upsertNotes.length; i++) {
      const remote: Note = changes.upsertNotes[i];
      const local: Note | null = FavoriteService.findNote(remote.id);
      if (local === null) {
        FavoriteService.notesCache.push(remote);
        noteChanged = true;
      } else if (local.updatedAt !== remote.updatedAt || local.deviceId !== remote.deviceId) {
        if (SyncService.lwwRemoteWins(local.updatedAt, local.deviceId, remote.updatedAt, remote.deviceId)) {
          FavoriteService.replaceNoteById(remote.id, remote);
          SyncService.recordConflict(remote.id, '笔记双端并发修改，保留较新的远端版本');
          noteChanged = true;
        } else {
          SyncService.syncNote(local);
          SyncService.recordConflict(remote.id, '笔记双端并发修改，保留较新的本机版本');
        }
      }
    }
    for (let i = 0; i < changes.deletedNoteIds.length; i++) {
      const noteId: string = changes.deletedNoteIds[i];
      if (FavoriteService.findNote(noteId) !== null) {
        FavoriteService.notesCache = FavoriteService.filterOutNote(FavoriteService.notesCache, noteId);
        noteChanged = true;
      }
    }
    if (noteChanged) {
      FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
    }

    if (favChanged || noteChanged) {
      FavoriteService.notifyDataChanged();
    }
  }

  private static replaceFavoriteByItemId(itemId: string, next: Favorite): void {
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      if (FavoriteService.favoritesCache[i].itemId === itemId) {
        FavoriteService.favoritesCache[i] = next;
        return;
      }
    }
  }

  private static replaceNoteById(noteId: string, next: Note): void {
    for (let i = 0; i < FavoriteService.notesCache.length; i++) {
      if (FavoriteService.notesCache[i].id === noteId) {
        FavoriteService.notesCache[i] = next;
        return;
      }
    }
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
