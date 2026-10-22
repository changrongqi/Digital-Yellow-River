/**
 * 知识图谱绘制层（C1.6 结构规范化）
 *
 * 职责：把 GraphModel 按视口变换绘制到 Canvas（边 → 节点 → 屏幕坐标文字）。
 * 不持有 ArkUI 状态、不处理手势、不修改图模型；GraphCanvas 负责数据刷新、
 * 视口、手势与控件，本类只接收一次绘制的快照参数。
 *
 * 分层收益：新增节点/边样式、导出静态图或替换渲染实现时无需改动交互层；
 * 绘制逻辑也可脱离设备做几何校验。
 */

import { GraphNode, GraphEdge, GraphModel, GraphNodeKind, GraphEdgeKind } from './GraphNode';
import { GraphTransform, findNodeByKey } from './GraphLayout';

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

export class GraphRenderer {
  /** 本次绘制的输入快照（draw 开始时整体赋值，绘制结束不再跨帧复用） */
  private model: GraphModel = { nodes: [], edges: [] };
  private transform: GraphTransform = { scale: 1, offsetX: 0, offsetY: 0 };
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private selected: GraphNode | null = null;
  private neighbors: Map<string, boolean> = new Map();
  private themeNode: GraphNode | null = null;
  private heritageCount: number = 0;

  /** 绘制一次完整画面（快照参数，调用方负责重绘调度） */
  draw(ctx: CanvasRenderingContext2D, model: GraphModel, selectedId: string,
    transform: GraphTransform, width: number, height: number): void {
    this.model = model;
    this.transform = transform;
    this.canvasWidth = width;
    this.canvasHeight = height;
    if (width <= 0 || height <= 0) {
      return;
    }
    // 不填充背景：保留父容器的圆角与底色（Canvas 填充会盖住卡片圆角）
    ctx.clearRect(0, 0, width, height);
    if (model.nodes.length === 0) {
      return;
    }
    this.selected = this.findSelectedNode(selectedId);
    this.neighbors = this.collectNeighborKeys();
    this.themeNode = this.findThemeNode();
    this.heritageCount = this.countHeritageNodes();

    ctx.save();
    ctx.translate(transform.offsetX, transform.offsetY);
    ctx.scale(transform.scale, transform.scale);

    // 先画边（亲和线在下、主干关系在上）
    for (let i = 0; i < model.edges.length; i++) {
      if (model.edges[i].kind === GraphEdgeKind.AFFINITY) {
        this.drawEdge(ctx, model.edges[i]);
      }
    }
    for (let i = 0; i < model.edges.length; i++) {
      if (model.edges[i].kind !== GraphEdgeKind.AFFINITY) {
        this.drawEdge(ctx, model.edges[i]);
      }
    }

    // 再画节点
    for (let i = 0; i < model.nodes.length; i++) {
      this.drawNode(ctx, model.nodes[i]);
    }
    ctx.restore();

    // 文字统一画在屏幕坐标系：字号不随缩放变小，并做碰撞避让
    this.drawThemeLabel(ctx);
    this.drawNodeLabels(ctx);
    this.drawEmptyHint(ctx);
  }

  // ==================== 选中与坐标辅助 ====================

  private findSelectedNode(selectedId: string): GraphNode | null {
    if (selectedId === '') {
      return null;
    }
    for (let i = 0; i < this.model.nodes.length; i++) {
      if (this.model.nodes[i].itemId === selectedId) {
        return this.model.nodes[i];
      }
    }
    return null;
  }

  private collectNeighborKeys(): Map<string, boolean> {
    const neighbors: Map<string, boolean> = new Map();
    if (this.selected === null) {
      return neighbors;
    }
    for (let i = 0; i < this.model.edges.length; i++) {
      const edge: GraphEdge = this.model.edges[i];
      if (edge.sourceKey === this.selected.key) {
        neighbors.set(edge.targetKey, true);
      } else if (edge.targetKey === this.selected.key) {
        neighbors.set(edge.sourceKey, true);
      }
    }
    return neighbors;
  }

  /** 节点透明度：选中时自身与邻接节点保持，其余淡出 */
  private nodeAlpha(node: GraphNode): number {
    if (this.selected === null) {
      return 1;
    }
    const isSelf: boolean = node.key === this.selected.key;
    const isNeighbor: boolean = this.neighbors.get(node.key) === true;
    return isSelf || isNeighbor ? 1 : 0.28;
  }

  private screenX(worldX: number): number {
    return worldX * this.transform.scale + this.transform.offsetX;
  }

  private screenY(worldY: number): number {
    return worldY * this.transform.scale + this.transform.offsetY;
  }

  // ==================== 边 ====================

  private drawEdge(ctx: CanvasRenderingContext2D, edge: GraphEdge): void {
    const source: GraphNode | null = findNodeByKey(this.model.nodes, edge.sourceKey);
    const target: GraphNode | null = findNodeByKey(this.model.nodes, edge.targetKey);
    if (source === null || target === null) {
      return;
    }
    const incident: boolean = this.selected !== null &&
      (edge.sourceKey === this.selected.key || edge.targetKey === this.selected.key);

    // 透明度：选中时非邻接边退后，未选中时按边类型分级
    let alpha: number = 1;
    if (this.selected !== null) {
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

  // ==================== 节点 ====================

  private drawNode(ctx: CanvasRenderingContext2D, node: GraphNode): void {
    const alpha: number = this.nodeAlpha(node);
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
    if (this.selected !== null && node.key === this.selected.key) {
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

  // ==================== 文字 ====================

  /** 中心主题文字：屏幕坐标固定字号（缩放只改变圆的大小，不影响可读性） */
  private drawThemeLabel(ctx: CanvasRenderingContext2D): void {
    const themeNode: GraphNode | null = this.themeNode;
    if (themeNode === null) {
      return;
    }
    const screenX: number = this.screenX(themeNode.x);
    const screenY: number = this.screenY(themeNode.y);
    const screenRadius: number = themeNode.radius * this.transform.scale;
    if (screenRadius < 8) {
      return;
    }
    const alpha: number = this.nodeAlpha(themeNode);
    ctx.globalAlpha = alpha;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';
    const count: number = this.heritageCount;
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
  private drawNodeLabels(ctx: CanvasRenderingContext2D): void {
    // 节点圆先占位：普通标签不得压住任何节点
    const circles: LabelBox[] = [];
    for (let i = 0; i < this.model.nodes.length; i++) {
      const node: GraphNode = this.model.nodes[i];
      const screenX: number = this.screenX(node.x);
      const screenY: number = this.screenY(node.y);
      const screenRadius: number = node.radius * this.transform.scale;
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
      if (this.selected !== null) {
        if (node.key === this.selected.key) {
          priority = 0;
        } else if (this.neighbors.get(node.key) === true) {
          priority = 1;
        }
      }
      const candidate: LabelCandidate = {
        node: node,
        priority: priority,
        alpha: this.nodeAlpha(node)
      };
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
      const screenX: number = this.screenX(node.x);
      const screenY: number = this.screenY(node.y);
      const screenRadius: number = node.radius * this.transform.scale;
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
    if (this.model.nodes.length === 0 || this.heritageCount > 0) {
      return;
    }
    const themeNode: GraphNode | null = this.themeNode;
    if (themeNode === null) {
      return;
    }
    const screenX: number = this.screenX(themeNode.x);
    const screenY: number = this.screenY(themeNode.y);
    const screenRadius: number = themeNode.radius * this.transform.scale;
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

  // ==================== 几何辅助 ====================

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
}
