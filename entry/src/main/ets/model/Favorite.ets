/**
 * 数据模型：收藏（Favorite）—— 用户数据
 * 携带 deviceId + updatedAt：LWW 冲突判定（最新时间戳优先）的前提，M3 分布式同步直接复用。
 */

export interface Favorite {
  id: string;         // 收藏记录唯一标识
  itemId: string;     // 被收藏的文化条目 id（对应 Heritage.id）
  tags: string[];     // 标签：内置「待实地探访/已去过/研究资料」+ 自定义
  themeIds: string[]; // 文化主题 id 集合（C1.1 新增：知识库归类，多对多；旧数据缺省空数组）
  createdAt: number;  // 收藏时间（毫秒时间戳）
  updatedAt: number;  // 最后修改时间（冲突判定用）
  deviceId: string;   // 设备来源（冲突判定兜底用）
}