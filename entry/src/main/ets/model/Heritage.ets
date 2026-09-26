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
 * → M1.9（文旅深度化迭代）：tourism 由 string 升级为 TourismInfo 结构化对象
 * （overview 概览 / guide 参观指引键值 / itinerary 行程规划 / interpretation 深度解说），
 * 旧版单字符串由加载层自动迁移为 overview（其余字段兜底空），UI 按结构化卡片渲染；
 * HeritageEvent 新增 commentary（深度解说/延伸知识点），加载层兜底空串。
 * → M1.10（遗址图片框架）：新增 HeritageImage（path/caption/source），HeritageDetail 与
 * HeritageEvent 各加 images 数组；path 指向 rawfile 图片（动态加载），空串=待填充占位；
 * 字段只增不改，存量数据缺失兜底空数组。
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
 * 遗址图片（M1.10：真实图片占位 + 点击放大）。
 * path 为 rawfile 相对路径（如 'images/yangshao/1921-excavation.jpg'），空串=待填充占位；
 * caption 为图注；source 为来源/版权标注（官方出处）。
 * 说明：官方图片 URL 经搜索代理缓存不可稳定下载（实测 404），故图片作为本地资源
 * 由用户/稳定渠道提供后填入 rawfile，遵守零网络依赖离线打包约束。
 */
export interface HeritageImage {
  path: string;    // rawfile 图片相对路径，空串=待填充
  caption: string; // 图注（如「1921 年发掘现场」）
  source: string;  // 来源/版权标注
}

/**
 * 参观指引键值项（M1.9 文旅结构化）：开放时间/票务/电话/地址
 */
export interface TourismGuide {
  hours: string;    // 开放时间（含闭馆安排）
  tickets: string;  // 票务政策
  contact: string;  // 咨询电话
  address: string;  // 地址
}

/**
 * 文旅信息（M1.9：由 string 升级为结构化对象，支撑文旅页签卡片化渲染）。
 * 旧版单字符串由加载层自动迁移为 overview，其余字段兜底为空，存量数据无需改 JSON。
 */
export interface TourismInfo {
  overview: string;        // 概览（正文）
  guide: TourismGuide;     // 参观指引（键值信息卡）
  itinerary: string;       // 行程规划（可含 \n 分段）
  interpretation: string;  // 深度解说（看什么、怎么看）
}

/**
 * 历史事件（M1.8：由 string[] 升级为结构化对象，支撑事件子详情页专题讲解）。
 * 字段说明：year/title 为时间轴主展示；background/process/impact 为子页三段正文；
 * figures/artifacts 为相关人物与相关文物；furtherReading 为来源出处（延伸阅读）；
 * commentary（M1.9 新增）为深度解说/延伸知识点，子页独立段落渲染。
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
  commentary: string;    // 深度解说/延伸知识点（M1.9 新增，空串为无）
  images: HeritageImage[]; // 事件图片（M1.10，path 空串=占位待填充）
}

/**
 * 详情五层级内容 + M1.7 结构化字段 + M1.8 结构化事件 + M1.9 结构化文旅
 */
export interface HeritageDetail {
  intro: string;        // 图文介绍
  discovery: string;    // 考古发现
  events: HeritageEvent[]; // 历史事件（M1.8 升级为结构化对象，可点击进事件子详情页）
  poems: Poem[];        // 相关诗词（可多条）
  tourism: TourismInfo; // 现代文旅信息（M1.9 结构化：概览/参观指引/行程规划/深度解说）
  highlights: string[]; // 核心看点（M1.7，介绍页签顶部 chips）
  specs: SpecItem[];    // 遗址档案键值（M1.7，介绍页签底部档案卡）
  artifacts: Artifact[]; // 代表性出土文物（M1.7，考古页签文物卡）
  images: HeritageImage[]; // 遗址级图集（M1.10，考古页签展示，path 空串=占位待填充）
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