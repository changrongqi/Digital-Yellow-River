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
import { Tombstone } from '../model/Tombstone';
import { SyncStatus, ConflictLogItem } from '../model/SyncStatus';
import { PermissionService } from './PermissionService';

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
/** 初始化失败后的自动重试间隔（ms）：避免页面频繁 init 造成重复创建 */
const INIT_RETRY_MIN_INTERVAL = 3000;
/** 自动同步最小间隔（ms）：设备上下线/回前台可能连续触发，避免重复 sync */
const AUTO_SYNC_MIN_INTERVAL = 2000;
/** KV 未就绪时的待写队列上限（同键只保留最后一次，超出丢最旧） */
const MAX_PENDING_PUTS = 200;

/** 待写记录（M6.3：KV 未就绪时本地仍可操作，就绪后补写，避免删除/重新收藏状态丢失） */
interface PendingPut {
  key: string;
  json: string;
}

/**
 * 远端变更事件（已解析、去噪）。
 * LWW 合并由数据权威方 FavoriteService 执行（M3.2），本结构只承载解析结果。
 */
export interface RemoteChanges {
  fromDeviceId: string;        // 变更来源设备
  upsertFavorites: Favorite[];  // 远端新增/覆盖的收藏
  upsertNotes: Note[];          // 远端新增/覆盖的笔记
  upsertThemes: Theme[];        // 远端新增/覆盖的主题（C1.3）
  favoriteTombstones: Tombstone[]; // 远端删除收藏的墓碑（M6.3，id=itemId）
  noteTombstones: Tombstone[];     // 远端删除笔记的墓碑（M6.3，id=noteId）
  themeTombstones: Tombstone[];    // 远端删除主题的墓碑（M6.3，id=themeId）
  deletedFavoriteItemIds: string[]; // 旧版本硬删除的收藏（无时间戳，兼容保留）
  deletedNoteIds: string[];     // 旧版本硬删除的笔记
  deletedThemeIds: string[];    // 旧版本硬删除的主题
}

/**
 * 在线（可信）设备信息（M3.3 同步面板展示）。
 * sync 目标必须用 DeviceBasicInfo.networkId；DeviceBasicInfo.deviceId 是 UDID 混淆值，
 * 不能作为 KV sync 的 deviceIds（官方 d.ts sync() 参数说明 + 官方示例双重确认）。
 */
export interface SyncDeviceInfo {
  networkId: string;   // 网络 ID（KV sync 目标列表用）
  deviceName: string;  // 设备显示名
}

export class SyncService {
  private static kvManager: distributedKVStore.KVManager | null = null;
  private static kvStore: distributedKVStore.SingleKVStore | null = null;
  /** 初始化成功标记（只有 KV store 真正就绪才置 true；失败保留可重试） */
  private static initialized: boolean = false;
  /** 初始化进行中标记（防止并发重复创建 KVManager/KVStore） */
  private static initializing: boolean = false;
  /** 上次初始化尝试时间（失败后按 INIT_RETRY_MIN_INTERVAL 节流） */
  private static lastInitAttempt: number = 0;
  /** 上次自动同步请求时间（设备上下线/回前台节流） */
  private static lastAutoSyncRequest: number = 0;
  /** 业务监听尚未注册时挂起的初次追赶（注册后补发，避免远端变更无人消费） */
  private static initialSyncPending: boolean = false;
  /** 权限未授予的日志只打一次，避免多个页面 init 重复刷屏 */
  private static permissionWarned: boolean = false;
  /** 远端变更监听者（M3.2 起 FavoriteService 注册消费） */
  private static listeners: Array<(changes: RemoteChanges) => void> = [];
  /** KV 就绪监听者（M6.3：墓碑重放入口，业务方注册后 KV ready 时触发一次） */
  private static readyListeners: Array<() => void> = [];
  /** KV 未就绪期间的待写记录（M6.3，就绪后补写；同键保留最后一次） */
  private static pendingPuts: PendingPut[] = [];
  /** 同步状态监听者（M3.3：进度/最后同步时间/设备上下线变化时通知，面板订阅） */
  private static statusListeners: Array<() => void> = [];
  /** DeviceManager 实例（M3.3：在线设备查询，懒创建） */
  private static deviceManager: distributedDeviceManager.DeviceManager | null = null;
  /** 上次 DeviceManager 创建尝试时间（失败后节流重试，不再永久熔断） */
  private static lastDeviceManagerAttempt: number = 0;
  /** 冲突台账（内存态，上限 50；M3.4 结论：本端诊断信息不持久化不同步，重启清零） */
  private static conflictLog: ConflictLogItem[] = [];
  private static lastSyncTime: number = 0;
  private static progress: number = 0;

  /**
   * 初始化：创建 KVManager + SingleKVStore（autoSync），订阅远端变更。
   * 幂等，页面 aboutToAppear / FavoriteService.init 调用均可。
   * M6.2：失败不再永久熔断，保留可重试状态；本地功能始终不受影响。
   */
  static init(context: common.Context): void {
    if (SyncService.initialized || SyncService.initializing) {
      return;
    }
    // M6.1：DISTRIBUTED_DATASYNC 是 user_grant，未授权时不能创建/使用分布式 KV。
    // 这里只做门禁，不在这里弹窗（弹窗需要 UIAbilityContext，由 EntryAbility/SyncPanel 发起）；
    // 不设置 initialized，保证授权成功后还能再次 init。
    if (!PermissionService.isSyncPermissionGranted()) {
      if (!SyncService.permissionWarned) {
        SyncService.permissionWarned = true;
        hilog.info(DOMAIN, TAG, 'DISTRIBUTED_DATASYNC not granted, sync init deferred');
      }
      return;
    }
    // M6.2：失败后允许重试，但按间隔节流，避免页面 aboutToAppear 连续触发重复创建。
    const now: number = Date.now();
    if (now - SyncService.lastInitAttempt < INIT_RETRY_MIN_INTERVAL) {
      return;
    }
    SyncService.lastInitAttempt = now;
    SyncService.permissionWarned = false;
    SyncService.initializing = true;
    try {
      const config: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: BUNDLE_NAME
      };
      SyncService.kvManager = distributedKVStore.createKVManager(config);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'createKVManager failed, retry later: %{public}s', JSON.stringify(err));
      SyncService.kvManager = null;
      SyncService.initializing = false;
      SyncService.initialized = false;
      SyncService.notifyStatusListeners();
      return;
    }
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: false,
      backup: false,
      autoSync: true, // 数据变更自动同步；不等价于初次拉取，需 M6.2 显式 PUSH_PULL 追赶
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };
    const manager = SyncService.kvManager;
    if (manager === null) {
      SyncService.initializing = false;
      SyncService.initialized = false;
      return;
    }
    manager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, options)
      .then((store: distributedKVStore.SingleKVStore) => {
        SyncService.kvStore = store;
        SyncService.initializing = false;
        SyncService.initialized = true;
        // M6.3：补写 KV 未就绪期间（未授权/初始化失败/离线）的本地变更，
        // 避免旧的墓碑或旧记录残留在 KV 中与当前本地状态冲突。
        SyncService.flushPendingPuts();
        SyncService.subscribeRemoteChanges();
        SyncService.subscribeSyncComplete();
        hilog.info(DOMAIN, TAG, 'distributed kv store ready');
        // M6.1：KV 就绪后主动通知面板，避免面板停留在「单机模式」（O11 的同一触发点）。
        SyncService.notifyStatusListeners();
        // M6.3：KV 未就绪期间的删除只落了本地墓碑，ready 后重放写入 KV，
        // 否则本地 KV 中的旧记录会在下次同步中把已删除数据推给对端。
        SyncService.notifyReadyListeners();
        // M6.2：autoSync 只在数据变更时自动推拉；新设备首次启动/离线期间的数据
        // 需要通过一次 PUSH_PULL 主动追赶。无在线设备时为空操作，设备上线事件会再触发。
        SyncService.syncWhenOnline();
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'getKVStore failed, retry later: %{public}s', JSON.stringify(err));
        SyncService.kvStore = null;
        SyncService.kvManager = null;
        SyncService.initializing = false;
        SyncService.initialized = false;
        SyncService.notifyStatusListeners();
      });
  }

  /** 显式重试初始化：面板「重试初始化」入口调用（绕过失败节流） */
  static retryInit(context: common.Context): void {
    SyncService.lastInitAttempt = 0;
    SyncService.init(context);
  }

  // ==================== 同步可用性 / 状态 ====================

  /** 分布式 KV 是否就绪（false = 已降级，仅本地） */
  static isAvailable(): boolean {
    return SyncService.kvStore !== null;
  }

  /** 是否已授予分布式数据同步权限（供同步面板展示/决定是否显示授权入口） */
  static isPermissionGranted(): boolean {
    return PermissionService.isSyncPermissionGranted();
  }

  /**
   * 申请分布式数据同步权限；授予后立即重试初始化。
   * 只应在 UIAbility 上下文可用时调用（EntryAbility / SyncPanel）。
   */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    const granted: boolean = await PermissionService.requestSyncPermission(context);
    if (granted) {
      SyncService.permissionWarned = false;
      SyncService.init(context);
    }
    return granted;
  }

  /** 用户拒绝后的再次授权入口（权限设置弹窗）；授予后重试初始化 */
  static async requestPermissionOnSetting(context: common.UIAbilityContext): Promise<boolean> {
    const granted: boolean = await PermissionService.requestSyncPermissionOnSetting(context);
    if (granted) {
      SyncService.permissionWarned = false;
      SyncService.init(context);
    }
    return granted;
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

  /**
   * 收藏删除后写入墓碑（M6.3）。
   * 用同一键 fav_{itemId} 覆盖原记录，让删除作为带时间戳的版本参与 LWW，
   * 而不是直接删键——直接删键无法阻止离线设备的旧记录复活。
   */
  static syncFavoriteTombstone(tomb: Tombstone): void {
    SyncService.putRecord(`${KEY_FAV_PREFIX}${tomb.id}`, JSON.stringify(tomb));
  }

  /** 笔记删除后写入墓碑（M6.3，键 note_{noteId} 覆盖原记录） */
  static syncNoteTombstone(tomb: Tombstone): void {
    SyncService.putRecord(`${KEY_NOTE_PREFIX}${tomb.id}`, JSON.stringify(tomb));
  }

  /** 主题写入/更新后上抛分布式 KV（C1.3；降级时静默跳过，本地不受影响） */
  static syncTheme(theme: Theme): void {
    SyncService.putRecord(`${KEY_THEME_PREFIX}${theme.id}`, JSON.stringify(theme));
  }

  /** 主题删除后写入墓碑（M6.3，键 theme_{themeId} 覆盖原记录） */
  static syncThemeTombstone(tomb: Tombstone): void {
    SyncService.putRecord(`${KEY_THEME_PREFIX}${tomb.id}`, JSON.stringify(tomb));
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

  /**
   * 注册 KV 就绪监听（M6.3）：用于重放本地墓碑。
   * 已就绪时立即执行，保证注册晚于初始化时也不会漏掉。
   */
  static onReady(listener: () => void): void {
    if (SyncService.kvStore !== null) {
      listener();
      return;
    }
    SyncService.readyListeners.push(listener);
  }

  private static notifyReadyListeners(): void {
    for (let i = 0; i < SyncService.readyListeners.length; i++) {
      SyncService.readyListeners[i]();
    }
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
      favoriteTombstones: [],
      noteTombstones: [],
      themeTombstones: [],
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
      // M6.3：同一键既可能是实体记录，也可能是删除墓碑；以 deletedAt 字段区分。
      const tomb: Tombstone | null = SyncService.parseTombstone(text, entry.key);
      if (tomb !== null) {
        if (entry.key.indexOf(KEY_FAV_PREFIX) === 0) {
          changes.favoriteTombstones.push(tomb);
        } else if (entry.key.indexOf(KEY_NOTE_PREFIX) === 0) {
          changes.noteTombstones.push(tomb);
        } else if (entry.key.indexOf(KEY_THEME_PREFIX) === 0) {
          changes.themeTombstones.push(tomb);
        }
      } else if (entry.key.indexOf(KEY_FAV_PREFIX) === 0) {
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
   * - sync(deviceIds) 的 deviceIds 实际是 DeviceBasicInfo.networkId；DeviceBasicInfo.deviceId
   *   是 UDID 混淆值，不能作为同步目标（官方 d.ts 参数说明 + 官方示例）；
   * - 缺 networkId 的设备跳过（无法 sync），不影响其余设备展示；
   * - 降级（DeviceManager 创建失败/查询异常）返回空数组，不影响其余功能。
   */
  static getOnlineDevices(): SyncDeviceInfo[] {
    // 未授权时 getAvailableDeviceListSync 必抛 201：直接返回空，避免把权限问题伪装成查询异常。
    if (!PermissionService.isSyncPermissionGranted()) {
      return [];
    }
    const dm = SyncService.ensureDeviceManager();
    if (dm === null) {
      return [];
    }
    try {
      const list: Array<distributedDeviceManager.DeviceBasicInfo> = dm.getAvailableDeviceListSync();
      const result: SyncDeviceInfo[] = [];
      for (let i = 0; i < list.length; i++) {
        const networkId: string | undefined = list[i].networkId;
        if (networkId === undefined || networkId === '') {
          continue;
        }
        const info: SyncDeviceInfo = {
          networkId: networkId,
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

  /** 自动追赶同步（M6.2）：KV ready / 设备上线 / 回前台调用；无在线设备时空操作 */
  static syncWhenOnline(): void {
    SyncService.requestSync(false);
  }

  /**
   * 手动同步入口（同步面板「立即同步」）：
   * 对全部在线可信设备 PUSH_PULL（推本端 + 拉远端）；完成经 syncComplete 回调刷新状态。
   * @return sync 是否成功受理（false = KV 未就绪 / 无在线设备 / 调用异常）
   */
  static manualSync(): boolean {
    return SyncService.requestSync(true);
  }

  /**
   * 统一 PUSH_PULL 请求。
   * @param force true=用户手动（不节流、不延迟）；false=自动追赶（2s 节流 + 1s 合并延迟）
   */
  private static requestSync(force: boolean): boolean {
    const store = SyncService.kvStore;
    if (store === null) {
      return false;
    }
    if (!force && SyncService.listeners.length === 0) {
      // 业务监听未注册时先挂起：否则初次 PULL 的远端变更无人消费会丢失。
      SyncService.initialSyncPending = true;
      return false;
    }
    const now: number = Date.now();
    if (!force && now - SyncService.lastAutoSyncRequest < AUTO_SYNC_MIN_INTERVAL) {
      return false;
    }
    const devices: SyncDeviceInfo[] = SyncService.getOnlineDevices();
    if (devices.length === 0) {
      return false; // 单机/无组网：等待设备上线（面板显示降级文案）
    }
    const ids: string[] = [];
    for (let i = 0; i < devices.length; i++) {
      ids.push(devices[i].networkId);
    }
    if (ids.length === 0) {
      return false;
    }
    SyncService.initialSyncPending = false;
    SyncService.lastAutoSyncRequest = now;
    try {
      SyncService.progress = 10;
      SyncService.notifyStatusListeners();
      // delayMs：自动同步给 1s 合并窗口；手动同步立即执行。
      store.sync(ids, distributedKVStore.SyncMode.PUSH_PULL, force ? 0 : 1000);
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'sync failed: %{public}s', JSON.stringify(err));
      SyncService.progress = 0;
      SyncService.notifyStatusListeners();
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

  /** DeviceManager 懒创建 + 失败节流重试（不再永久熔断，避免一次瞬时失败导致设备列表永远为空） */
  private static ensureDeviceManager(): distributedDeviceManager.DeviceManager | null {
    if (SyncService.deviceManager !== null) {
      return SyncService.deviceManager;
    }
    const now: number = Date.now();
    if (now - SyncService.lastDeviceManagerAttempt < INIT_RETRY_MIN_INTERVAL) {
      return null;
    }
    SyncService.lastDeviceManagerAttempt = now;
    try {
      SyncService.deviceManager = distributedDeviceManager.createDeviceManager(BUNDLE_NAME);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'createDeviceManager failed, retry later: %{public}s', JSON.stringify(err));
      return null;
    }
    SyncService.subscribeDeviceStateChange();
    return SyncService.deviceManager;
  }

  /** 设备上下线 → 通知面板刷新 + 主动追赶同步（回调载荷不使用，零参函数结构兼容官方签名） */
  private static subscribeDeviceStateChange(): void {
    const dm = SyncService.deviceManager;
    if (dm === null) {
      return;
    }
    try {
      dm.on('deviceStateChange', () => {
        SyncService.notifyStatusListeners();
        // M6.2：设备上线后主动 PUSH_PULL，保证新设备/离线期间的数据能收敛。
        SyncService.syncWhenOnline();
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
      // M6.3：KV 未就绪（降级/未授权/初始化中）时排队，就绪后补写。
      SyncService.enqueuePendingPut(key, json);
      return;
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

  /** 待写入队：同键只保留最后一次写入（如「删除 → 重新收藏」只留新记录） */
  private static enqueuePendingPut(key: string, json: string): void {
    for (let i = 0; i < SyncService.pendingPuts.length; i++) {
      if (SyncService.pendingPuts[i].key === key) {
        SyncService.pendingPuts.splice(i, 1);
        break;
      }
    }
    const put: PendingPut = {
      key: key,
      json: json
    };
    SyncService.pendingPuts.push(put);
    if (SyncService.pendingPuts.length > MAX_PENDING_PUTS) {
      SyncService.pendingPuts.splice(0, SyncService.pendingPuts.length - MAX_PENDING_PUTS);
    }
  }

  /** KV 就绪后补写待写记录（队列只在内存中，进程被杀则丢弃；用户数据本身仍由 Preferences 持久化） */
  private static flushPendingPuts(): void {
    const store = SyncService.kvStore;
    if (store === null) {
      return;
    }
    const pending: PendingPut[] = SyncService.pendingPuts.slice();
    SyncService.pendingPuts = [];
    for (let i = 0; i < pending.length; i++) {
      const put: PendingPut = pending[i];
      store.put(put.key, put.json)
        .then(() => {
          SyncService.progress = 100;
        })
        .catch((err: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'flush %{public}s failed: %{public}s', put.key, JSON.stringify(err));
        });
    }
  }

  // ==================== 线格式解析（踩坑 1/2/4：逐字段显式转换） ====================

  /** 解析删除墓碑（M6.3）：仅有 deletedAt>0 的条目才是墓碑；实体记录返回 null 交给各自解析 */
  private static parseTombstone(text: string, key: string): Tombstone | null {
    try {
      const rec = JSON.parse(text) as Record<string, Object>;
      const deletedAt: number = SyncService.getNum(rec, 'deletedAt');
      if (deletedAt <= 0) {
        return null;
      }
      const id: string = SyncService.getStr(rec, 'id');
      if (id === '') {
        hilog.warn(DOMAIN, TAG, 'skip invalid remote tombstone %{public}s', key);
        return null;
      }
      const tomb: Tombstone = {
        id: id,
        deletedAt: deletedAt,
        deviceId: SyncService.getStr(rec, 'deviceId')
      };
      return tomb;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse remote tombstone %{public}s failed: %{public}s', key, JSON.stringify(err));
      return null;
    }
  }

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
