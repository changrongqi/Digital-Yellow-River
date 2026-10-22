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
 * 8. M6.3 删除墓碑：删除不再直接删 KV 键，而是以墓碑（deletedAt + deviceId）覆盖同一键，
 *    让删除参与 LWW——离线设备的旧记录上线后不会复活已删除数据；
 *    墓碑本地持久化，KV 就绪后重放；删除与并发编辑谁新谁生效，落败的一方登记冲突台账。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Favorite } from '../model/Favorite';
import { Note } from '../model/Note';
import { Tombstone } from '../model/Tombstone';
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
  /** 收藏删除墓碑存储键（M6.3） */
  private static readonly KEY_FAVORITE_TOMBSTONES = 'favorite_tombstones_json';
  /** 笔记删除墓碑存储键（M6.3） */
  private static readonly KEY_NOTE_TOMBSTONES = 'note_tombstones_json';
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
  /** 收藏删除墓碑（M6.3，id=itemId，参与 LWW） */
  private static favoriteTombstones: Tombstone[] = [];
  /** 笔记删除墓碑（M6.3，id=noteId，参与 LWW） */
  private static noteTombstones: Tombstone[] = [];
  /** 本机设备标识（M3 冲突判定兜底用） */
  private static device: string = '';
  /** 远端变更合并处理器是否已注册（init 可能重入，只注册一次） */
  private static mergeRegistered: boolean = false;
  /** KV 就绪重放墓碑是否已注册（init 可能重入，只注册一次） */
  private static readyRegistered: boolean = false;
  /** 主题 id 校验器（ThemeService 注册；未注册时保留远端原值，降级不误删） */
  private static themeIdValidator: ((ids: string[]) => string[]) | null = null;
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
    // M3.2：先注册远端变更合并处理器，再激活同步骨架（只注册一次）。
    // M6.2：顺序不能反——KV 就绪后可能立刻初次 PULL，监听未注册会丢远端变更。
    if (!FavoriteService.mergeRegistered) {
      FavoriteService.mergeRegistered = true;
      SyncService.onRemoteChange((changes: RemoteChanges) => {
        FavoriteService.mergeRemoteChanges(changes);
      });
    }
    // M6.3：KV 就绪后重放本地墓碑（离线期间的删除此时才写进 KV）。
    if (!FavoriteService.readyRegistered) {
      FavoriteService.readyRegistered = true;
      SyncService.onReady(() => {
        FavoriteService.replayTombstones();
      });
    }
    // M3.1：激活分布式同步骨架（幂等；降级不影响下方本地逻辑）。
    SyncService.init(context);
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
    FavoriteService.favoriteTombstones =
      FavoriteService.parseTombstones(FavoriteService.readStored(FavoriteService.KEY_FAVORITE_TOMBSTONES));
    FavoriteService.noteTombstones =
      FavoriteService.parseTombstones(FavoriteService.readStored(FavoriteService.KEY_NOTE_TOMBSTONES));
    FavoriteService.ensureDeviceId();
    // KV 可能在本次 init 之前已就绪（其它页面先初始化过同步），补一次重放。
    FavoriteService.replayTombstonesIfAvailable();
    hilog.info(DOMAIN, TAG, 'init ok: %{public}d favorites, %{public}d notes, %{public}d tombstones',
      FavoriteService.favoritesCache.length, FavoriteService.notesCache.length,
      FavoriteService.favoriteTombstones.length + FavoriteService.noteTombstones.length);
  }

  // ==================== 主题引用校验（M6.3） ====================

  /**
   * 注册主题 id 校验器（ThemeService.init 调用）。
   * 采纳远端收藏前过滤掉已删除主题的引用；未注册时保持原值（降级不误删）。
   * 用回调而不是直接 import ThemeService，避免 FavoriteService ↔ ThemeService 循环依赖。
   */
  static setThemeIdValidator(validator: (ids: string[]) => string[]): void {
    FavoriteService.themeIdValidator = validator;
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

  /** 归入某文化主题的收藏（C1.1，拷贝），按收藏时间倒序 */
  static getFavoritesByTheme(themeId: string): Favorite[] {
    const result: Favorite[] = [];
    for (let i = 0; i < FavoriteService.favoritesCache.length; i++) {
      const fav: Favorite = FavoriteService.favoritesCache[i];
      if (fav.themeIds.indexOf(themeId) >= 0) {
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
    // M6.3：重新收藏已删除条目时，保证新记录版本严格新于墓碑，
    // 否则对端仍会按 LWW 维持删除（设备墙钟回拨/备份恢复场景）。
    const tomb: Tombstone | null = FavoriteService.findFavoriteTombstone(itemId);
    const fav: Favorite = {
      id: util.generateRandomUUID(false),
      itemId: itemId,
      tags: FavoriteService.normalizeTags(tags),
      themeIds: [],
      createdAt: now,
      updatedAt: tomb !== null ? Math.max(now, tomb.deletedAt + 1) : now,
      deviceId: FavoriteService.ensureDeviceId()
    };
    FavoriteService.favoritesCache.push(fav);
    FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    if (tomb !== null && FavoriteService.dropFavoriteTombstone(itemId)) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITE_TOMBSTONES, FavoriteService.favoriteTombstones);
    }
    SyncService.syncFavorite(fav); // M3.2 双写：上抛分布式 KV（降级时空操作）
    FavoriteService.notifyDataChanged();
    return true;
  }

  /**
   * 取消收藏（只删收藏记录本身，不级联删除笔记：笔记是独立用户数据，
   * 详情页笔记区按 itemId 展示，与是否收藏无关，避免误销毁用户内容）。
   * M6.3：删除写墓碑并覆盖 KV 记录，供对端按 LWW 收敛。
   */
  static removeFavorite(itemId: string): boolean {
    const before: number = FavoriteService.favoritesCache.length;
    FavoriteService.favoritesCache = FavoriteService.filterOutFavorite(FavoriteService.favoritesCache, itemId);
    const removed: boolean = FavoriteService.favoritesCache.length < before;
    if (removed) {
      const tomb: Tombstone = {
        id: itemId,
        deletedAt: Date.now(),
        deviceId: FavoriteService.ensureDeviceId()
      };
      FavoriteService.upsertFavoriteTombstone(tomb);
      FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
      FavoriteService.persist(FavoriteService.KEY_FAVORITE_TOMBSTONES, FavoriteService.favoriteTombstones);
      SyncService.syncFavoriteTombstone(tomb); // M6.3 双写：墓碑覆盖 KV 记录
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

  /**
   * 更新收藏的文化主题集合（C1.1，知识库归类入口；全量替换，自动去重去空）。
   * 归类走本服务（收藏唯一权威不变，ThemeService 只维护主题本身），
   * 写入后经 syncFavorite 双写让 themeIds 随收藏走 LWW 同步（C1.3）。
   */
  static updateFavoriteThemes(itemId: string, themeIds: string[]): boolean {
    const fav: Favorite | null = FavoriteService.findFavorite(itemId);
    if (fav === null) {
      return false;
    }
    fav.themeIds = FavoriteService.normalizeTags(themeIds);
    fav.updatedAt = Date.now();
    FavoriteService.persist(FavoriteService.KEY_FAVORITES, FavoriteService.favoritesCache);
    SyncService.syncFavorite(fav); // M3.2 双写：themeIds 随收藏同步
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

  /** 删除笔记（M6.3：写墓碑并覆盖 KV 记录，避免离线设备旧笔记复活） */
  static deleteNote(noteId: string): boolean {
    const before: number = FavoriteService.notesCache.length;
    FavoriteService.notesCache = FavoriteService.filterOutNote(FavoriteService.notesCache, noteId);
    const removed: boolean = FavoriteService.notesCache.length < before;
    if (removed) {
      const tomb: Tombstone = {
        id: noteId,
        deletedAt: Date.now(),
        deviceId: FavoriteService.ensureDeviceId()
      };
      FavoriteService.upsertNoteTombstone(tomb);
      FavoriteService.persist(FavoriteService.KEY_NOTES, FavoriteService.notesCache);
      FavoriteService.persist(FavoriteService.KEY_NOTE_TOMBSTONES, FavoriteService.noteTombstones);
      SyncService.syncNoteTombstone(tomb); // M6.3 双写：墓碑覆盖 KV 记录
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
   * 远端变更 LWW 合并（M3.2 收藏/笔记 + M6.3 墓碑；本服务是数据唯一权威）。
   *
   * 合并规则（与官方单版本 KV「同键多端修改以最新为准」语义对齐，应用层显式化）：
   * - 实体 vs 实体：远端新增→采纳；双端版本不同→LWW（updatedAt 新者胜，相等 deviceId 小者胜）；
   *   本机胜→保留本机并回写 KV（autoSync 推送让对端收敛，本机 REMOTE 订阅不会收到
   *   自己 put 的回声，无回环）+ 记 conflictLog；
   * - 实体 vs 墓碑（M6.3）：同一 LWW 原语比较（实体 updatedAt vs 墓碑 deletedAt）。
   *   墓碑胜→维持删除并回写墓碑，离线旧记录不会复活；
   *   实体胜→采纳实体并丢弃墓碑（编辑确实晚于删除，编辑不静默丢失）；
   * - 墓碑 vs 墓碑：保留较新的墓碑；
   * - 本机无记录但收到墓碑：仅记墓碑，防止其它设备旧记录日后复活；
   * - 采纳远端收藏时校验 themeIds（ThemeService 注册校验器），剔除已删除主题的引用；
   * - 旧版本硬删除通知（deleteEntries，无时间戳）按「删除生效」兼容处理。
   * 合并结果落 Preferences 并通知页面刷新。
   */
  private static mergeRemoteChanges(changes: RemoteChanges): void {
    let favChanged: boolean = false;
    let favTombChanged: boolean = false;

    for (let i = 0; i < changes.upsertFavorites.length; i++) {
      const remote: Favorite = changes.upsertFavorites[i];
      remote.themeIds = FavoriteService.sanitizeThemeIds(remote.themeIds);
      const localTomb: Tombstone | null = FavoriteService.findFavoriteTombstone(remote.itemId);
      const local: Favorite | null = FavoriteService.findFavorite(remote.itemId);
      if (localTomb !== null) {
        if (SyncService.lwwRemoteWins(localTomb.deletedAt, localTomb.deviceId, remote.updatedAt, remote.deviceId)) {
          // 远端记录确实新于本地删除：采纳（编辑晚于删除，不算静默丢失）。
          FavoriteService.dropFavoriteTombstone(remote.itemId);
          if (local === null) {
            FavoriteService.favoritesCache.push(remote);
          } else {
            FavoriteService.replaceFavoriteByItemId(remote.itemId, remote);
          }
          SyncService.recordConflict(remote.itemId, '收藏删除后远端有更新版本，采纳远端记录');
          favChanged = true;
          favTombChanged = true;
        } else {
          // 墓碑更新：维持删除，并回写墓碑让持有旧记录的对端收敛。
          SyncService.syncFavoriteTombstone(localTomb);
          SyncService.recordConflict(remote.itemId, '远端收藏版本早于本地删除，维持删除');
        }
      } else if (local === null) {
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
    for (let i = 0; i < changes.favoriteTombstones.length; i++) {
      const remoteTomb: Tombstone = changes.favoriteTombstones[i];
      const localTomb: Tombstone | null = FavoriteService.findFavoriteTombstone(remoteTomb.id);
      if (localTomb !== null) {
        if (SyncService.lwwRemoteWins(localTomb.deletedAt, localTomb.deviceId,
          remoteTomb.deletedAt, remoteTomb.deviceId)) {
          FavoriteService.upsertFavoriteTombstone(remoteTomb);
          favTombChanged = true;
        }
        continue;
      }
      const local: Favorite | null = FavoriteService.findFavorite(remoteTomb.id);
      if (local === null) {
        // 本机没有该收藏：仍记墓碑，防止其它离线设备的旧记录之后再复活。
        FavoriteService.upsertFavoriteTombstone(remoteTomb);
        favTombChanged = true;
        continue;
      }
      if (SyncService.lwwRemoteWins(local.updatedAt, local.deviceId,
        remoteTomb.deletedAt, remoteTomb.deviceId)) {
        FavoriteService.favoritesCache =
          FavoriteService.filterOutFavorite(FavoriteService.favoritesCache, remoteTomb.id);
        FavoriteService.upsertFavoriteTombstone(remoteTomb);
        SyncService.recordConflict(remoteTomb.id, '远端删除比本地收藏编辑新，删除生效');
        favChanged = true;
        favTombChanged = true;
      } else {
        SyncService.syncFavorite(local);
        SyncService.recordConflict(remoteTomb.id, '本地收藏编辑比远端删除新，保留本地记录');
      }
    }
    // 旧版本硬删除（deleteEntries，无时间戳）：兼容保留「删除生效」语义。
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
    if (favTombChanged) {
      FavoriteService.persist(FavoriteService.KEY_FAVORITE_TOMBSTONES, FavoriteService.favoriteTombstones);
    }

    let noteChanged: boolean = false;
    let noteTombChanged: boolean = false;
    for (let i = 0; i < changes.upsertNotes.length; i++) {
      const remote: Note = changes.upsertNotes[i];
      const localTomb: Tombstone | null = FavoriteService.findNoteTombstone(remote.id);
      const local: Note | null = FavoriteService.findNote(remote.id);
      if (localTomb !== null) {
        if (SyncService.lwwRemoteWins(localTomb.deletedAt, localTomb.deviceId, remote.updatedAt, remote.deviceId)) {
          FavoriteService.dropNoteTombstone(remote.id);
          if (local === null) {
            FavoriteService.notesCache.push(remote);
          } else {
            FavoriteService.replaceNoteById(remote.id, remote);
          }
          SyncService.recordConflict(remote.id, '笔记删除后远端有更新版本，采纳远端记录');
          noteChanged = true;
          noteTombChanged = true;
        } else {
          SyncService.syncNoteTombstone(localTomb);
          SyncService.recordConflict(remote.id, '远端笔记版本早于本地删除，维持删除');
        }
      } else if (local === null) {
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
    for (let i = 0; i < changes.noteTombstones.length; i++) {
      const remoteTomb: Tombstone = changes.noteTombstones[i];
      const localTomb: Tombstone | null = FavoriteService.findNoteTombstone(remoteTomb.id);
      if (localTomb !== null) {
        if (SyncService.lwwRemoteWins(localTomb.deletedAt, localTomb.deviceId,
          remoteTomb.deletedAt, remoteTomb.deviceId)) {
          FavoriteService.upsertNoteTombstone(remoteTomb);
          noteTombChanged = true;
        }
        continue;
      }
      const local: Note | null = FavoriteService.findNote(remoteTomb.id);
      if (local === null) {
        FavoriteService.upsertNoteTombstone(remoteTomb);
        noteTombChanged = true;
        continue;
      }
      if (SyncService.lwwRemoteWins(local.updatedAt, local.deviceId,
        remoteTomb.deletedAt, remoteTomb.deviceId)) {
        FavoriteService.notesCache = FavoriteService.filterOutNote(FavoriteService.notesCache, remoteTomb.id);
        FavoriteService.upsertNoteTombstone(remoteTomb);
        SyncService.recordConflict(remoteTomb.id, '远端删除比本地笔记编辑新，删除生效');
        noteChanged = true;
        noteTombChanged = true;
      } else {
        SyncService.syncNote(local);
        SyncService.recordConflict(remoteTomb.id, '本地笔记编辑比远端删除新，保留本地记录');
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
    if (noteTombChanged) {
      FavoriteService.persist(FavoriteService.KEY_NOTE_TOMBSTONES, FavoriteService.noteTombstones);
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

  // ==================== 删除墓碑（M6.3） ====================

  /** 过滤掉已删除主题的引用（校验器未注册时原样返回；只按墓碑判定，不误删尚未同步到的主题） */
  private static sanitizeThemeIds(ids: string[]): string[] {
    const validator = FavoriteService.themeIdValidator;
    if (validator === null) {
      return ids;
    }
    return validator(ids);
  }

  private static findFavoriteTombstone(itemId: string): Tombstone | null {
    for (let i = 0; i < FavoriteService.favoriteTombstones.length; i++) {
      if (FavoriteService.favoriteTombstones[i].id === itemId) {
        return FavoriteService.favoriteTombstones[i];
      }
    }
    return null;
  }

  private static findNoteTombstone(noteId: string): Tombstone | null {
    for (let i = 0; i < FavoriteService.noteTombstones.length; i++) {
      if (FavoriteService.noteTombstones[i].id === noteId) {
        return FavoriteService.noteTombstones[i];
      }
    }
    return null;
  }

  /** 写入/更新墓碑（同 id 直接覆盖，调用方负责持久化） */
  private static upsertFavoriteTombstone(tomb: Tombstone): void {
    for (let i = 0; i < FavoriteService.favoriteTombstones.length; i++) {
      if (FavoriteService.favoriteTombstones[i].id === tomb.id) {
        FavoriteService.favoriteTombstones[i] = tomb;
        return;
      }
    }
    FavoriteService.favoriteTombstones.push(tomb);
  }

  private static upsertNoteTombstone(tomb: Tombstone): void {
    for (let i = 0; i < FavoriteService.noteTombstones.length; i++) {
      if (FavoriteService.noteTombstones[i].id === tomb.id) {
        FavoriteService.noteTombstones[i] = tomb;
        return;
      }
    }
    FavoriteService.noteTombstones.push(tomb);
  }

  /** 移除墓碑（重新收藏/远端记录胜出时调用），返回是否确有移除 */
  private static dropFavoriteTombstone(itemId: string): boolean {
    const next: Tombstone[] = [];
    for (let i = 0; i < FavoriteService.favoriteTombstones.length; i++) {
      if (FavoriteService.favoriteTombstones[i].id !== itemId) {
        next.push(FavoriteService.favoriteTombstones[i]);
      }
    }
    const dropped: boolean = next.length < FavoriteService.favoriteTombstones.length;
    FavoriteService.favoriteTombstones = next;
    return dropped;
  }

  private static dropNoteTombstone(noteId: string): boolean {
    const next: Tombstone[] = [];
    for (let i = 0; i < FavoriteService.noteTombstones.length; i++) {
      if (FavoriteService.noteTombstones[i].id !== noteId) {
        next.push(FavoriteService.noteTombstones[i]);
      }
    }
    const dropped: boolean = next.length < FavoriteService.noteTombstones.length;
    FavoriteService.noteTombstones = next;
    return dropped;
  }

  /** 重放本地墓碑到 KV（KV 尚未就绪时 putRecord 静默跳过，由 onReady 再次触发） */
  private static replayTombstones(): void {
    for (let i = 0; i < FavoriteService.favoriteTombstones.length; i++) {
      SyncService.syncFavoriteTombstone(FavoriteService.favoriteTombstones[i]);
    }
    for (let i = 0; i < FavoriteService.noteTombstones.length; i++) {
      SyncService.syncNoteTombstone(FavoriteService.noteTombstones[i]);
    }
  }

  private static replayTombstonesIfAvailable(): void {
    if (SyncService.isAvailable()) {
      FavoriteService.replayTombstones();
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
        themeIds: FavoriteService.getStrArray(rec, 'themeIds'),
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

  private static parseTombstones(text: string): Tombstone[] {
    const result: Tombstone[] = [];
    if (text === '') {
      return result;
    }
    let parsed: object[] = [];
    try {
      parsed = JSON.parse(text) as object[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'tombstones parse failed: %{public}s', JSON.stringify(err));
      return result;
    }
    for (let i = 0; i < parsed.length; i++) {
      const tomb: Tombstone | null = FavoriteService.parseTombstone(parsed[i], i);
      if (tomb !== null) {
        result.push(tomb);
      }
    }
    return result;
  }

  private static parseTombstone(obj: object, index: number): Tombstone | null {
    try {
      const rec = obj as Record<string, Object>;
      const id: string = FavoriteService.getStr(rec, 'id');
      const deletedAt: number = FavoriteService.getNum(rec, 'deletedAt');
      if (id === '' || deletedAt <= 0) {
        hilog.warn(DOMAIN, TAG, 'skip invalid tombstone #%{public}d', index);
        return null;
      }
      const tomb: Tombstone = {
        id: id,
        deletedAt: deletedAt,
        deviceId: FavoriteService.getStr(rec, 'deviceId')
      };
      return tomb;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse tombstone #%{public}d error: %{public}s', index, JSON.stringify(err));
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
