/**
 * 知识图谱 Canvas 交互与视图控制组件（C1.4 重构，C1.6 渲染层拆分）
 *
 * 职责：数据刷新调度、视口变换、手势识别、命中测试与右上角控件；
 * 具体绘制（边/节点/标签/空态）在 GraphRenderer，纯绘制且不持有 ArkUI 状态。
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
import { GraphNode, GraphModel, GraphNodeKind } from './GraphNode';
import {
  GraphBounds,
  GraphTransform,
  buildGraphModel,
  layoutGraph,
  computeBounds,
  computeFitTransform
} from './GraphLayout';
import { GraphRenderer } from './GraphRenderer';

/** 用户缩放范围（视口初始适配范围更窄，见 GraphLayout） */
const MIN_USER_SCALE: number = 0.45;
const MAX_USER_SCALE: number = 2.6;
/** 平移边界：内容至少保留多少 vp 在画布内 */
const VIEWPORT_MARGIN: number = 40;
/** 命中测试：节点半径外扩容差（vp；小缩放时再按屏幕最小触控区补偿） */
const HIT_TOLERANCE_EXTRA: number = 8;
const HIT_TOLERANCE_SCREEN: number = 22;
/** 画布宽高变化判定阈值（vp），避免 onAreaChange 抖动触发重置视口 */
const SIZE_CHANGE_EPSILON: number = 0.5;

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
  /** 绘制层：只接收快照参数，不持有 ArkUI 状态 */
  private renderer: GraphRenderer = new GraphRenderer();
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
    const changed: boolean = Math.abs(width - this.canvasWidth) >= SIZE_CHANGE_EPSILON ||
      Math.abs(height - this.canvasHeight) >= SIZE_CHANGE_EPSILON;
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
    const minOffsetX: number = VIEWPORT_MARGIN - this.bounds.maxX * this.viewScale;
    const maxOffsetX: number = this.canvasWidth - VIEWPORT_MARGIN - this.bounds.minX * this.viewScale;
    if (minOffsetX > maxOffsetX) {
      this.offsetX = this.canvasWidth / 2 - (this.bounds.minX + this.bounds.maxX) / 2 * this.viewScale;
    } else {
      this.offsetX = this.clamp(this.offsetX, minOffsetX, maxOffsetX);
    }
    const minOffsetY: number = VIEWPORT_MARGIN - this.bounds.maxY * this.viewScale;
    const maxOffsetY: number = this.canvasHeight - VIEWPORT_MARGIN - this.bounds.minY * this.viewScale;
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
      const tolerance: number = Math.max(node.radius + HIT_TOLERANCE_EXTRA,
        HIT_TOLERANCE_SCREEN / this.viewScale);
      if (Math.sqrt(dx * dx + dy * dy) <= tolerance) {
        return node;
      }
    }
    return null;
  }

  // ==================== 绘制调度 ====================

  private drawGraph(): void {
    const transform: GraphTransform = {
      scale: this.viewScale,
      offsetX: this.offsetX,
      offsetY: this.offsetY
    };
    this.renderer.draw(this.context, this.model, this.selectedId, transform,
      this.canvasWidth, this.canvasHeight);
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
