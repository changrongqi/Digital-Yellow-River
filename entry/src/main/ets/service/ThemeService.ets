/**
 * 业务服务层（C1.1）：文化主题（Theme）CRUD + 本地持久化 + 分布式双写。
 *
 * 设计说明（计划书 M5 C1，模式对齐 FavoriteService）：
 * 1. 主题是「文化脉络聚合」维度（如「彩陶文化」「青铜文明」「帝王陵寝」），
 *    与 M2 收藏标签是两个维度：标签是收藏卡片的管理分类，主题是知识库的知识节点；
 *    一个收藏可归入多个主题（Favorite.themeIds），多对多，归类写 FavoriteService。
 * 2. 主题数据唯一权威 = 本服务（内存缓存 + Preferences + 分布式 KV 双写 + 远端 LWW 合并）；
 *    收藏归类的写入走 FavoriteService.updateFavoriteThemes——收藏唯一权威不变，避免双权威。
 * 3. 独立 store 名 'yellow_river_themes'（不共享 FavoriteService 的 pref 实例，
 *    避免两个实例并发写同一 Preferences 文件导致一致性风险；各自文件各自实例）。
 * 4. 删除主题：仅清收藏上的关联引用（经 FavoriteService 逐条剥离 themeIds），不删除收藏本身；
 *    远端删除主题同理（先删主题，再剥离本端收藏引用）。
 * 5. LWW：updatedAt 新者胜、相等 deviceId 字典序小者胜（与 M3 收藏/笔记判定原语一致，
 *    复用 SyncService.lwwRemoteWins）。
 * 6. 踩坑 1/2/4：Preferences 读回 JSON 逐字段显式转换 + 合法性校验，非法条目跳过记日志；
 *    全程不用 any、不用解构赋值；可抛异常 SDK 调用包 try/catch。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Theme } from '../model/Theme';
import { Favorite } from '../model/Favorite';
import { FavoriteService } from './FavoriteService';
import { SyncService, RemoteChanges } from './SyncService';

const DOMAIN = 0x0000;
const TAG = 'ThemeService';

export class ThemeService {
  /** Preferences 实例名（独立 store，避免与收藏/笔记共享实例） */
  private static readonly STORE_NAME = 'yellow_river_themes';
  /** 主题整表存储键（JSON 数组文本） */
  private static readonly KEY_THEMES = 'themes_json';
  /** 本机设备标识存储键（与 FavoriteService 各自存一份，值一致生成） */
  private static readonly KEY_DEVICE_ID = 'device_id';

  /** Preferences 实例（null = 未初始化或初始化失败，降级为纯内存） */
  private static pref: preferences.Preferences | null = null;
  /** 主题内存缓存（唯一数据源，变更后同步落盘） */
  private static themesCache: Theme[] = [];
  /** 本机设备标识 */
  private static device: string = '';
  /** 远端主题合并处理器是否已注册（init 可能重入，只注册一次） */
  private static mergeRegistered: boolean = false;
  /** 主题数据变更监听者（本地 CRUD 与远端合并后通知，页面订阅刷新 UI） */
  private static dataListeners: Array<() => void> = [];

  /**
   * 初始化：加载 Preferences 并把历史主题读入内存缓存。
   * 页面 aboutToAppear 调用即可，重复调用无副作用。
   */
  static init(context: common.Context): void {
    if (ThemeService.pref !== null) {
      return;
    }
    // 注册远端主题合并处理器（C1.3：主题经分布式 KV 双写 + onRemoteChange 收敛；只注册一次）
    if (!ThemeService.mergeRegistered) {
      ThemeService.mergeRegistered = true;
      SyncService.onRemoteChange((changes: RemoteChanges) => {
        ThemeService.mergeRemoteThemes(changes);
      });
    }
    try {
      const options: preferences.Options = { name: ThemeService.STORE_NAME };
      ThemeService.pref = preferences.getPreferencesSync(context, options);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init preferences failed, degrade to memory only: %{public}s', JSON.stringify(err));
      ThemeService.pref = null;
      return;
    }
    ThemeService.themesCache =
      ThemeService.parseThemes(ThemeService.readStored(ThemeService.KEY_THEMES));
    ThemeService.ensureDeviceId();
    hilog.info(DOMAIN, TAG, 'init ok: %{public}d themes', ThemeService.themesCache.length);
  }

  // ==================== 主题查询 ====================

  /** 全部主题（拷贝），按创建时间倒序（最近在前） */
  static getAllThemes(): Theme[] {
    const copy: Theme[] = ThemeService.themesCache.slice();
    copy.sort((a: Theme, b: Theme): number => b.createdAt - a.createdAt);
    return copy;
  }

  /** 按 id 取主题（无则 null），返回对象按只读约定使用 */
  static getTheme(id: string): Theme | null {
    return ThemeService.findTheme(id);
  }

  // ==================== 主题变更 ====================

  /**
   * 新增主题。
   * @return 新主题（名称去重后为空返回 null）
   */
  static addTheme(name: string, colorIndex: number): Theme | null {
    const trimmed: string = name.trim();
    if (trimmed === '' || ThemeService.isNameUsed(trimmed)) {
      return null;
    }
    const now: number = Date.now();
    const theme: Theme = {
      id: util.generateRandomUUID(false),
      name: trimmed,
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
      deviceId: ThemeService.ensureDeviceId()
    };
    ThemeService.themesCache.push(theme);
    ThemeService.persist(ThemeService.KEY_THEMES, ThemeService.themesCache);
    SyncService.syncTheme(theme); // C1.3 双写：上抛分布式 KV（降级时空操作）
    ThemeService.notifyDataChanged();
    return theme;
  }

  /** 重命名主题（去重后为空返回 false） */
  static renameTheme(id: string, name: string): boolean {
    const theme: Theme | null = ThemeService.findTheme(id);
    if (theme === null) {
      return false;
    }
    const trimmed: string = name.trim();
    if (trimmed === '' || (trimmed !== theme.name && ThemeService.isNameUsed(trimmed))) {
      return false;
    }
    theme.name = trimmed;
    theme.updatedAt = Date.now();
    ThemeService.persist(ThemeService.KEY_THEMES, ThemeService.themesCache);
    SyncService.syncTheme(theme); // C1.3 双写
    ThemeService.notifyDataChanged();
    return true;
  }

  /**
   * 删除主题：只删主题本身，不清除收藏；同时剥离各收藏对该主题的关联引用
   * （经 FavoriteService.updateFavoriteThemes，逐条双写同步）。远端删除主题同理。
   */
  static removeTheme(id: string): boolean {
    const before: number = ThemeService.themesCache.length;
    ThemeService.themesCache = ThemeService.filterOutTheme(ThemeService.themesCache, id);
    const removed: boolean = ThemeService.themesCache.length < before;
    if (removed) {
      ThemeService.persist(ThemeService.KEY_THEMES, ThemeService.themesCache);
      SyncService.removeThemeSync(id); // C1.3 双写：移除分布式 KV 记录
      ThemeService.stripThemeFromFavorites(id);
      ThemeService.notifyDataChanged();
    }
    return removed;
  }

  // ==================== 页面刷新通知 ====================

  /** 订阅主题数据变化（本地 CRUD 与远端合并后触发），页面在 aboutToAppear 注册 */
  static onDataChanged(listener: () => void): void {
    ThemeService.dataListeners.push(listener);
  }

  /** 取消订阅（页面 aboutToDisappear 调用，传入注册时的同一函数引用） */
  static offDataChanged(listener: () => void): void {
    const idx: number = ThemeService.dataListeners.indexOf(listener);
    if (idx >= 0) {
      ThemeService.dataListeners.splice(idx, 1);
    }
  }

  private static notifyDataChanged(): void {
    for (let i = 0; i < ThemeService.dataListeners.length; i++) {
      ThemeService.dataListeners[i]();
    }
  }

  // ==================== 内部实现 ====================

  /** 剥离收藏关联：把收藏中出现的主题 id 移除（删除主题的善后，C1.1） */
  private static stripThemeFromFavorites(themeId: string): void {
    const favs: Favorite[] = FavoriteService.getAllFavorites();
    for (let i = 0; i < favs.length; i++) {
      const fav: Favorite = favs[i];
      const idx: number = fav.themeIds.indexOf(themeId);
      if (idx >= 0) {
        const next: string[] = fav.themeIds.slice();
        next.splice(idx, 1);
        FavoriteService.updateFavoriteThemes(fav.itemId, next);
      }
    }
  }

  /**
   * 远端主题 LWW 合并（C1.3，SyncService 回调触发；本服务是主题数据唯一权威）。
   * 合并规则与收藏/笔记一致：远端新增→采纳；双端版本不同→LWW（新者胜、deviceId 兜底）；
   * 远端删除→移除主题并剥离本端收藏引用。
   */
  private static mergeRemoteThemes(changes: RemoteChanges): void {
    let changed: boolean = false;
    for (let i = 0; i < changes.upsertThemes.length; i++) {
      const remote: Theme = changes.upsertThemes[i];
      const local: Theme | null = ThemeService.findTheme(remote.id);
      if (local === null) {
        ThemeService.themesCache.push(remote);
        changed = true;
      } else if (local.updatedAt !== remote.updatedAt || local.deviceId !== remote.deviceId) {
        if (SyncService.lwwRemoteWins(local.updatedAt, local.deviceId, remote.updatedAt, remote.deviceId)) {
          ThemeService.replaceThemeById(remote.id, remote);
          SyncService.recordConflict(remote.id, '主题双端并发修改，保留较新的远端版本');
          changed = true;
        } else {
          SyncService.syncTheme(local);
          SyncService.recordConflict(remote.id, '主题双端并发修改，保留较新的本机版本');
        }
      }
    }
    for (let i = 0; i < changes.deletedThemeIds.length; i++) {
      const themeId: string = changes.deletedThemeIds[i];
      if (ThemeService.findTheme(themeId) !== null) {
        ThemeService.themesCache = ThemeService.filterOutTheme(ThemeService.themesCache, themeId);
        ThemeService.stripThemeFromFavorites(themeId);
        changed = true;
      }
    }
    if (changed) {
      ThemeService.persist(ThemeService.KEY_THEMES, ThemeService.themesCache);
      ThemeService.notifyDataChanged();
    }
  }

  private static replaceThemeById(id: string, next: Theme): void {
    for (let i = 0; i < ThemeService.themesCache.length; i++) {
      if (ThemeService.themesCache[i].id === id) {
        ThemeService.themesCache[i] = next;
        return;
      }
    }
  }

  private static findTheme(id: string): Theme | null {
    for (let i = 0; i < ThemeService.themesCache.length; i++) {
      if (ThemeService.themesCache[i].id === id) {
        return ThemeService.themesCache[i];
      }
    }
    return null;
  }

  private static filterOutTheme(list: Theme[], id: string): Theme[] {
    const result: Theme[] = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== id) {
        result.push(list[i]);
      }
    }
    return result;
  }

  private static isNameUsed(name: string): boolean {
    for (let i = 0; i < ThemeService.themesCache.length; i++) {
      if (ThemeService.themesCache[i].name === name) {
        return true;
      }
    }
    return false;
  }

  /** 取本机设备标识：优先读已持久化值，否则生成 UUID 并落盘 */
  private static ensureDeviceId(): string {
    if (ThemeService.device !== '') {
      return ThemeService.device;
    }
    let stored: string = '';
    if (ThemeService.pref !== null) {
      try {
        const value = ThemeService.pref.getSync(ThemeService.KEY_DEVICE_ID, '');
        stored = String(value);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'read device id failed: %{public}s', JSON.stringify(err));
      }
    }
    if (stored === '') {
      stored = util.generateRandomUUID(false);
      if (ThemeService.pref !== null) {
        try {
          ThemeService.pref.putSync(ThemeService.KEY_DEVICE_ID, stored);
          ThemeService.pref.flushSync();
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'persist device id failed: %{public}s', JSON.stringify(err));
        }
      }
    }
    ThemeService.device = stored;
    return stored;
  }

  /** 整表序列化落盘（失败仅记日志，内存数据不受影响） */
  private static persist(key: string, data: object[]): void {
    const pref = ThemeService.pref;
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
    const pref = ThemeService.pref;
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

  private static parseThemes(text: string): Theme[] {
    const result: Theme[] = [];
    if (text === '') {
      return result;
    }
    let parsed: object[] = [];
    try {
      parsed = JSON.parse(text) as object[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'themes parse failed: %{public}s', JSON.stringify(err));
      return result;
    }
    for (let i = 0; i < parsed.length; i++) {
      const theme: Theme | null = ThemeService.parseTheme(parsed[i], i);
      if (theme !== null) {
        result.push(theme);
      }
    }
    return result;
  }

  private static parseTheme(obj: object, index: number): Theme | null {
    try {
      const rec = obj as Record<string, Object>;
      const id: string = ThemeService.getStr(rec, 'id');
      const name: string = ThemeService.getStr(rec, 'name');
      if (id === '' || name === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid theme #%{public}d', index);
        return null;
      }
      const theme: Theme = {
        id: id,
        name: name,
        colorIndex: ThemeService.getNum(rec, 'colorIndex'),
        createdAt: ThemeService.getNum(rec, 'createdAt'),
        updatedAt: ThemeService.getNum(rec, 'updatedAt'),
        deviceId: ThemeService.getStr(rec, 'deviceId')
      };
      return theme;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse theme #%{public}d error: %{public}s', index, JSON.stringify(err));
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
}
