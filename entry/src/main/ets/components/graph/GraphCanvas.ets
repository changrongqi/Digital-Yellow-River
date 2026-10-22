/**
 * 知识图谱 Canvas 渲染与交互组件（C1.4 重构）
 *
 * 设计参考：
 * - relation-graph：核心图数据 / 布局 / 渲染分离，渲染层只做「世界坐标 → 屏幕坐标」变换，
 *   并提供平移、缩放、命中测试与视图复位；
 * - Trilium Notes Note Map：中心根节点 + 周围关系节点，点击节点进入对应内容，相邻节点高亮；
 * - Obsidian Graph View：点按选中后邻接边/节点高亮、其余淡出；标签做碰撞避让，
 *   按「选中 > 邻接 > 连接度」优先级逐条放置，避免小画布上文字互相压盖。
 *
 * 交互（手势仲裁由 ArkUI 统一处理，Canvas 子手势优先于外层 Scroll）：
 * - 单指点按节点 = 选中并交给页面展示信息卡；点按空白 = 取消选中；
 * - 单指拖动空白 = 平移视图；单指拖动节点 = 移动节点（本次会话内保持）；
 * - 双指捏合 = 以捏合中心缩放；右上角 ＋ / － / ⟲ = 缩放与视图复位。
 *
 * 注意：Canvas 不会因 @Prop 变化自动重绘，所有数据/选中变化均经 @Watch 触发重绘（O9 修复）。
 */

import { Theme } from '../../model/Theme';
import { Heritage } from '../../model/Heritage';
import { GraphNode, GraphEdge, GraphModel, GraphNodeKind, GraphEdgeKind } from './GraphNode';
import {
  GraphBounds,
  GraphTransform,
  buildGraphModel,
  layoutGraph,
  computeBounds,
  computeFitTransform,
  findNodeByKey
} from './GraphLayout';

/** 用户缩放范围（视口初始适配范围更窄，见 GraphLayout） */
const MIN_USER_SCALE: number = 0.45;
const MAX_USER_SCALE: number = 2.6;
/** 标签字号（屏幕坐标 vp，不随缩放变小） */
const LABEL_FONT_SIZE: number = 11;
/** 画布底色（比页面米白更亮一档，衬出节点） */
const CANVAS_BACKGROUND: string = '#FDFBF8';

/** 标签绘制候选（排序后逐个尝试放置） */
interface LabelCandidate {
  node: GraphNode;
  priority: number; // 0=选中 1=邻接 2=其余
  alpha: number;
}

/** 屏幕坐标占位矩形（节点圆或已放置标签） */
interface LabelBox {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

@Component
export struct GraphCanvas {
  // ==================== 数据输入（@Watch 保证 Canvas 随数据重绘） ====================
  @Prop @Watch('onDataChanged') theme: Theme | null = null;
  @Prop @Watch('onDataChanged') heritages: Heritage[] = [];
  @Prop @Watch('onDataChanged') recommendations: Heritage[] = [];
  @Prop @Watch('onDataChanged') showAffinity: boolean = true;
  @Prop @Watch('onDataChanged') showRecommend: boolean = false;
  @Prop @Watch('onDataChanged') graphVersion: number = 0;
  @Prop @Watch('onSelectionChanged') selectedId: string = '';

  /** 节点选中回调（itemId = 主题 id 或遗址 id；kind = NONE 表示取消选中） */
  onSelect: (itemId: string, kind: GraphNodeKind) => void = () => {};

  // ==================== 渲染状态 ====================
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private model: GraphModel = { nodes: [], edges: [] };
  private bounds: GraphBounds = { minX: 0, maxX: 0, minY: 0, maxY: 0 };
  /** 视图缩放（避开 CustomComponent 内置 scale 属性名） */
  private viewScale: number = 1;
  private offsetX: number = 0;
  private offsetY: number = 0;
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private ready: boolean = false;
  /** 上次布局的数据签名：内容未变时只重绘，不重置用户缩放/平移/拖动 */
  private lastDataSignature: string = '';

  // ==================== 手势状态 ====================
  private isPinching: boolean = false;
  private panBaseOffsetX: number = 0;
  private panBaseOffsetY: number = 0;
  private draggingNode: GraphNode | null = null;
  private dragBaseX: number = 0;
  private dragBaseY: number = 0;
  private pinchBaseScale: number = 1;
  private pinchBaseOffsetX: number = 0;
  private pinchBaseOffsetY: number = 0;
  private pinchStartCenterX: number = 0;
  private pinchStartCenterY: number = 0;

  // ==================== 生命周期与数据刷新 ====================

  private onDataChanged(): void {
    if (!this.ready) {
      return;
    }
    const signature: string = this.dataSignature();
    if (signature === this.lastDataSignature) {
      // 数据内容未变（如页面刷新 tick）：保留用户当前视口与节点位置，仅重绘
      this.drawGraph();
      return;
    }
    this.lastDataSignature = signature;
    this.relayout();
  }

  /** 数据签名：主题信息 + 节点 id 序列 + 图层开关 */
  private dataSignature(): string {
    const themeId: string = this.theme === null ? '' : this.theme.id;
    const themeName: string = this.theme === null ? '' : this.theme.name;
    const themeColor: string = this.theme === null ? '' : String(this.theme.colorIndex);
    let signature: string = `${themeId}|${themeName}|${themeColor}|${this.showAffinity}|${this.showRecommend}`;
    for (let i = 0; i < this.heritages.length; i++) {
      signature += `|h:${this.heritages[i].id}`;
    }
    for (let i = 0; i < this.recommendations.length; i++) {
      signature += `|r:${this.recommendations[i].id}`;
    }
    return signature;
  }

  private onSelectionChanged(): void {
    if (!this.ready) {
      return;
    }
    this.drawGraph();
  }

  private onCanvasReady(): void {
    this.canvasWidth = this.context.width;
    this.canvasHeight = this.context.height;
    this.ready = true;
    this.relayout();
  }

  /** 区域变化：重新适配视口（世界坐标不变，不重新跑力导向） */
  private onCanvasResize(): void {
    if (!this.ready) {
      return;
    }
    const width: number = this.context.width;
    const height: number = this.context.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    const changed: boolean = Math.abs(width - this.canvasWidth) >= 0.5 ||
      Math.abs(height - this.canvasHeight) >= 0.5;
    this.canvasWidth = width;
    this.canvasHeight = height;
    if (!changed) {
      return;
    }
    if (this.model.nodes.length === 0) {
      this.relayout();
    } else {
      this.fitView();
    }
  }

  /** 重建图模型 → 力导向布局 → 适配视口 → 绘制 */
  private relayout(): void {
    if (this.canvasWidth <= 0 || this.canvasHeight <= 0) {
      return;
    }
    this.lastDataSignature = this.dataSignature();
    this.model = buildGraphModel(this.theme, this.heritages, this.recommendations,
      this.showAffinity, this.showRecommend);
    layoutGraph(this.model);
    this.bounds = computeBounds(this.model);
    this.fitView();
  }

  /** 视图适配并重绘 */
  private fitView(): void {
    const transform: GraphTransform = computeFitTransform(this.model, this.canvasWidth, this.canvasHeight);
    this.viewScale = transform.scale;
    this.offsetX = transform.offsetX;
    this.offsetY = transform.offsetY;
    this.clampViewport();
    this.drawGraph();
  }

  /** 限制平移范围：内容不能被完全拖出画布 */
  private clampViewport(): void {
    if (this.model.nodes.length === 0) {
      return;
    }
    const margin: number = 40;
    const minOffsetX: number = margin - this.bounds.maxX * this.viewScale;
    const maxOffsetX: number = this.canvasWidth - margin - this.bounds.minX * this.viewScale;
    if (minOffsetX > maxOffsetX) {
      this.offsetX = this.canvasWidth / 2 - (this.bounds.minX + this.bounds.maxX) / 2 * this.viewScale;
    } else {
      this.offsetX = this.clamp(this.offsetX, minOffsetX, maxOffsetX);
    }
    const minOffsetY: number = margin - this.bounds.maxY * this.viewScale;
    const maxOffsetY: number = this.canvasHeight - margin - this.bounds.minY * this.viewScale;
    if (minOffsetY > maxOffsetY) {
      this.offsetY = this.canvasHeight / 2 - (this.bounds.minY + this.bounds.maxY) / 2 * this.viewScale;
    } else {
      this.offsetY = this.clamp(this.offsetY, minOffsetY, maxOffsetY);
    }
  }

  // ==================== 手势 ====================

  private handleTap(event: GestureEvent): void {
    if (event.fingerList.length === 0) {
      return;
    }
    const fingerX: number = event.fingerList[0].localX;
    const fingerY: number = event.fingerList[0].localY;
    const node: GraphNode | null = this.hitTest(fingerX, fingerY);
    if (node === null) {
      this.onSelect('', GraphNodeKind.NONE);
    } else {
      this.onSelect(node.itemId, node.kind);
    }
  }

  private handlePanStart(event: GestureEvent): void {
    if (this.isPinching || event.fingerList.length === 0) {
      return;
    }
    const node: GraphNode | null = this.hitTest(event.fingerList[0].localX, event.fingerList[0].localY);
    if (node !== null && !node.pinned) {
      this.draggingNode = node;
      this.dragBaseX = node.x;
      this.dragBaseY = node.y;
    } else {
      this.draggingNode = null;
      this.panBaseOffsetX = this.offsetX;
      this.panBaseOffsetY = this.offsetY;
    }
  }

  private handlePanUpdate(event: GestureEvent): void {
    if (this.isPinching) {
      return;
    }
    if (this.draggingNode !== null) {
      this.draggingNode.x = this.dragBaseX + event.offsetX / this.viewScale;
      this.draggingNode.y = this.dragBaseY + event.offsetY / this.viewScale;
    } else {
      this.offsetX = this.panBaseOffsetX + event.offsetX;
      this.offsetY = this.panBaseOffsetY + event.offsetY;
      this.clampViewport();
    }
    this.drawGraph();
  }

  private handlePanEnd(): void {
    if (this.draggingNode !== null) {
      // 节点被手动移动后包围盒会变化：重算并收敛视口，避免节点被拖出可平移找回的范围
      this.bounds = computeBounds(this.model);
      this.clampViewport();
      this.drawGraph();
    }
    this.draggingNode = null;
  }

  private handlePinchStart(event: GestureEvent): void {
    this.isPinching = true;
    this.draggingNode = null;
    this.pinchBaseScale = this.viewScale;
    this.pinchBaseOffsetX = this.offsetX;
    this.pinchBaseOffsetY = this.offsetY;
    this.pinchStartCenterX = event.pinchCenterX;
    this.pinchStartCenterY = event.pinchCenterY;
  }

  private handlePinchUpdate(event: GestureEvent): void {
    if (!this.isPinching || this.pinchBaseScale <= 0) {
      return;
    }
    const nextScale: number = this.clamp(this.pinchBaseScale * event.scale,
      MIN_USER_SCALE, MAX_USER_SCALE);
    // 保持捏合起点下的世界坐标不动，同时跟随捏合中心平移
    const worldX: number = (this.pinchStartCenterX - this.pinchBaseOffsetX) / this.pinchBaseScale;
    const worldY: number = (this.pinchStartCenterY - this.pinchBaseOffsetY) / this.pinchBaseScale;
    this.viewScale = nextScale;
    this.offsetX = event.pinchCenterX - worldX * nextScale;
    this.offsetY = event.pinchCenterY - worldY * nextScale;
    this.clampViewport();
    this.drawGraph();
  }

  private handlePinchEnd(): void {
    this.isPinching = false;
  }

  /** 以画布中心缩放（右上角 ＋/－ 按钮） */
  private zoomBy(factor: number): void {
    const centerX: number = this.canvasWidth / 2;
    const centerY: number = this.canvasHeight / 2;
    const nextScale: number = this.clamp(this.viewScale * factor, MIN_USER_SCALE, MAX_USER_SCALE);
    if (nextScale === this.viewScale) {
      return;
    }
    const worldX: number = (centerX - this.offsetX) / this.viewScale;
    const worldY: number = (centerY - this.offsetY) / this.viewScale;
    this.viewScale = nextScale;
    this.offsetX = centerX - worldX * nextScale;
    this.offsetY = centerY - worldY * nextScale;
    this.clampViewport();
    this.drawGraph();
  }

  /** 屏幕坐标命中测试（世界坐标距离，触控容差随缩放补偿） */
  private hitTest(screenX: number, screenY: number): GraphNode | null {
    if (this.viewScale <= 0) {
      return null;
    }
    const worldX: number = (screenX - this.offsetX) / this.viewScale;
    const worldY: number = (screenY - this.offsetY) / this.viewScale;
    for (let i = this.model.nodes.length - 1; i >= 0; i--) {
      const node: GraphNode = this.model.nodes[i];
      const dx: number = worldX - node.x;
      const dy: number = worldY - node.y;
      const tolerance: number = Math.max(node.radius + 8, 22 / this.viewScale);
      if (Math.sqrt(dx * dx + dy * dy) <= tolerance) {
        return node;
      }
    }
    return null;
  }

  // ==================== 绘制 ====================

  private drawGraph(): void {
    const width: number = this.canvasWidth;
    const height: number = this.canvasHeight;
    if (width <= 0 || height <= 0) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.context;
    // 不填充背景：保留父容器的圆角与底色（Canvas 填充会盖住卡片圆角）
    ctx.clearRect(0, 0, width, height);
    if (this.model.nodes.length === 0) {
      return;
    }

    const selected: GraphNode | null = this.findSelectedNode();
    const neighbors: Map<string, boolean> = this.collectNeighborKeys(selected);

    ctx.save();
    ctx.translate(this.offsetX, this.offsetY);
    ctx.scale(this.viewScale, this.viewScale);

    // 先画边（亲和线在下、主干关系在上）
    for (let i = 0; i < this.model.edges.length; i++) {
      if (this.model.edges[i].kind === GraphEdgeKind.AFFINITY) {
        this.drawEdge(ctx, this.model.edges[i], selected);
      }
    }
    for (let i = 0; i < this.model.edges.length; i++) {
      if (this.model.edges[i].kind !== GraphEdgeKind.AFFINITY) {
        this.drawEdge(ctx, this.model.edges[i], selected);
      }
    }

    // 再画节点
    for (let i = 0; i < this.model.nodes.length; i++) {
      this.drawNode(ctx, this.model.nodes[i], selected, neighbors);
    }
    ctx.restore();

    // 文字统一画在屏幕坐标系：字号不随缩放变小，并做碰撞避让
    this.drawThemeLabel(ctx, selected, neighbors);
    this.drawNodeLabels(ctx, selected, neighbors);
    this.drawEmptyHint(ctx);
  }

  private findSelectedNode(): GraphNode | null {
    if (this.selectedId === '') {
      return null;
    }
    for (let i = 0; i < this.model.nodes.length; i++) {
      if (this.model.nodes[i].itemId === this.selectedId) {
        return this.model.nodes[i];
      }
    }
    return null;
  }

  private collectNeighborKeys(selected: GraphNode | null): Map<string, boolean> {
    const neighbors: Map<string, boolean> = new Map();
    if (selected === null) {
      return neighbors;
    }
    for (let i = 0; i < this.model.edges.length; i++) {
      const edge = this.model.edges[i];
      if (edge.sourceKey === selected.key) {
        neighbors.set(edge.targetKey, true);
      } else if (edge.targetKey === selected.key) {
        neighbors.set(edge.sourceKey, true);
      }
    }
    return neighbors;
  }

  private drawEdge(ctx: CanvasRenderingContext2D, edge: GraphEdge, selected: GraphNode | null): void {
    const source: GraphNode | null = findNodeByKey(this.model.nodes, edge.sourceKey);
    const target: GraphNode | null = findNodeByKey(this.model.nodes, edge.targetKey);
    if (source === null || target === null) {
      return;
    }
    const incident: boolean = selected !== null &&
      (edge.sourceKey === selected.key || edge.targetKey === selected.key);

    // 透明度：选中时非邻接边退后，未选中时按边类型分级
    let alpha: number = 1;
    if (selected !== null) {
      alpha = incident ? 0.95 : 0.10;
    } else if (edge.kind === GraphEdgeKind.AFFINITY) {
      alpha = 0.16 + 0.22 * edge.weight;
    } else if (edge.kind === GraphEdgeKind.RECOMMEND) {
      alpha = 0.50;
    } else {
      alpha = 0.34;
    }
    ctx.globalAlpha = alpha;

    if (edge.kind === GraphEdgeKind.AFFINITY) {
      // 同类关联：二次曲线，避免与归入边重叠成毛球
      const midX: number = (source.x + target.x) / 2;
      const midY: number = (source.y + target.y) / 2;
      const dx: number = target.x - source.x;
      const dy: number = target.y - source.y;
      const length: number = Math.max(1, Math.sqrt(dx * dx + dy * dy));
      const normalX: number = -dy / length;
      const normalY: number = dx / length;
      const bend: number = Math.min(18, length * 0.12) * (edge.weight >= 0.6 ? 1 : 0.7);
      ctx.beginPath();
      ctx.moveTo(source.x, source.y);
      ctx.quadraticCurveTo(midX + normalX * bend, midY + normalY * bend, target.x, target.y);
      ctx.strokeStyle = '#A1887F';
      ctx.lineWidth = 0.8 + 0.8 * edge.weight;
      ctx.stroke();
    } else {
      // 归入 / 拓展：直线，端点裁到圆边
      const dx: number = target.x - source.x;
      const dy: number = target.y - source.y;
      const length: number = Math.sqrt(dx * dx + dy * dy);
      if (length < 1) {
        return;
      }
      const unitX: number = dx / length;
      const unitY: number = dy / length;
      const startX: number = source.x + unitX * (source.radius + 2);
      const startY: number = source.y + unitY * (source.radius + 2);
      const endX: number = target.x - unitX * (target.radius + 2);
      const endY: number = target.y - unitY * (target.radius + 2);
      if (edge.kind === GraphEdgeKind.RECOMMEND) {
        ctx.setLineDash([5, 4]);
        ctx.strokeStyle = '#B08D7A';
        ctx.lineWidth = 1.2;
      } else {
        ctx.strokeStyle = source.fill;
        ctx.lineWidth = 1.6;
      }
      ctx.beginPath();
      ctx.moveTo(startX, startY);
      ctx.lineTo(endX, endY);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    ctx.globalAlpha = 1;
  }

  private drawNode(ctx: CanvasRenderingContext2D, node: GraphNode,
    selected: GraphNode | null, neighbors: Map<string, boolean>): void {
    let alpha: number = 1;
    if (selected !== null) {
      const isSelf: boolean = node.key === selected.key;
      const isNeighbor: boolean = neighbors.get(node.key) === true;
      alpha = isSelf || isNeighbor ? 1 : 0.28;
    }
    ctx.globalAlpha = alpha;

    ctx.beginPath();
    ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
    if (node.kind === GraphNodeKind.THEME) {
      ctx.fillStyle = node.fill;
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 2.5;
      ctx.stroke();
    } else if (node.kind === GraphNodeKind.RECOMMEND) {
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
      ctx.setLineDash([4, 3]);
      ctx.strokeStyle = node.stroke;
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.setLineDash([]);
      // 中心小点：强调「候选 / 未归入」
      ctx.beginPath();
      ctx.arc(node.x, node.y, 2.4, 0, Math.PI * 2);
      ctx.fillStyle = node.stroke;
      ctx.fill();
    } else {
      ctx.fillStyle = node.fill;
      ctx.fill();
      ctx.strokeStyle = node.stroke;
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // 选中描边环
    if (selected !== null && node.key === selected.key) {
      ctx.beginPath();
      ctx.arc(node.x, node.y, node.radius + 4, 0, Math.PI * 2);
      ctx.strokeStyle = node.stroke;
      ctx.lineWidth = 1.6;
      ctx.globalAlpha = alpha * 0.9;
      ctx.stroke();
      ctx.globalAlpha = alpha;
    }

    ctx.globalAlpha = 1;
  }

  /** 中心主题文字：屏幕坐标固定字号（缩放只改变圆的大小，不影响可读性） */
  private drawThemeLabel(ctx: CanvasRenderingContext2D, selected: GraphNode | null,
    neighbors: Map<string, boolean>): void {
    const themeNode: GraphNode | null = this.findThemeNode();
    if (themeNode === null) {
      return;
    }
    const screenX: number = themeNode.x * this.viewScale + this.offsetX;
    const screenY: number = themeNode.y * this.viewScale + this.offsetY;
    const screenRadius: number = themeNode.radius * this.viewScale;
    if (screenRadius < 8) {
      return;
    }
    let alpha: number = 1;
    if (selected !== null) {
      const isSelf: boolean = themeNode.key === selected.key;
      const isNeighbor: boolean = neighbors.get(themeNode.key) === true;
      alpha = isSelf || isNeighbor ? 1 : 0.28;
    }
    ctx.globalAlpha = alpha;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';
    const count: number = this.countHeritageNodes();
    const hasCount: boolean = count > 0;
    const titleSize: number = this.clamp(screenRadius * 0.36, 9, 16);
    ctx.font = `${titleSize}vp sans-serif`;
    const name: string = this.fitLabelByWidth(ctx, themeNode.label,
      Math.max(18, screenRadius * 1.55));
    ctx.fillText(name, screenX, screenY + (hasCount ? -screenRadius * 0.16 : 0));
    if (hasCount) {
      ctx.font = `${this.clamp(screenRadius * 0.23, 7, 11)}vp sans-serif`;
      ctx.globalAlpha = alpha * 0.82;
      ctx.fillText(`${count} 处`, screenX, screenY + screenRadius * 0.48);
    }
    ctx.globalAlpha = 1;
  }

  /**
   * 遗址/推荐标签：屏幕坐标固定字号 + 碰撞避让。
   * 先按「选中 > 邻接 > 连接度」排序，再逐条放入空位；放不下就跳过该条，
   * 而不是在低缩放时把所有标签整体隐藏（C1.5）。
   */
  private drawNodeLabels(ctx: CanvasRenderingContext2D, selected: GraphNode | null,
    neighbors: Map<string, boolean>): void {
    // 节点圆先占位：普通标签不得压住任何节点
    const circles: LabelBox[] = [];
    for (let i = 0; i < this.model.nodes.length; i++) {
      const node: GraphNode = this.model.nodes[i];
      const screenX: number = node.x * this.viewScale + this.offsetX;
      const screenY: number = node.y * this.viewScale + this.offsetY;
      const screenRadius: number = node.radius * this.viewScale;
      const circle: LabelBox = {
        left: screenX - screenRadius - 2,
        top: screenY - screenRadius - 2,
        right: screenX + screenRadius + 2,
        bottom: screenY + screenRadius + 2
      };
      circles.push(circle);
    }

    const candidates: LabelCandidate[] = [];
    for (let i = 0; i < this.model.nodes.length; i++) {
      const node: GraphNode = this.model.nodes[i];
      if (node.kind === GraphNodeKind.THEME) {
        continue;
      }
      let priority: number = 2;
      let alpha: number = 1;
      if (selected !== null) {
        const isSelf: boolean = node.key === selected.key;
        const isNeighbor: boolean = neighbors.get(node.key) === true;
        alpha = isSelf || isNeighbor ? 1 : 0.28;
        priority = isSelf ? 0 : (isNeighbor ? 1 : 2);
      }
      const candidate: LabelCandidate = { node: node, priority: priority, alpha: alpha };
      candidates.push(candidate);
    }
    candidates.sort((a: LabelCandidate, b: LabelCandidate): number => {
      if (a.priority !== b.priority) {
        return a.priority - b.priority;
      }
      if (a.node.degree !== b.node.degree) {
        return b.node.degree - a.node.degree;
      }
      return a.node.key < b.node.key ? -1 : (a.node.key > b.node.key ? 1 : 0);
    });

    const placed: LabelBox[] = [];
    for (let i = 0; i < candidates.length; i++) {
      const candidate: LabelCandidate = candidates[i];
      const node: GraphNode = candidate.node;
      const screenX: number = node.x * this.viewScale + this.offsetX;
      const screenY: number = node.y * this.viewScale + this.offsetY;
      const screenRadius: number = node.radius * this.viewScale;
      if (screenRadius < 5) {
        continue;
      }
      ctx.font = `${LABEL_FONT_SIZE}vp sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      const maxWidth: number = Math.max(44, screenRadius * 3.4);
      const label: string = this.fitLabelByWidth(ctx, node.label, maxWidth);
      const labelWidth: number = ctx.measureText(label).width;
      // 贴边节点标签内收，避免被画布裁掉（文字仍尽量居中对齐节点）
      let drawX: number = screenX;
      if (labelWidth + 8 <= this.canvasWidth) {
        drawX = this.clamp(screenX, labelWidth / 2 + 4, this.canvasWidth - labelWidth / 2 - 4);
      } else {
        drawX = this.canvasWidth / 2;
      }
      const labelY: number = screenY + screenRadius + 4;
      const textBox: LabelBox = {
        left: drawX - labelWidth / 2 - 3,
        top: labelY - 2,
        right: drawX + labelWidth / 2 + 3,
        bottom: labelY + LABEL_FONT_SIZE + 3
      };
      if (textBox.right < 0 || textBox.left > this.canvasWidth ||
        textBox.bottom < 0 || textBox.top > this.canvasHeight) {
        continue;
      }
      // 选中节点的标签优先保证（允许压住其他节点圆，但不覆盖已放置标签）
      if (candidate.priority !== 0 && this.intersectsBox(textBox, circles)) {
        continue;
      }
      if (this.intersectsBox(textBox, placed)) {
        continue;
      }
      placed.push(textBox);
      ctx.globalAlpha = candidate.priority === 0 ? 1 : candidate.alpha * 0.95;
      // 浅色描边文字：压在连线/节点上仍可读
      ctx.strokeStyle = CANVAS_BACKGROUND;
      ctx.lineWidth = 3;
      ctx.strokeText(label, drawX, labelY);
      ctx.fillStyle = node.kind === GraphNodeKind.RECOMMEND ? '#8D6E63' : '#5D4037';
      ctx.fillText(label, drawX, labelY);
      ctx.globalAlpha = 1;
    }
  }

  /** 空主题画布内引导（页面下方已有空态卡，这里补画布内的下一步动作） */
  private drawEmptyHint(ctx: CanvasRenderingContext2D): void {
    if (this.model.nodes.length === 0 || this.countHeritageNodes() > 0) {
      return;
    }
    const themeNode: GraphNode | null = this.findThemeNode();
    if (themeNode === null) {
      return;
    }
    const screenX: number = themeNode.x * this.viewScale + this.offsetX;
    const screenY: number = themeNode.y * this.viewScale + this.offsetY;
    const screenRadius: number = themeNode.radius * this.viewScale;
    const hintY: number = screenY + screenRadius + 14;
    if (hintY + 30 > this.canvasHeight) {
      return;
    }
    ctx.globalAlpha = 1;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.font = '11vp sans-serif';
    ctx.fillStyle = '#8D6E63';
    ctx.fillText('尚未归入遗址', screenX, hintY);
    ctx.font = '10vp sans-serif';
    ctx.fillStyle = '#A1887F';
    ctx.fillText('点击下方「归类管理」开始构建知识网络', screenX, hintY + 16);
  }

  private intersectsBox(box: LabelBox, boxes: LabelBox[]): boolean {
    for (let i = 0; i < boxes.length; i++) {
      if (box.left < boxes[i].right && box.right > boxes[i].left &&
        box.top < boxes[i].bottom && box.bottom > boxes[i].top) {
        return true;
      }
    }
    return false;
  }

  private findThemeNode(): GraphNode | null {
    for (let i = 0; i < this.model.nodes.length; i++) {
      if (this.model.nodes[i].kind === GraphNodeKind.THEME) {
        return this.model.nodes[i];
      }
    }
    return null;
  }

  /** 按真实测量宽度截断（英文名同样适用） */
  private fitLabelByWidth(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string {
    if (text === '') {
      return text;
    }
    if (ctx.measureText(text).width <= maxWidth) {
      return text;
    }
    let value: string = text;
    while (value.length > 1 && ctx.measureText(`${value}…`).width > maxWidth) {
      value = value.substring(0, value.length - 1);
    }
    return `${value}…`;
  }

  private countHeritageNodes(): number {
    let count: number = 0;
    for (let i = 0; i < this.model.nodes.length; i++) {
      if (this.model.nodes[i].kind === GraphNodeKind.HERITAGE) {
        count += 1;
      }
    }
    return count;
  }

  private clamp(value: number, min: number, max: number): number {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  // ==================== UI ====================

  @Builder
  controlButton(label: string, fontSize: number, action: () => void) {
    Text(label)
      .fontSize(fontSize)
      .fontColor('#6D4C41')
      .width(32)
      .height(32)
      .textAlign(TextAlign.Center)
      .borderRadius(8)
      .onClick(() => {
        action();
      })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.onCanvasReady();
        })
        .onAreaChange((_oldValue: Area, _newValue: Area) => {
          this.onCanvasResize();
        })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 })
              .onAction((event: GestureEvent) => {
                this.handleTap(event);
              }),
            GestureGroup(GestureMode.Parallel,
              PanGesture({ fingers: 1, distance: 5 })
                .onActionStart((event: GestureEvent) => {
                  this.handlePanStart(event);
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.handlePanUpdate(event);
                })
                .onActionEnd(() => {
                  this.handlePanEnd();
                })
                .onActionCancel(() => {
                  this.handlePanEnd();
                }),
              PinchGesture({ fingers: 2, distance: 5 })
                .onActionStart((event: GestureEvent) => {
                  this.handlePinchStart(event);
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.handlePinchUpdate(event);
                })
                .onActionEnd(() => {
                  this.handlePinchEnd();
                })
                .onActionCancel(() => {
                  this.handlePinchEnd();
                })
            )
          )
        )

      // 视图控制（浮于画布右上角，不参与画布手势）
      Column() {
        this.controlButton('＋', 15, () => {
          this.zoomBy(1.25);
        })
        Divider()
          .width(16)
          .color('#EFE7E0')
        this.controlButton('－', 15, () => {
          this.zoomBy(0.8);
        })
        Divider()
          .width(16)
          .color('#EFE7E0')
        this.controlButton('⟲', 14, () => {
          // 恢复默认布局 + 适配视口（含撤销手动拖动的节点位置）
          this.relayout();
        })
      }
      .padding(2)
      .margin({ top: 10, right: 10 })
      .backgroundColor('rgba(255,255,255,0.92)')
      .borderRadius(12)
      .shadow({ radius: 6, color: 'rgba(62,39,35,0.10)', offsetX: 0, offsetY: 2 })
      .onClick(() => {
        // 消费点击，避免控制条空白处穿透到画布触发选中
      })
    }
    .width('100%')
    .height('100%')
  }
}
