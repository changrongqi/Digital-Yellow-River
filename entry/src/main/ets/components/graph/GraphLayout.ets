/**
 * 知识图谱「纯数据 + 纯布局」层（C1.4 图谱重构）
 *
 * 设计参考：
 * - relation-graph：核心数据模型与布局算法独立于渲染，布局输出世界坐标，渲染层只做视口变换；
 * - Trilium Notes Note Map：根节点（主题）固定为中心，周围是已归类遗址；
 *   拓展推荐不另起一圈，而是挂在「最相似的已归类遗址」旁，关系语义更清晰；
 * - Obsidian Graph View：力导向布局（斥力 + 弹簧 + 向心 + 碰撞消解），
 *   节点大小按连接度编码，同类关联只保留每个节点最强的若干条，避免毛球化。
 *
 * 本文件不依赖任何 UI / Canvas API：输入主题与遗址，输出 GraphModel 与视口变换。
 * 其中 buildGraphModel / computeBounds / computeFitTransform 为纯函数；
 * layoutGraph 是确定性原地布局（直接把坐标写回 GraphModel，同一输入必得同一坐标）。
 */

import { Heritage } from '../../model/Heritage';
import { Theme, getThemeColor } from '../../model/Theme';
import { getEraTheme } from '../../utils/EraTheme';
import { ThemeTokens } from '../../utils/ThemeTokens';
import { GraphNode, GraphEdge, GraphModel, GraphNodeKind, GraphEdgeKind } from './GraphNode';

/** 中心主题节点半径（世界坐标） */
const THEME_RADIUS: number = 44;
/** 已归类遗址基础半径（连接度增加后最大约 27.5） */
const HERITAGE_BASE_RADIUS: number = 20;
/** 拓展推荐节点半径 */
const RECOMMEND_RADIUS: number = 16;
/** 标签预留高度（参与视口适配，避免标签被裁） */
const LABEL_SPACE: number = 18;
/** 标签最大半宽（世界坐标；屏幕固定字号 11vp 时约 6 个汉字） */
const LABEL_HALF_WIDTH: number = 34;
/** 每个遗址节点最多保留的同类关联边数（Obsidian 式防毛球） */
const MAX_AFFINITY_PER_NODE: number = 3;

/** 布局参数（经临时脚本几何校验：3~12 个遗址 + 0~5 个推荐均无重叠/飞出） */
const IDEAL_DISTANCE: number = 44;
const ITERATIONS: number = 260;
const TEMP_START: number = 40;
const MAX_REPULSION: number = 90;
const GRAVITY: number = 0.26;
const COLLIDE_PAD: number = 10;
const CONTAINS_REST: number = 105;
const CONTAINS_STRENGTH: number = 0.12;
const RECOMMEND_REST: number = 72;
const RECOMMEND_STRENGTH: number = 0.50;
const AFFINITY_REST: number = 105;
const AFFINITY_STRENGTH: number = 0.08;

/** 视口边距（vp） */
const FIT_PADDING: number = 16;
const MIN_SCALE: number = 0.45;
const MAX_SCALE: number = 1.35;

/** 同类关联候选（排序后按度数贪心取边） */
interface AffinityCandidate {
  source: GraphNode;
  target: GraphNode;
  weight: number;
}

/** 图内容包围盒（世界坐标） */
export interface GraphBounds {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

/** 视口变换：屏幕 = 世界 * scale + offset */
export interface GraphTransform {
  scale: number;
  offsetX: number;
  offsetY: number;
}

/** 数值钳制 */
function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

/** 字符串稳定散列（用于确定性微扰，避免完全对称导致力抵消） */
function hashText(text: string): number {
  let hash: number = 0;
  for (let i = 0; i < text.length; i++) {
    hash = (hash * 31 + text.charCodeAt(i)) % 1000003;
  }
  return hash;
}

/** 由 key 生成 [-8, 8] 的确定性微扰 */
function jitterOf(key: string): number {
  return ((hashText(key) % 1000) / 1000 - 0.5) * 16;
}

/** 两遗址的共享特征分：同年代 1 + 同城市 1 + 同类型 0.5（满值 2.5） */
function sharedScore(aEra: string, aCity: string, aType: string,
  bEra: string, bCity: string, bType: string): number {
  let score: number = 0;
  if (aEra !== '' && aEra === bEra) {
    score += 1;
  }
  if (aCity !== '' && aCity === bCity) {
    score += 1;
  }
  if (aType !== '' && aType === bType) {
    score += 0.5;
  }
  return score;
}

/** 为推荐条目找最相似的已归类遗址下标（全 0 分时取第一条，保证有锚点） */
function bestAnchorIndex(item: Heritage, heritages: Heritage[]): number {
  let bestIndex: number = 0;
  let bestScore: number = -1;
  for (let i = 0; i < heritages.length; i++) {
    const score: number = sharedScore(item.era, item.city, item.type,
      heritages[i].era, heritages[i].city, heritages[i].type);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/**
 * 推荐条目的最佳锚点遗址。
 * 与 layoutGraph 的虚线锚点同源（同一 bestAnchorIndex 规则），
 * 页面信息卡据此解释「为什么推荐」，保证文案与图上关系一致。
 */
export function findBestAnchor(item: Heritage, heritages: Heritage[]): Heritage | null {
  if (heritages.length === 0) {
    return null;
  }
  return heritages[bestAnchorIndex(item, heritages)];
}

/** 推荐依据文案：与锚点共享的年代/城市/类型；无共享特征时说明为知识库补充推荐 */
export function buildRecommendReason(item: Heritage, anchor: Heritage): string {
  const traits: string[] = [];
  if (item.era === anchor.era) {
    traits.push(`同年代（${item.era}）`);
  }
  if (item.city === anchor.city) {
    traits.push(`同城市（${item.city}）`);
  }
  if (item.type === anchor.type) {
    traits.push(`同类型（${item.type}）`);
  }
  if (traits.length === 0) {
    return `与「${anchor.name}」暂无强关联特征，作为知识库补充推荐`;
  }
  return `与「${anchor.name}」${traits.join('、')}，故作为拓展推荐`;
}

/** 创建主题节点（连接度由后续边统计写入，不在创建时预置） */
function makeThemeNode(theme: Theme): GraphNode {
  const color: string = getThemeColor(theme.colorIndex);
  const node: GraphNode = {
    key: `theme:${theme.id}`,
    itemId: theme.id,
    label: theme.name,
    kind: GraphNodeKind.THEME,
    era: '',
    city: '',
    type: '',
    summary: '',
    fill: color,
    stroke: color,
    radius: THEME_RADIUS,
    degree: 0,
    x: 0,
    y: 0,
    pinned: true
  };
  return node;
}

/** 创建已归类遗址节点 */
function makeHeritageNode(heritage: Heritage): GraphNode {
  const eraTheme = getEraTheme(heritage.era);
  const node: GraphNode = {
    key: `h:${heritage.id}`,
    itemId: heritage.id,
    label: heritage.name,
    kind: GraphNodeKind.HERITAGE,
    era: heritage.era,
    city: heritage.city,
    type: heritage.type,
    summary: heritage.summary,
    fill: eraTheme.soft,
    stroke: eraTheme.deep,
    radius: HERITAGE_BASE_RADIUS,
    degree: 0,
    x: 0,
    y: 0,
    pinned: false
  };
  return node;
}

/** 创建拓展推荐节点（空心虚线样式由渲染层按 kind 决定） */
function makeRecommendNode(heritage: Heritage): GraphNode {
  const eraTheme = getEraTheme(heritage.era);
  const node: GraphNode = {
    key: `r:${heritage.id}`,
    itemId: heritage.id,
    label: heritage.name,
    kind: GraphNodeKind.RECOMMEND,
    era: heritage.era,
    city: heritage.city,
    type: heritage.type,
    summary: heritage.summary,
    fill: ThemeTokens.BG_CARD,
    stroke: eraTheme.deep,
    radius: RECOMMEND_RADIUS,
    degree: 0,
    x: 0,
    y: 0,
    pinned: false
  };
  return node;
}

/**
 * 构建图模型。
 *
 * 边语义：
 * - CONTAINS：主题 → 已归入遗址（实线，主关系）；
 * - AFFINITY：遗址 ↔ 遗址（同年代/同城市/同类型，细线，每个节点最多 3 条）；
 * - RECOMMEND：最相似遗址 → 拓展推荐（虚线，「因为相似所以推荐」）。
 * 推荐节点不直接连中心主题：挂在相似遗址旁更符合知识网络的语义，
 * 也避免推荐节点被斥力推到画布边缘（C1.4 视觉重构决策）。
 */
export function buildGraphModel(theme: Theme | null, heritages: Heritage[],
  recommendations: Heritage[], showAffinity: boolean, showRecommend: boolean): GraphModel {
  const nodes: GraphNode[] = [];
  const edges: GraphEdge[] = [];
  if (theme === null) {
    const empty: GraphModel = { nodes: nodes, edges: edges };
    return empty;
  }

  const themeNode: GraphNode = makeThemeNode(theme);
  nodes.push(themeNode);

  // 已归类遗址 + 归入边
  const heritageNodes: GraphNode[] = [];
  for (let i = 0; i < heritages.length; i++) {
    const node: GraphNode = makeHeritageNode(heritages[i]);
    heritageNodes.push(node);
    nodes.push(node);
    const edge: GraphEdge = {
      sourceKey: themeNode.key,
      targetKey: node.key,
      kind: GraphEdgeKind.CONTAINS,
      weight: 1
    };
    edges.push(edge);
  }

  // 同类关联：先收集候选，按权重降序后按节点度数贪心取边（防毛球）
  if (showAffinity && heritages.length > 1) {
    const candidates: AffinityCandidate[] = [];
    for (let i = 0; i < heritages.length; i++) {
      for (let j = i + 1; j < heritages.length; j++) {
        const score: number = sharedScore(heritages[i].era, heritages[i].city, heritages[i].type,
          heritages[j].era, heritages[j].city, heritages[j].type);
        // 仅「同年代 / 同城市」视为有效文化关联；仅同类型过弱，不画
        if (score >= 1) {
          const candidate: AffinityCandidate = {
            source: heritageNodes[i],
            target: heritageNodes[j],
            weight: clamp(score / 2.5, 0.2, 1)
          };
          candidates.push(candidate);
        }
      }
    }
    candidates.sort((a: AffinityCandidate, b: AffinityCandidate): number => {
      if (a.weight !== b.weight) {
        return b.weight - a.weight;
      }
      const ai: string = a.source.key + a.target.key;
      const bi: string = b.source.key + b.target.key;
      return ai < bi ? -1 : (ai > bi ? 1 : 0);
    });
    const degreeMap: Map<string, number> = new Map();
    for (let i = 0; i < candidates.length; i++) {
      const sourceDegree: number = degreeMap.get(candidates[i].source.key) ?? 0;
      const targetDegree: number = degreeMap.get(candidates[i].target.key) ?? 0;
      if (sourceDegree >= MAX_AFFINITY_PER_NODE || targetDegree >= MAX_AFFINITY_PER_NODE) {
        continue;
      }
      const edge: GraphEdge = {
        sourceKey: candidates[i].source.key,
        targetKey: candidates[i].target.key,
        kind: GraphEdgeKind.AFFINITY,
        weight: candidates[i].weight
      };
      edges.push(edge);
      degreeMap.set(candidates[i].source.key, sourceDegree + 1);
      degreeMap.set(candidates[i].target.key, targetDegree + 1);
    }
  }

  // 拓展推荐：挂在最相似的已归类遗址旁
  if (showRecommend && recommendations.length > 0 && heritageNodes.length > 0) {
    for (let i = 0; i < recommendations.length; i++) {
      const node: GraphNode = makeRecommendNode(recommendations[i]);
      nodes.push(node);
      const anchor: GraphNode = heritageNodes[bestAnchorIndex(recommendations[i], heritages)];
      const edge: GraphEdge = {
        sourceKey: anchor.key,
        targetKey: node.key,
        kind: GraphEdgeKind.RECOMMEND,
        weight: 1
      };
      edges.push(edge);
    }
  }

  // 连接度统计：决定遗址节点大小（Obsidian 节点尺寸编码）
  for (let i = 0; i < edges.length; i++) {
    const source: GraphNode | null = findNodeByKey(nodes, edges[i].sourceKey);
    const target: GraphNode | null = findNodeByKey(nodes, edges[i].targetKey);
    if (source !== null) {
      source.degree += 1;
    }
    if (target !== null) {
      target.degree += 1;
    }
  }
  for (let i = 0; i < nodes.length; i++) {
    if (nodes[i].kind === GraphNodeKind.HERITAGE) {
      const extra: number = Math.min(5, Math.max(0, nodes[i].degree - 1));
      nodes[i].radius = HERITAGE_BASE_RADIUS + extra * 1.5;
    }
  }

  const model: GraphModel = { nodes: nodes, edges: edges };
  return model;
}

/** 按 key 查节点（图规模很小，线性查找足够且无需维护额外索引） */
export function findNodeByKey(nodes: GraphNode[], key: string): GraphNode | null {
  for (let i = 0; i < nodes.length; i++) {
    if (nodes[i].key === key) {
      return nodes[i];
    }
  }
  return null;
}

/**
 * 力导向布局（确定性）：
 * 初次位置 = 主题中心 + 遗址圆环 + 推荐挂在锚点旁；
 * 迭代 = 两两斥力 + 边弹簧 + 向心约束 + 温度钳制；
 * 收尾 = 多轮碰撞消解，保证节点圆与标签互不压盖。
 */
export function layoutGraph(model: GraphModel): void {
  const nodes: GraphNode[] = model.nodes;
  const edges: GraphEdge[] = model.edges;
  if (nodes.length === 0) {
    return;
  }

  // 1) 初始位置
  let heritageCount: number = 0;
  for (let i = 0; i < nodes.length; i++) {
    if (nodes[i].kind === GraphNodeKind.HERITAGE) {
      heritageCount += 1;
    }
  }
  let heritageIndex: number = 0;
  const recSlotMap: Map<string, number> = new Map();
  const anchorKeyMap: Map<string, string> = new Map();
  for (let i = 0; i < edges.length; i++) {
    if (edges[i].kind === GraphEdgeKind.RECOMMEND) {
      anchorKeyMap.set(edges[i].targetKey, edges[i].sourceKey);
    }
  }
  for (let i = 0; i < nodes.length; i++) {
    const node: GraphNode = nodes[i];
    if (node.kind === GraphNodeKind.THEME) {
      node.x = 0;
      node.y = 0;
      continue;
    }
    if (node.kind === GraphNodeKind.HERITAGE) {
      const angle: number = -Math.PI / 2 + (heritageIndex / Math.max(1, heritageCount)) * Math.PI * 2;
      node.x = Math.cos(angle) * 90 + jitterOf(node.key);
      node.y = Math.sin(angle) * 90 + jitterOf(`${node.key}:y`);
      heritageIndex += 1;
      continue;
    }
    // 推荐：围绕锚点外侧展开，同一锚点的多个推荐扇形分布
    const anchorKey: string | undefined = anchorKeyMap.get(node.key);
    const anchor: GraphNode | null = anchorKey === undefined ? null : findNodeByKey(nodes, anchorKey);
    if (anchor !== null && anchorKey !== undefined) {
      const slot: number = recSlotMap.get(anchorKey) ?? 0;
      recSlotMap.set(anchorKey, slot + 1);
      const baseAngle: number = Math.atan2(anchor.y, anchor.x);
      const angle: number = baseAngle + (slot - 1) * 0.7;
      node.x = anchor.x + Math.cos(angle) * (64 + slot * 4);
      node.y = anchor.y + Math.sin(angle) * (64 + slot * 4);
    } else {
      node.x = jitterOf(node.key);
      node.y = 150 + jitterOf(`${node.key}:y`);
    }
  }

  // 2) 力导向迭代
  const indexMap: Map<string, number> = new Map();
  for (let i = 0; i < nodes.length; i++) {
    indexMap.set(nodes[i].key, i);
  }
  const dispX: number[] = [];
  const dispY: number[] = [];
  for (let i = 0; i < nodes.length; i++) {
    dispX.push(0);
    dispY.push(0);
  }
  for (let iteration = 0; iteration < ITERATIONS; iteration++) {
    const temperature: number = TEMP_START * (1 - iteration / ITERATIONS) + 0.6;
    for (let i = 0; i < nodes.length; i++) {
      dispX[i] = 0;
      dispY[i] = 0;
    }
    // 斥力：所有节点两两相斥（带上限，避免近距离爆散）
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        let dx: number = nodes[i].x - nodes[j].x;
        let dy: number = nodes[i].y - nodes[j].y;
        let distanceSquared: number = dx * dx + dy * dy;
        if (distanceSquared < 1) {
          distanceSquared = 1;
          dx = (i - j) * 0.1;
          dy = 0.1;
        }
        const distance: number = Math.sqrt(distanceSquared);
        const force: number = Math.min(IDEAL_DISTANCE * IDEAL_DISTANCE / distance, MAX_REPULSION);
        const unitX: number = dx / distance;
        const unitY: number = dy / distance;
        dispX[i] += unitX * force;
        dispY[i] += unitY * force;
        dispX[j] -= unitX * force;
        dispY[j] -= unitY * force;
      }
    }
    // 弹簧：不同边类型有不同自然长度与劲度
    for (let e = 0; e < edges.length; e++) {
      const sourceIndex: number | undefined = indexMap.get(edges[e].sourceKey);
      const targetIndex: number | undefined = indexMap.get(edges[e].targetKey);
      if (sourceIndex === undefined || targetIndex === undefined) {
        continue;
      }
      let dx: number = nodes[sourceIndex].x - nodes[targetIndex].x;
      let dy: number = nodes[sourceIndex].y - nodes[targetIndex].y;
      let distance: number = Math.sqrt(dx * dx + dy * dy);
      if (distance < 0.01) {
        distance = 0.01;
        dx = 0.1;
        dy = 0.1;
      }
      let restLength: number = CONTAINS_REST;
      let strength: number = CONTAINS_STRENGTH;
      if (edges[e].kind === GraphEdgeKind.RECOMMEND) {
        restLength = RECOMMEND_REST;
        strength = RECOMMEND_STRENGTH;
      } else if (edges[e].kind === GraphEdgeKind.AFFINITY) {
        restLength = AFFINITY_REST - 24 * edges[e].weight;
        strength = AFFINITY_STRENGTH;
      }
      const force: number = (distance - restLength) * strength;
      const unitX: number = dx / distance;
      const unitY: number = dy / distance;
      dispX[sourceIndex] -= unitX * force;
      dispY[sourceIndex] -= unitY * force;
      dispX[targetIndex] += unitX * force;
      dispY[targetIndex] += unitY * force;
    }
    // 向心约束：保持图形紧凑（视口适配后节点不至于过小）
    for (let i = 0; i < nodes.length; i++) {
      if (nodes[i].pinned) {
        continue;
      }
      dispX[i] -= nodes[i].x * GRAVITY;
      dispY[i] -= nodes[i].y * GRAVITY;
    }
    // 温度钳制位移（收敛稳定）
    for (let i = 0; i < nodes.length; i++) {
      if (nodes[i].pinned) {
        nodes[i].x = 0;
        nodes[i].y = 0;
        continue;
      }
      const length: number = Math.sqrt(dispX[i] * dispX[i] + dispY[i] * dispY[i]);
      if (length < 0.0001) {
        continue;
      }
      const move: number = Math.min(length, temperature);
      nodes[i].x += (dispX[i] / length) * move;
      nodes[i].y += (dispY[i] / length) * move;
    }
  }

  // 3) 碰撞消解：站点圆之间至少留 COLLIDE_PAD；固定节点不被推动
  for (let pass: number = 0; pass < 5; pass++) {
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        const source: GraphNode = nodes[i];
        const target: GraphNode = nodes[j];
        let dx: number = target.x - source.x;
        let dy: number = target.y - source.y;
        let distance: number = Math.sqrt(dx * dx + dy * dy);
        const minDistance: number = source.radius + target.radius + COLLIDE_PAD;
        if (distance < 0.01) {
          dx = 0.1;
          dy = 0.1;
          distance = 0.14;
        }
        if (distance >= minDistance) {
          continue;
        }
        const push: number = (minDistance - distance) * 0.5;
        const unitX: number = dx / distance;
        const unitY: number = dy / distance;
        if (source.pinned && !target.pinned) {
          target.x += unitX * push * 2;
          target.y += unitY * push * 2;
        } else if (target.pinned && !source.pinned) {
          source.x -= unitX * push * 2;
          source.y -= unitY * push * 2;
        } else if (!source.pinned && !target.pinned) {
          source.x -= unitX * push;
          source.y -= unitY * push;
          target.x += unitX * push;
          target.y += unitY * push;
        }
      }
    }
  }
}

/** 计算图内容包围盒（含节点半径与下方标签预留） */
export function computeBounds(model: GraphModel): GraphBounds {
  if (model.nodes.length === 0) {
    const empty: GraphBounds = { minX: 0, maxX: 0, minY: 0, maxY: 0 };
    return empty;
  }
  let minX: number = Number.MAX_VALUE;
  let maxX: number = -Number.MAX_VALUE;
  let minY: number = Number.MAX_VALUE;
  let maxY: number = -Number.MAX_VALUE;
  for (let i = 0; i < model.nodes.length; i++) {
    const node: GraphNode = model.nodes[i];
    const labelPad: number = node.kind === GraphNodeKind.THEME ? 4 : LABEL_SPACE;
    // 标签画在屏幕坐标、字号固定，横向按最大标签宽度预留，避免贴边截断
    const halfWidth: number = node.kind === GraphNodeKind.THEME
      ? node.radius + 4
      : Math.max(node.radius + 4, LABEL_HALF_WIDTH);
    minX = Math.min(minX, node.x - halfWidth);
    maxX = Math.max(maxX, node.x + halfWidth);
    minY = Math.min(minY, node.y - node.radius - 4);
    maxY = Math.max(maxY, node.y + node.radius + labelPad);
  }
  const bounds: GraphBounds = { minX: minX, maxX: maxX, minY: minY, maxY: maxY };
  return bounds;
}

/** 视口适配：内容居中并按画布宽高取最小缩放（限制在 [0.45, 1.35]） */
export function computeFitTransform(model: GraphModel, width: number, height: number): GraphTransform {
  const bounds: GraphBounds = computeBounds(model);
  const contentWidth: number = bounds.maxX - bounds.minX;
  const contentHeight: number = bounds.maxY - bounds.minY;
  if (width <= 0 || height <= 0 || contentWidth <= 0 || contentHeight <= 0) {
    const fallback: GraphTransform = { scale: 1, offsetX: width / 2, offsetY: height / 2 };
    return fallback;
  }
  const scale: number = clamp(Math.min((width - FIT_PADDING * 2) / contentWidth,
    (height - FIT_PADDING * 2) / contentHeight), MIN_SCALE, MAX_SCALE);
  const centerX: number = (bounds.minX + bounds.maxX) / 2;
  const centerY: number = (bounds.minY + bounds.maxY) / 2;
  const transform: GraphTransform = {
    scale: scale,
    offsetX: width / 2 - centerX * scale,
    offsetY: height / 2 - centerY * scale
  };
  return transform;
}
