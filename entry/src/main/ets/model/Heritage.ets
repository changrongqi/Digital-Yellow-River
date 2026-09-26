/**
 * 数据模型：文化条目（Heritage）—— 只读预置数据
 * 来源：任务书「四、数据模型」Heritage / HeritageDetail
 * 结构变更记录：M1 后冻结 → M1.7（2026-09-27，动态演进）解除冻结，
 * 新增 highlights/specs/artifacts 三个可选结构化字段（解析时字段缺失兜底为空数组，
 * 旧数据兼容）；「字段只增不改」原则继续有效，存量字段语义不变。
 */

import { HeritageEra, HeritageType, HeritageCity } from './Types';

/**
 * 相关诗词
 */
export interface Poem {
  title: string;
  author: string;
  content: string;
}

/**
 * 遗址档案键值项（M1.7）：面积/年代跨度/保护级别等速查信息
 */
export interface SpecItem {
  label: string;  // 档案项名称（如「遗址面积」）
  value: string;  // 档案值（如「约30万平方米」）
}

/**
 * 代表性出土文物（M1.7）
 */
export interface Artifact {
  name: string;  // 文物名称（如「彩陶盆」）
  desc: string;  // 文物说明
}

/**
 * 详情五层级内容 + M1.7 结构化字段
 */
export interface HeritageDetail {
  intro: string;        // 图文介绍
  discovery: string;    // 考古发现
  events: string[];     // 历史事件（可多条）
  poems: Poem[];        // 相关诗词（可多条）
  tourism: string;      // 现代文旅信息
  highlights: string[]; // 核心看点（M1.7，介绍页签顶部 chips）
  specs: SpecItem[];    // 遗址档案键值（M1.7，介绍页签底部档案卡）
  artifacts: Artifact[]; // 代表性出土文物（M1.7，考古页签文物卡）
}

/**
 * 文化条目
 */
export interface Heritage {
  id: string;
  name: string;
  era: HeritageEra;       // 年代
  type: HeritageType;     // 类型
  city: HeritageCity;     // 城市
  coverImage: string;     // rawfile 封面图相对路径
  summary: string;        // 一句话简介（列表页）
  detail: HeritageDetail; // 详情五层级
}