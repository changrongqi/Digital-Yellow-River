/**
 * 业务服务层（M3.1~M3.3）：分布式数据同步服务。
 *
 * 职责边界（分层约定，计划书 §3）：
 * - 本服务只负责「传输 + 冲突判定原语 + 冲突台账 + 在线设备/手动同步 + 同步状态」；
 * - 收藏/笔记数据的唯一权威仍是 FavoriteService（M2.1 内存缓存 + Preferences），
 *   M3.2 起由其执行双写与远端变更合并（LWW 用本服务的判定原语）；
 * - API 用法对齐华为官方文档（@kit.ArkData distributedKVStore + @kit.DistributedServiceKit，API 12）。
 *
 * 设计说明：
 * 1. distributedKVStore 单版本 KV（SINGLE_VERSION）+ autoSync：
 *    收藏一条记录 = 键 `fav_{itemId}`，笔记一条记录 = 键 `note_{noteId}`，值 = 记录 JSON 文本。
 *    键按「业务实体」对齐，远端变更按键合并，天然与 FavoriteService 缓存对得上。
 * 2. 降级策略（O7 环境约束）：模拟器无分布式组网，KV 初始化失败/无组网时
 *    仅记日志、静默跳过同步——本地功能（M2 全部能力）不受任何影响。
 * 3. on('dataChange', SUBSCRIBE_TYPE_REMOTE) 只收远端变更：
 *    本机 put 不会触发回调，避免自己同步给自己。
 * 4. LWW 冲突判定（updatedAt 谁新谁赢；相等时 deviceId 字典序小者胜，
 *    保证两端同时写入也能收敛到同一条，不来回覆盖）。判定是纯函数，
 *    由 FavoriteService 携带本地数据调用（踩坑 3 的字段在此兑现）。
 * 5. conflictLog 保持内存态（上限 50 条，超出丢最旧；M3.4 评估结论：冲突日志是
 *    本端诊断信息，非需跨端同步的用户数据，重启清零可接受，不引入同步循环风险）。
 * 6. 踩坑 1/2/4：远端 JSON 逐字段显式转换，非法条目跳过记日志；全程不用 any。
 * 7. 所有可抛异常的 SDK 调用包 try/catch（对齐 O3 告警基线纪律）。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { distributedKVStore } from '@kit.ArkData';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { Favorite } from '../model/Favorite';
import { Note } from '../model/Note';
import { Theme } from '../model/Theme';
import { SyncStatus, ConflictLogItem } from '../model/SyncStatus';

const DOMAIN = 0x0000;
const TAG = 'SyncService';

/** 分布式 KV store id（两端设备一致才能互通） */
const STORE_ID = 'yellow_river_user_data';
/** 应用 bundleName（与 AppScope/app.json5 保持一致，createKVManager 要求） */
const BUNDLE_NAME = 'com.example.first';
/** 收藏存储键前缀：fav_{itemId} */
const KEY_FAV_PREFIX = 'fav_';
/** 笔记存储键前缀：note_{noteId} */
const KEY_NOTE_PREFIX = 'note_';
/** 主题存储键前缀：theme_{themeId}（C1.3，与收藏/笔记同一 KV store 双写通道） */
const KEY_THEME_PREFIX = 'theme_';
/** conflictLog 条数上限（超出丢最旧，避免无限增长） */
const MAX_CONFLICT_LOG = 50;

/**
 * 远端变更事件（已解析、去噪）。
 * LWW 合并由数据权威方 FavoriteService 执行（M3.2），本结构只承载解析结果。
 */
export interface RemoteChanges {
  fromDeviceId: string;        // 变更来源设备
  upsertFavorites: Favorite[];  // 远端新增/覆盖的收藏
  upsertNotes: Note[];          // 远端新增/覆盖的笔记
  upsertThemes: Theme[];        // 远端新增/覆盖的主题（C1.3）
  deletedFavoriteItemIds: string[]; // 远端删除的收藏（itemId）
  deletedNoteIds: string[];     // 远端删除的笔记（noteId）
  deletedThemeIds: string[];    // 远端删除的主题（themeId，C1.3）
}

/** 在线（可信）设备信息（M3.3 同步面板展示） */
export interface SyncDeviceInfo {
  deviceId: string;   // 分布式 deviceId（sync 目标列表用，d.ts 实测）
  deviceName: string;  // 设备显示名
}

export class SyncService {
  private static kvManager: distributedKVStore.KVManager | null = null;
  private static kvStore: distributedKVStore.SingleKVStore | null = null;
  /** 初始化只跑一次（无论成功或降级） */
  private static initialized: boolean = false;
  /** 远端变更监听者（M3.2 起 FavoriteService 注册消费） */
  private static listeners: Array<(changes: RemoteChanges) => void> = [];
  /** 同步状态监听者（M3.3：进度/最后同步时间/设备上下线变化时通知，面板订阅） */
  private static statusListeners: Array<() => void> = [];
  /** DeviceManager 实例（M3.3：在线设备查询，懒创建） */
  private static deviceManager: distributedDeviceManager.DeviceManager | null = null;
  /** DeviceManager 创建已失败标记（失败不重试，避免每次调用重复抛异常） */
  private static deviceManagerFailed: boolean = false;
  /** 冲突台账（内存态，上限 50；M3.4 结论：本端诊断信息不持久化不同步，重启清零） */
  private static conflictLog: ConflictLogItem[] = [];
  private static lastSyncTime: number = 0;
  private static progress: number = 0;

  /**
   * 初始化：创建 KVManager + SingleKVStore（autoSync），订阅远端变更。
   * 幂等，页面 aboutToAppear / FavoriteService.init 调用均可；失败降级为纯本地。
   */
  static init(context: common.Context): void {
    if (SyncService.initialized) {
      return;
    }
    SyncService.initialized = true;
    try {
      const config: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: BUNDLE_NAME
      };
      SyncService.kvManager = distributedKVStore.createKVManager(config);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'createKVManager failed, degrade to local only: %{public}s', JSON.stringify(err));
      SyncService.kvManager = null;
      return;
    }
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: false,
      backup: false,
      autoSync: true, // put 后自动向组网设备同步；模拟器无组网，等效空操作
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };
    const manager = SyncService.kvManager;
    if (manager === null) {
      return;
    }
    manager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, options)
      .then((store: distributedKVStore.SingleKVStore) => {
        SyncService.kvStore = store;
        SyncService.subscribeRemoteChanges();
        SyncService.subscribeSyncComplete();
        hilog.info(DOMAIN, TAG, 'distributed kv store ready');
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'getKVStore failed, degrade to local only: %{public}s', JSON.stringify(err));
        SyncService.kvStore = null;
      });
  }

  // ==================== 同步可用性 / 状态 ====================

  /** 分布式 KV 是否就绪（false = 已降级，仅本地） */
  static isAvailable(): boolean {
    return SyncService.kvStore !== null;
  }

  /** 同步状态快照（拷贝，同步面板 M3.3 读取） */
  static getStatus(): SyncStatus {
    const status: SyncStatus = {
      progress: SyncService.progress,
      lastSyncTime: SyncService.lastSyncTime,
      conflictCount: SyncService.conflictLog.length,
      conflictLog: SyncService.conflictLog.slice()
    };
    return status;
  }

  // ==================== 本端变更上抛（M3.2 双写调用） ====================

  /** 收藏写入/更新后上抛分布式 KV（降级时静默跳过，本地不受影响） */
  static syncFavorite(fav: Favorite): void {
    SyncService.putRecord(`${KEY_FAV_PREFIX}${fav.itemId}`, JSON.stringify(fav));
  }

  /** 笔记写入/更新后上抛分布式 KV */
  static syncNote(note: Note): void {
    SyncService.putRecord(`${KEY_NOTE_PREFIX}${note.id}`, JSON.stringify(note));
  }

  /** 收藏删除后同步移除分布式 KV 记录（远端以 deleteEntries 通知对端） */
  static removeFavoriteSync(itemId: string): void {
    SyncService.deleteRecord(`${KEY_FAV_PREFIX}${itemId}`);
  }

  /** 笔记删除后同步移除分布式 KV 记录 */
  static removeNoteSync(noteId: string): void {
    SyncService.deleteRecord(`${KEY_NOTE_PREFIX}${noteId}`);
  }

  /** 主题写入/更新后上抛分布式 KV（C1.3；降级时静默跳过，本地不受影响） */
  static syncTheme(theme: Theme): void {
    SyncService.putRecord(`${KEY_THEME_PREFIX}${theme.id}`, JSON.stringify(theme));
  }

  /** 主题删除后同步移除分布式 KV 记录（C1.3；远端以 deleteEntries 通知对端） */
  static removeThemeSync(themeId: string): void {
    SyncService.deleteRecord(`${KEY_THEME_PREFIX}${themeId}`);
  }

  // ==================== LWW 冲突判定原语（纯函数） ====================

  /**
   * LWW 判定：远端版本是否胜出。
   * updatedAt 大者胜（谁新谁赢）；完全相等时 deviceId 字典序小者胜
   * （确定性兜底：两端同时写入也收敛到同一条，不来回覆盖）。
   */
  static lwwRemoteWins(localUpdatedAt: number, localDeviceId: string,
    remoteUpdatedAt: number, remoteDeviceId: string): boolean {
    if (remoteUpdatedAt !== localUpdatedAt) {
      return remoteUpdatedAt > localUpdatedAt;
    }
    return remoteDeviceId < localDeviceId;
  }

  /** 冲突台账登记（M3.2 合并冲突时调用，同步面板展示） */
  static recordConflict(itemId: string, reason: string): void {
    const item: ConflictLogItem = {
      itemId: itemId,
      time: Date.now(),
      reason: reason
    };
    SyncService.conflictLog.push(item);
    if (SyncService.conflictLog.length > MAX_CONFLICT_LOG) {
      SyncService.conflictLog.splice(0, SyncService.conflictLog.length - MAX_CONFLICT_LOG);
    }
  }

  // ==================== 远端变更订阅（M3.2 消费） ====================

  /** 注册远端变更监听（FavoriteService 合并入口，M3.2 接线） */
  static onRemoteChange(listener: (changes: RemoteChanges) => void): void {
    SyncService.listeners.push(listener);
  }

  private static notifyListeners(changes: RemoteChanges): void {
    for (let i = 0; i < SyncService.listeners.length; i++) {
      SyncService.listeners[i](changes);
    }
  }

  // ==================== 内部实现 ====================

  private static subscribeRemoteChanges(): void {
    const store = SyncService.kvStore;
    if (store === null) {
      return;
    }
    try {
      // SUBSCRIBE_TYPE_REMOTE：只收远端设备变更，本机 put 不触发（避免自己同步给自己）
      store.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE,
        (data: distributedKVStore.ChangeNotification) => {
          SyncService.handleRemoteChanges(data);
        });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'subscribe dataChange failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 远端变更解析：按键前缀分类 + 逐字段显式转换（踩坑 1/2/4），非法条目跳过 */
  private static handleRemoteChanges(data: distributedKVStore.ChangeNotification): void {
    const changes: RemoteChanges = {
      fromDeviceId: data.deviceId,
      upsertFavorites: [],
      upsertNotes: [],
      upsertThemes: [],
      deletedFavoriteItemIds: [],
      deletedNoteIds: [],
      deletedThemeIds: []
    };
    // insertEntries + updateEntries 在单版本 KV 中都是「写入/覆盖」语义
    const upserts: distributedKVStore.Entry[] = [];
    for (let i = 0; i < data.insertEntries.length; i++) {
      upserts.push(data.insertEntries[i]);
    }
    for (let i = 0; i < data.updateEntries.length; i++) {
      upserts.push(data.updateEntries[i]);
    }
    for (let i = 0; i < upserts.length; i++) {
      const entry: distributedKVStore.Entry = upserts[i];
      const text: string = SyncService.entryText(entry);
      if (entry.key.indexOf(KEY_FAV_PREFIX) === 0) {
        const fav: Favorite | null = SyncService.parseFavoriteFromWire(text, entry.key);
        if (fav !== null) {
          changes.upsertFavorites.push(fav);
        }
      } else if (entry.key.indexOf(KEY_NOTE_PREFIX) === 0) {
        const note: Note | null = SyncService.parseNoteFromWire(text, entry.key);
        if (note !== null) {
          changes.upsertNotes.push(note);
        }
      } else if (entry.key.indexOf(KEY_THEME_PREFIX) === 0) {
        const theme: Theme | null = SyncService.parseThemeFromWire(text, entry.key);
        if (theme !== null) {
          changes.upsertThemes.push(theme);
        }
      }
    }
    for (let i = 0; i < data.deleteEntries.length; i++) {
      const key: string = data.deleteEntries[i].key;
      if (key.indexOf(KEY_FAV_PREFIX) === 0) {
        changes.deletedFavoriteItemIds.push(key.substring(KEY_FAV_PREFIX.length));
      } else if (key.indexOf(KEY_NOTE_PREFIX) === 0) {
        changes.deletedNoteIds.push(key.substring(KEY_NOTE_PREFIX.length));
      } else if (key.indexOf(KEY_THEME_PREFIX) === 0) {
        changes.deletedThemeIds.push(key.substring(KEY_THEME_PREFIX.length));
      }
    }
    SyncService.lastSyncTime = Date.now();
    SyncService.progress = 100;
    SyncService.notifyListeners(changes);
    SyncService.notifyStatusListeners();
  }

  // ==================== 在线设备与手动同步（M3.3） ====================

  /**
   * 在线（可信）设备列表。
   * API 事实（本机 SDK d.ts + 官方「跨设备同步 KV Store」指南双核对）：
   * - getAvailableDeviceListSync 仅需 ohos.permission.DISTRIBUTED_DATASYNC（M3.1 已声明，无新增权限）；
   * - 官方 sync 示例即用该列表的 deviceId 作为同步目标；
   * - 降级（DeviceManager 创建失败/查询异常）返回空数组，不影响其余功能。
   */
  static getOnlineDevices(): SyncDeviceInfo[] {
    const dm = SyncService.ensureDeviceManager();
    if (dm === null) {
      return [];
    }
    try {
      const list: Array<distributedDeviceManager.DeviceBasicInfo> = dm.getAvailableDeviceListSync();
      const result: SyncDeviceInfo[] = [];
      for (let i = 0; i < list.length; i++) {
        const info: SyncDeviceInfo = {
          deviceId: list[i].deviceId,
          deviceName: list[i].deviceName
        };
        result.push(info);
      }
      return result;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'getAvailableDeviceListSync failed: %{public}s', JSON.stringify(err));
      return [];
    }
  }

  /**
   * 手动同步入口（同步面板「立即同步」）：
   * 对全部在线可信设备 PUSH_PULL（推本端 + 拉远端）；完成经 syncComplete 回调刷新状态。
   * @return sync 是否成功受理（false = KV 未就绪 / 无在线设备 / 调用异常）
   */
  static manualSync(): boolean {
    const store = SyncService.kvStore;
    if (store === null) {
      return false;
    }
    const devices: SyncDeviceInfo[] = SyncService.getOnlineDevices();
    if (devices.length === 0) {
      return false; // 单机/无组网：等待设备上线（面板显示降级文案）
    }
    const ids: string[] = [];
    for (let i = 0; i < devices.length; i++) {
      ids.push(devices[i].deviceId);
    }
    try {
      store.sync(ids, distributedKVStore.SyncMode.PUSH_PULL);
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'manual sync failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /** 订阅同步状态变化（进度/最后同步时间/设备上下线），同步面板 aboutToAppear 注册 */
  static onStatusChanged(listener: () => void): void {
    SyncService.statusListeners.push(listener);
  }

  /** 取消订阅（面板 aboutToDisappear 调用，传入注册时的同一函数引用） */
  static offStatusChanged(listener: () => void): void {
    const idx: number = SyncService.statusListeners.indexOf(listener);
    if (idx >= 0) {
      SyncService.statusListeners.splice(idx, 1);
    }
  }

  private static notifyStatusListeners(): void {
    for (let i = 0; i < SyncService.statusListeners.length; i++) {
      SyncService.statusListeners[i]();
    }
  }

  /** DeviceManager 懒创建 + 失败熔断（已失败不再重试） */
  private static ensureDeviceManager(): distributedDeviceManager.DeviceManager | null {
    if (SyncService.deviceManager !== null) {
      return SyncService.deviceManager;
    }
    if (SyncService.deviceManagerFailed) {
      return null;
    }
    try {
      SyncService.deviceManager = distributedDeviceManager.createDeviceManager(BUNDLE_NAME);
      SyncService.subscribeDeviceStateChange();
      return SyncService.deviceManager;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'createDeviceManager failed, device query degrade: %{public}s', JSON.stringify(err));
      SyncService.deviceManagerFailed = true;
      return null;
    }
  }

  /** 设备上下线 → 通知面板刷新设备列表与状态（回调载荷不使用，零参函数结构兼容官方签名） */
  private static subscribeDeviceStateChange(): void {
    const dm = SyncService.deviceManager;
    if (dm === null) {
      return;
    }
    try {
      dm.on('deviceStateChange', () => {
        SyncService.notifyStatusListeners();
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'subscribe deviceStateChange failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 手动/自动同步完成 → 刷新最后同步时间并通知面板（回调载荷不使用） */
  private static subscribeSyncComplete(): void {
    const store = SyncService.kvStore;
    if (store === null) {
      return;
    }
    try {
      store.on('syncComplete', () => {
        SyncService.lastSyncTime = Date.now();
        SyncService.progress = 100;
        SyncService.notifyStatusListeners();
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'subscribe syncComplete failed: %{public}s', JSON.stringify(err));
    }
  }

  /** Entry 值统一转字符串（本应用只写 string 值；其他类型视为空） */
  private static entryText(entry: distributedKVStore.Entry): string {
    const raw: Uint8Array | string | number | boolean = entry.value.value;
    if (typeof raw === 'string') {
      return raw;
    }
    return '';
  }

  private static putRecord(key: string, json: string): void {
    const store = SyncService.kvStore;
    if (store === null) {
      return; // 降级：本地照常工作，仅不同步
    }
    // 本 SDK 版本 SingleKVStore 仅有 Promise 形式 put/delete（d.ts 实测，无 putSync）
    store.put(key, json)
      .then(() => {
        SyncService.progress = 100;
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'put %{public}s failed: %{public}s', key, JSON.stringify(err));
      });
  }

  private static deleteRecord(key: string): void {
    const store = SyncService.kvStore;
    if (store === null) {
      return;
    }
    store.delete(key)
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'delete %{public}s failed: %{public}s', key, JSON.stringify(err));
      });
  }

  // ==================== 线格式解析（踩坑 1/2/4：逐字段显式转换） ====================

  private static parseFavoriteFromWire(text: string, key: string): Favorite | null {
    try {
      const rec = JSON.parse(text) as Record<string, Object>;
      const id: string = SyncService.getStr(rec, 'id');
      const itemId: string = SyncService.getStr(rec, 'itemId');
      if (id === '' || itemId === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid remote favorite %{public}s', key);
        return null;
      }
      const fav: Favorite = {
        id: id,
        itemId: itemId,
        tags: SyncService.getStrArray(rec, 'tags'),
        themeIds: SyncService.getStrArray(rec, 'themeIds'),
        createdAt: SyncService.getNum(rec, 'createdAt'),
        updatedAt: SyncService.getNum(rec, 'updatedAt'),
        deviceId: SyncService.getStr(rec, 'deviceId')
      };
      return fav;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse remote favorite %{public}s failed: %{public}s', key, JSON.stringify(err));
      return null;
    }
  }

  private static parseNoteFromWire(text: string, key: string): Note | null {
    try {
      const rec = JSON.parse(text) as Record<string, Object>;
      const id: string = SyncService.getStr(rec, 'id');
      const itemId: string = SyncService.getStr(rec, 'itemId');
      const content: string = SyncService.getStr(rec, 'content');
      if (id === '' || itemId === '' || content === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid remote note %{public}s', key);
        return null;
      }
      const note: Note = {
        id: id,
        itemId: itemId,
        content: content,
        createdAt: SyncService.getNum(rec, 'createdAt'),
        updatedAt: SyncService.getNum(rec, 'updatedAt'),
        deviceId: SyncService.getStr(rec, 'deviceId')
      };
      return note;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse remote note %{public}s failed: %{public}s', key, JSON.stringify(err));
      return null;
    }
  }

  private static parseThemeFromWire(text: string, key: string): Theme | null {
    try {
      const rec = JSON.parse(text) as Record<string, Object>;
      const id: string = SyncService.getStr(rec, 'id');
      const name: string = SyncService.getStr(rec, 'name');
      if (id === '' || name === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid remote theme %{public}s', key);
        return null;
      }
      const theme: Theme = {
        id: id,
        name: name,
        colorIndex: SyncService.getNum(rec, 'colorIndex'),
        createdAt: SyncService.getNum(rec, 'createdAt'),
        updatedAt: SyncService.getNum(rec, 'updatedAt'),
        deviceId: SyncService.getStr(rec, 'deviceId')
      };
      return theme;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse remote theme %{public}s failed: %{public}s', key, JSON.stringify(err));
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
