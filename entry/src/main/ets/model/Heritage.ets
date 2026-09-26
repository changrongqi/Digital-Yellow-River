/**
 * 数据模型：文化条目（Heritage）—— 只读预置数据
 * 来源：任务书「四、数据模型」Heritage / HeritageDetail
 * 结构变更记录：M1 后冻结 → M1.7（2026-09-27，动态演进）解除冻结，
 * 新增 highlights/specs/artifacts 三个可选结构化字段（解析时字段缺失兜底为空数组，
 * 旧数据兼容）；「字段只增不改」原则继续有效，存量字段语义不变。
 * → M1.8（计划书授权「events 升级为结构化对象」）：events 由 string[] 升级为
 * HeritageEvent[]（含 background/process/impact/figures/artifacts/furtherReading 子详情字段），
 * 旧版字符串「XXXX年：正文」由加载层自动迁移为 year+title，存量数据无需改 JSON 即可兼容；
 * 升级属计划书 M1.8 明确授权，其余字段语义不变。
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
 * 历史事件（M1.8：由 string[] 升级为结构化对象，支撑事件子详情页专题讲解）。
 * 字段说明：year/title 为时间轴主展示；background/process/impact 为子页三段正文；
 * figures/artifacts 为相关人物与相关文物；furtherReading 为来源出处（延伸阅读）。
 * 旧版字符串「XXXX年：正文」由加载层自动迁移为 year + title，其余字段兜底为空。
 */
export interface HeritageEvent {
  year: string;          // 年份前缀（如「1921年」），无年份可为空
  title: string;         // 事件标题（时间轴主文案）
  summary: string;       // 一句话概述（子页简介）
  background: string;    // 背景
  process: string;       // 经过
  impact: string;        // 影响
  figures: string[];     // 相关人物
  artifacts: string[];   // 相关文物
  furtherReading: string; // 延伸阅读（来源出处）
}

/**
 * 详情五层级内容 + M1.7 结构化字段 + M1.8 结构化事件
 */
export interface HeritageDetail {
  intro: string;        // 图文介绍
  discovery: string;    // 考古发现
  events: HeritageEvent[]; // 历史事件（M1.8 升级为结构化对象，可点击进事件子详情页）
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