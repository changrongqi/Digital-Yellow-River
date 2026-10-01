/**
 * 图谱节点数据模型（Canvas 命中测试用）
 */
export class GraphNode {
  id: string;
  label: string;
  x: number;
  y: number;
  r: number;

  constructor(id: string, label: string, x: number, y: number, r: number) {
    this.id = id;
    this.label = label;
    this.x = x;
    this.y = y;
    this.r = r;
  }
}
