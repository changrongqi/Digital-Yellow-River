/**
 * 图谱数据模型（节点 / 边 / 图模型）
 *
 * 设计参考（C1.4 图谱重构）：
 * - relation-graph：核心数据与渲染分离，节点/边只描述「是什么」，坐标由布局层计算；
 * - Trilium Notes Note Map：根节点为中心，关系边有类型（归入 / 拓展 / 同类关联），
 *   点击节点是导航入口而非装饰；
 * - Obsidian Graph View：节点半径按连接度（degree）编码，关系越密视觉权重越高。
 *
 * 约定：
 * - key 是图内唯一键（带类型前缀，避免主题 id / 遗址 id / 推荐 id 冲突）；
 * - itemId 是业务 id（主题 id 或遗址 id），页面据此打开详情/定位数据；
 * - x/y 由 GraphLayout 写入，UI 层不得自行编造坐标。
 */

/** 节点种类（NONE 仅用于页面「未选中」状态） */
export enum GraphNodeKind {
  NONE = 'none',
  THEME = 'theme',
  HERITAGE = 'heritage',
  RECOMMEND = 'recommend'
}

/** 边种类：归入主题 / 拓展推荐 / 同类关联 */
export enum GraphEdgeKind {
  CONTAINS = 'contains',
  RECOMMEND = 'recommend',
  AFFINITY = 'affinity'
}

/** 图谱节点 */
export interface GraphNode {
  key: string;        // 图内唯一键（如 theme:xxx / h:xxx / r:xxx）
  itemId: string;     // 业务 id（主题 id 或遗址 id）
  label: string;      // 展示名称
  kind: GraphNodeKind;
  fill: string;       // 节点填充色
  stroke: string;     // 节点描边色
  radius: number;     // 绘制半径（世界坐标 vp）
  degree: number;     // 连接度（决定遗址节点大小）
  x: number;          // 世界坐标（布局层写入）
  y: number;
  pinned: boolean;    // 固定节点（中心主题不参与力导向位移）
}

/** 图谱边 */
export interface GraphEdge {
  sourceKey: string;  // 起点节点 key
  targetKey: string;  // 终点节点 key
  kind: GraphEdgeKind;
  weight: number;     // 关联强度 0~1（亲和边决定线宽/透明度）
}

/** 一张完整的图模型（布局前坐标为初始值，布局后为最终值） */
export interface GraphModel {
  nodes: GraphNode[];
  edges: GraphEdge[];
}
