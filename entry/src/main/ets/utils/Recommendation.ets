/**
 * 工具函数（M4.1）：智能关联推荐——条目特征向量 → 余弦相似度 → Top-N。
 *
 * 设计说明（计划书 §5 M4.1，utils 层纯函数：无状态、无副作用、不抛异常）：
 * - 特征向量：16 维 one-hot（年代 6 + 类型 4 + 城市 6），仅定位唯一激活维；
 *   对 one-hot 向量余弦相似度退化为「共享特征维度数」（era/type/city 各至多共享 1 维，
 *   值 ∈ {0, 1/3, 2/3, 1}），语义直观：完全无关=0、共享一维=1/3、共享两维=2/3、
 *   三维全同=1（同年代同类型同城市）。
 * - 收藏微调（M4.2）：候选条目若在用户收藏集合中，分数 +0.1 小加权——0.1 小于任意
 *   非零相似度差（1/3≈0.333），不会颠倒主要相似度次序，只让同一档位内「已收藏」的
 *   条目更靠前，体现个性化偏好而非主导排序。
 * - 排序稳定：分数降序，同分按名称升序（同数据必得同结果，便于交叉验证）。
 * - Top-N 兜底：先取「分数 > 0」的强关联条目，不足 N 条再用剩余候选按序补足
 *   （保证推荐区块始终有内容）；无候选（数据源 ≤ 1 条 / 当前条目不在列表中）返回空数组。
 * - 调用约定：list 传当前数据源全量（rawfile 或 mock，与详情同源），currentId 为详情页
 *   目标 id，favoriteIds 取 FavoriteService.getAllFavorites 的 itemId 集合。
 */

import { Heritage } from '../model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../model/Types';

/** 推荐候选内部结构（排序用，分数 = 余弦相似度 + 收藏加成） */
interface ScoredHeritage {
  item: Heritage;
  score: number;
}

/** 年代 one-hot 顺序（与 Types.ets 枚举定义一致，16 维向量中占 0~5） */
const ERA_ORDER: HeritageEra[] = [
  HeritageEra.YANGSHAO, HeritageEra.LONGSHAN, HeritageEra.XIA_SHANG,
  HeritageEra.ZHOU, HeritageEra.HAN_TANG, HeritageEra.SONG
];

/** 类型 one-hot 顺序（占 6~9） */
const TYPE_ORDER: HeritageType[] = [
  HeritageType.CAPITAL_SITE, HeritageType.TOMB_GROUP,
  HeritageType.KILN_SITE, HeritageType.ANCIENT_BUILDING
];

/** 城市 one-hot 顺序（占 10~15） */
const CITY_ORDER: HeritageCity[] = [
  HeritageCity.SANMENXIA, HeritageCity.LUOYANG, HeritageCity.ZHENGZHOU,
  HeritageCity.KAIFENG, HeritageCity.PUYANG, HeritageCity.ANYANG
];

/** 收藏微调加权（小于最小非零相似度差 1/3，只做同档位内排序提升） */
const FAVORITE_BONUS = 0.1;

/**
 * 条目特征向量：年代/类型/城市 one-hot（16 维）。
 * 枚举值不匹配时对应段全 0（非法数据不产生假相似度，与数据层校验纪律一致）。
 */
export function buildFeatureVector(era: string, type: string, city: string): number[] {
  const v: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  const eraIdx: number = ERA_ORDER.indexOf(era as HeritageEra);
  if (eraIdx >= 0) {
    v[eraIdx] = 1;
  }
  const typeIdx: number = TYPE_ORDER.indexOf(type as HeritageType);
  if (typeIdx >= 0) {
    v[6 + typeIdx] = 1;
  }
  const cityIdx: number = CITY_ORDER.indexOf(city as HeritageCity);
  if (cityIdx >= 0) {
    v[10 + cityIdx] = 1;
  }
  return v;
}

/**
 * 余弦相似度（标准实现）。零向量或维度不一致返回 0（无相似度）。
 * 对 one-hot 向量即「共享特征维度数」。
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) {
    return 0;
  }
  let dot: number = 0;
  let normA: number = 0;
  let normB: number = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) {
    return 0;
  }
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Top-N 推荐：以 currentId 条目为锚，对其余条目按「余弦相似度 + 收藏微调」降序取 N 条。
 * @param list 当前数据源全量条目（与详情页同源：rawfile 或 mock）
 * @param currentId 当前详情页目标 id（推荐排除自身）
 * @param favoriteIds 用户已收藏的 itemId 集合（FavoriteService.getAllFavorites 提取）
 * @param topN 期望返回条数
 */
export function recommendHeritages(list: Heritage[], currentId: string,
  favoriteIds: string[], topN: number): Heritage[] {
  const current: Heritage | null = findById(list, currentId);
  if (current === null) {
    return [];
  }
  const currentVec: number[] = buildFeatureVector(current.era, current.type, current.city);
  const candidates: ScoredHeritage[] = [];
  for (let i = 0; i < list.length; i++) {
    const item: Heritage = list[i];
    if (item.id === currentId) {
      continue;
    }
    const sim: number = cosineSimilarity(currentVec,
      buildFeatureVector(item.era, item.type, item.city));
    let score: number = sim;
    if (favoriteIds.indexOf(item.id) >= 0) {
      score += FAVORITE_BONUS; // 收藏微调：已收藏条目同档位内优先
    }
    const scored: ScoredHeritage = { item: item, score: score };
    candidates.push(scored);
  }
  if (candidates.length === 0) {
    return [];
  }
  candidates.sort((a: ScoredHeritage, b: ScoredHeritage): number => {
    if (a.score !== b.score) {
      return b.score - a.score;
    }
    return a.item.name < b.item.name ? -1 : (a.item.name > b.item.name ? 1 : 0);
  });
  const result: Heritage[] = [];
  // 第一轮：强关联（分数 > 0，含「相似且已收藏」的微调提升）
  for (let i = 0; i < candidates.length && result.length < topN; i++) {
    if (candidates[i].score > 0) {
      result.push(candidates[i].item);
    }
  }
  // 第二轮：弱关联补足（保证推荐区块始终有内容）
  for (let i = 0; i < candidates.length && result.length < topN; i++) {
    if (candidates[i].score <= 0) {
      result.push(candidates[i].item);
    }
  }
  return result;
}

/** 按 id 查找条目（内部辅助，无则 null） */
function findById(list: Heritage[], id: string): Heritage | null {
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      return list[i];
    }
  }
  return null;
}
