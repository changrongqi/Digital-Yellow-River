/**
 * 数据模型（C1.1）：文化主题（Theme）—— 用户数据
 *
 * 设计说明（计划书 M5 C1）：
 * - 主题是「文化脉络聚合」维度（如「彩陶文化」「青铜文明」「帝王陵寝」），
 *   与 M2 收藏标签是两个维度：标签是收藏卡片的管理分类，主题是知识库的知识节点；
 * - 一个收藏可归入多个主题（Favorite.themeIds），多对多；
 * - 携带 deviceId + updatedAt：与 Favorite/Note 一致，M3 LWW 冲突判定直接复用
 *   （远端主题经分布式 KV 双写 + onRemoteChange 合并，C1.3）；
 * - colorIndex：主题色板下标（KnowledgeGraph 绘制知识节点时取色，越界取余兜底）。
 */

export interface Theme {
  id: string;         // 主题唯一标识（UUID）
  name: string;       // 主题名称（如「彩陶文化」）
  colorIndex: number; // 主题色板下标（0 起）
  createdAt: number;  // 创建时间（毫秒时间戳）
  updatedAt: number;  // 最后修改时间（LWW 冲突判定用）
  deviceId: string;   // 设备来源（LWW 冲突判定兜底用）
}
