/**
 * 主题拓展推荐（C1.6 从 KnowledgeGraph 抽出的纯函数）
 *
 * 规则与 C1.4/C1.5 完全一致：
 * - 以主题下每条已归类遗址为锚点分别取相似条目，合并去重（不只看第一条）；
 * - 排除全部已收藏条目（拓展推荐指向「尚未发现」的遗址）；
 * - 排除主题内条目，最多 maxCount 条。
 *
 * 无状态、无 UI 依赖，便于单独校验推荐结果；页面只负责把结果放进 @State。
 */

import { Heritage } from '../model/Heritage';
import { Favorite } from '../model/Favorite';
import { recommendHeritages } from './Recommendation';

/** 单个锚点最多取多少条候选（再由主题层去重/截断） */
const CANDIDATE_LIMIT: number = 12;

/** 构建一个主题的拓展推荐列表（顺序稳定：主题内锚点顺序 → 锚点内相似度顺序） */
export function buildThemeRecommendations(allHeritage: Heritage[], themed: Heritage[],
  favorites: Favorite[], maxCount: number): Heritage[] {
  if (themed.length === 0 || allHeritage.length === 0 || maxCount <= 0) {
    return [];
  }
  const favoriteIds: string[] = [];
  const favoriteMap: Map<string, boolean> = new Map();
  for (let i = 0; i < favorites.length; i++) {
    favoriteIds.push(favorites[i].itemId);
    favoriteMap.set(favorites[i].itemId, true);
  }
  const themedMap: Map<string, boolean> = new Map();
  for (let i = 0; i < themed.length; i++) {
    themedMap.set(themed[i].id, true);
  }
  const used: Map<string, boolean> = new Map();
  const result: Heritage[] = [];
  for (let anchorIndex = 0; anchorIndex < themed.length; anchorIndex++) {
    if (result.length >= maxCount) {
      break;
    }
    const candidates: Heritage[] = recommendHeritages(allHeritage,
      themed[anchorIndex].id, favoriteIds, CANDIDATE_LIMIT);
    for (let i = 0; i < candidates.length && result.length < maxCount; i++) {
      const candidate: Heritage = candidates[i];
      if (favoriteMap.get(candidate.id) === true) {
        continue;
      }
      if (used.get(candidate.id) === true) {
        continue;
      }
      if (themedMap.get(candidate.id) === true) {
        continue;
      }
      used.set(candidate.id, true);
      result.push(candidate);
    }
  }
  return result;
}
