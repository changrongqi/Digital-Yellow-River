/**
 * 数据模型（M6.3）：删除墓碑（Tombstone）—— 用户数据。
 *
 * 设计说明：
 * - 删除不再直接抹掉分布式 KV 键，而是用墓碑以同一键覆盖写入：
 *   离线设备的旧记录上线后，与墓碑按 LWW 比较，旧记录不会复活已删除数据；
 * - deletedAt + deviceId 与 Favorite/Note/Theme 的 updatedAt + deviceId 使用同一判定原语
 *   （SyncService.lwwRemoteWins），删除与并发编辑谁新谁生效；
 * - 收藏墓碑 id = itemId，笔记墓碑 id = noteId，主题墓碑 id = themeId；
 * - 墓碑本地随 Preferences 持久化，KV 就绪后重放，避免离线删除丢失。
 */

export interface Tombstone {
  id: string;        // 被删除实体 id（收藏=itemId / 笔记=noteId / 主题=themeId）
  deletedAt: number; // 删除时间（毫秒时间戳，LWW 版本）
  deviceId: string;  // 执行删除的设备（LWW 平局兜底）
}
