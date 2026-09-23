/**
 * 数据模型：文化条目（Heritage）—— 只读预置数据
 * 字段一次成型，M1 后结构不再变更。
 * 来源：任务书「四、数据模型」Heritage / HeritageDetail
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
 * 详情五层级内容
 */
export interface HeritageDetail {
  intro: string;        // 图文介绍
  discovery: string;    // 考古发现
  events: string[];     // 历史事件（可多条）
  poems: Poem[];        // 相关诗词（可多条）
  tourism: string;      // 现代文旅信息
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