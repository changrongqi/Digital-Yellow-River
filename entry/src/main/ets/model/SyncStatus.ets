/**
 * 数据模型：同步状态（SyncStatus）—— 同步面板展示数据
 * 对应任务书「四、数据模型」SyncStatus
 */

/**
 * 冲突明细记录
 */
export interface ConflictLogItem {
  itemId: string;  // 发生冲突的数据条目 id
  time: number;    // 冲突发生时间（毫秒时间戳）
  reason: string;  // 冲突说明（如：双端同时编辑，保留 xx 设备版本）
  deviceId: string; // 胜出版本的最后写入设备 id（空串 = 无设备信息，如旧版本硬删除）
}

/**
 * 同步状态
 */
export interface SyncStatus {
  progress: number;          // 同步进度 0~100
  lastSyncTime: number;      // 最后同步时间（毫秒时间戳，0 表示从未同步/等待设备上线）
  conflictCount: number;     // 冲突记录数
  conflictLog: ConflictLogItem[]; // 冲突明细
}