/**
 * 数据模型：笔记（Note）—— 用户数据
 * 携带 deviceId + updatedAt：LWW 冲突判定（最新时间戳优先）的前提，M3 分布式同步直接复用。
 */

export interface Note {
  id: string;         // 笔记唯一标识
  itemId: string;     // 所属文化条目 id（对应 Heritage.id）
  content: string;    // 笔记正文（文字）
  createdAt: number;  // 创建时间（毫秒时间戳，自动记录）
  updatedAt: number;  // 最后修改时间（冲突判定用）
  deviceId: string;   // 设备来源（冲突判定兜底用）
}