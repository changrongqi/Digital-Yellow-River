/**
 * 知识图谱 Canvas 绘制组件
 *
 * 职责：仅负责 Canvas 绘制与点击命中测试，不管理业务状态
 * 官方依据：CanvasRenderingContext2D 默认 vp 单位，context.width/height 为 vp
 * 设计：中心主题节点 + 环绕遗址节点圆周分布 + 连线，克制简洁
 */

import { GraphNode } from './GraphNode';
import { Heritage } from '../../model/Heritage';
import { Theme } from '../../model/Theme';
import { getEraTheme } from '../../utils/EraTheme';

/** 主题色板 */
const THEME_PALETTE: string[] = ['#6D4C41', '#C0392B', '#2E7D32', '#1565C0', '#6A1B9A', '#EF6C00'];

@Component
export struct GraphCanvas {
  /** 选中主题 */
  @Prop theme: Theme | null = null;
  /** 已归类遗址列表 */
  @Prop heritages: Heritage[] = [];
  /** 点击节点回调 */
  onNodeClick: (id: string) => void = () => {};

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private graphNodes: GraphNode[] = [];

  /** 数值钳制到 [min, max] */
  private clamp(v: number, min: number, max: number): number {
    if (v < min) {
      return min;
    }
    if (v > max) {
      return max;
    }
    return v;
  }

  /**
   * 按像素宽度截断（Canvas measureText 实测 vp 宽度）
   * 字符数策略对英文名（如 "First"）误截为 "Fi…"，宽度策略可完整显示
   */
  private fitLabelByWidth(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string {
    if (text === '') {
      return text;
    }
    if (ctx.measureText(text).width <= maxWidth) {
      return text;
    }
    let s: string = text;
    while (s.length > 1 && ctx.measureText(`${s}…`).width > maxWidth) {
      s = s.substring(0, s.length - 1);
    }
    return `${s}…`;
  }

  /** 绘制知识节点网络 */
  private drawGraph(): void {
    const w: number = this.context.width;
    const h: number = this.context.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, w, h);
    this.graphNodes = [];
    const cx: number = w / 2;
    const cy: number = h / 2;

    // 尺寸计算（vp 域，随画布宽度等比缩放）
    const themeR: number = this.clamp(Math.round(w * 0.11), 40, 52);
    const nodeR: number = this.clamp(Math.round(w * 0.065), 26, 34);
    const themeFont: number = this.clamp(Math.round(themeR * 0.38), 14, 20);
    const labelFont: number = this.clamp(Math.round(nodeR * 0.48), 12, 16);
    const countFont: number = this.clamp(Math.round(themeR * 0.26), 11, 14);
    // 主题名最大宽度 = 圆直径减边距；遗址标签允许轻微溢出圆形以保证名称完整
    const themeNameMaxWidth: number = themeR * 2 - 12;
    const siteNameMaxWidth: number = nodeR * 2.4;

    // 中心主题节点
    const themeColor: string = this.theme === null ? '#9E9E9E' : THEME_PALETTE[this.theme.colorIndex % THEME_PALETTE.length];
    ctx.beginPath();
    ctx.arc(cx, cy, themeR, 0, Math.PI * 2);
    ctx.fillStyle = themeColor;
    ctx.fill();

    // 主题名（支持两行显示）
    ctx.fillStyle = '#FFFFFF';
    ctx.textAlign = 'center';
    ctx.font = `${themeFont}vp sans-serif`;
    const themeName: string = this.theme === null ? '未选择' : this.theme.name;
    const displayName: string = this.fitLabelByWidth(ctx, themeName, themeNameMaxWidth);
    ctx.fillText(displayName, cx, cy - 2);

    // 「N 处」计数
    ctx.font = `${countFont}vp sans-serif`;
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.fillText(`${this.heritages.length} 处`, cx, cy + themeR * 0.55);

    // 环绕遗址节点
    const n: number = this.heritages.length;
    if (n > 0) {
      const layoutR: number = Math.max(70, Math.min(w, h) / 2 - themeR - nodeR - 16);
      for (let i = 0; i < n; i++) {
        const angle: number = (i / n) * Math.PI * 2 - Math.PI / 2;
        const x: number = cx + layoutR * Math.cos(angle);
        const y: number = cy + layoutR * Math.sin(angle);

        // 连线
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(x, y);
        ctx.strokeStyle = '#E0D6CC';
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // 节点圆
        const item: Heritage = this.heritages[i];
        const eraTheme = getEraTheme(item.era);
        ctx.beginPath();
        ctx.arc(x, y, nodeR, 0, Math.PI * 2);
        ctx.fillStyle = eraTheme.soft;
        ctx.fill();
        ctx.strokeStyle = eraTheme.deep;
        ctx.lineWidth = 2;
        ctx.stroke();

        // 遗址名称（内嵌标签，居中显示）
        ctx.fillStyle = '#3E2723';
        ctx.font = `${labelFont}vp sans-serif`;
        ctx.textAlign = 'center';
        const shortName: string = this.fitLabelByWidth(ctx, item.name, siteNameMaxWidth);
        ctx.fillText(shortName, x, y + labelFont * 0.35);

        this.graphNodes.push(new GraphNode(item.id, item.name, x, y, nodeR));
      }
    }
  }

  /** Canvas 点击命中测试 */
  private handleCanvasTap(tx: number, ty: number): void {
    for (let i = 0; i < this.graphNodes.length; i++) {
      const node: GraphNode = this.graphNodes[i];
      const dx: number = tx - node.x;
      const dy: number = ty - node.y;
      const dist: number = Math.sqrt(dx * dx + dy * dy);
      if (dist <= node.r + 12) {
        this.onNodeClick(node.id);
        return;
      }
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.drawGraph();
      })
      .onAreaChange((_oldValue: Area, _newValue: Area) => {
        this.drawGraph();
      })
      .onClick((event: ClickEvent) => {
        this.handleCanvasTap(event.x, event.y);
      })
  }
}
