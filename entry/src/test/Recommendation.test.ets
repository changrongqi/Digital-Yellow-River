/**
 * 本地单元测试（M11）：推荐算法与主题拓展推荐（纯函数）。
 * 覆盖：one-hot 特征、余弦相似度、Top-N 排序/兜底、收藏微调、主题推荐排除规则。
 */

import { describe, it, expect } from '@ohos/hypium';
import { Heritage } from '../main/ets/model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../main/ets/model/Types';
import { Favorite } from '../main/ets/model/Favorite';
import { buildFeatureVector, cosineSimilarity, recommendHeritages } from '../main/ets/utils/Recommendation';
import { buildThemeRecommendations } from '../main/ets/utils/ThemeRecommendation';
import { makeHeritage, makeFavorite } from './TestFixtures';

/** 固定夹具：A 为锚点；B 同年代+同城市；D 同年代；E 同城市；C 无共享特征 */
const A: Heritage = makeHeritage('a', '甲', HeritageEra.YANGSHAO,
  HeritageType.CAPITAL_SITE, HeritageCity.LUOYANG);
const B: Heritage = makeHeritage('b', '乙', HeritageEra.YANGSHAO,
  HeritageType.TOMB_GROUP, HeritageCity.LUOYANG);
const C: Heritage = makeHeritage('c', '丙', HeritageEra.SONG,
  HeritageType.KILN_SITE, HeritageCity.KAIFENG);
const D: Heritage = makeHeritage('d', '丁', HeritageEra.YANGSHAO,
  HeritageType.TOMB_GROUP, HeritageCity.ZHENGZHOU);
const E: Heritage = makeHeritage('e', '戊', HeritageEra.SONG,
  HeritageType.CAPITAL_SITE, HeritageCity.LUOYANG);
const LIST: Heritage[] = [A, B, C, D, E];

export default function recommendationTest() {
  describe('FeatureVector', () => {
    it('activatesEraTypeCityDimensions', 0, () => {
      const v: number[] = buildFeatureVector(A.era, A.type, A.city);
      expect(v.length).assertEqual(16);
      expect(v[0]).assertEqual(1);   // 仰韶
      expect(v[6]).assertEqual(1);   // 都城遗址
      expect(v[11]).assertEqual(1);  // 洛阳
    });
    it('ignoresUnknownDimensionValues', 0, () => {
      const v: number[] = buildFeatureVector('未知年代', '未知类型', '未知城市');
      let sum: number = 0;
      for (let i = 0; i < v.length; i++) {
        sum += v[i];
      }
      expect(sum).assertEqual(0);
    });
  });

  describe('CosineSimilarity', () => {
    it('identicalVectorIsOne', 0, () => {
      const v: number[] = buildFeatureVector(A.era, A.type, A.city);
      expect(Math.abs(cosineSimilarity(v, v) - 1) < 0.000001).assertEqual(true);
    });
    it('disjointVectorIsZero', 0, () => {
      const va: number[] = buildFeatureVector(A.era, A.type, A.city);
      const vc: number[] = buildFeatureVector(C.era, C.type, C.city);
      expect(cosineSimilarity(va, vc)).assertEqual(0);
    });
    it('zeroOrMismatchedVectorIsZero', 0, () => {
      expect(cosineSimilarity([0, 0], [0, 0])).assertEqual(0);
      expect(cosineSimilarity([1], [1, 0])).assertEqual(0);
    });
  });

  describe('RecommendHeritages', () => {
    it('ordersBySharedDimensionsAndName', 0, () => {
      // B/E 均与 A 共享两维（0.667），按名称升序 B 在前；D 仅共享年代（0.333）
      const result: Heritage[] = recommendHeritages(LIST, 'a', [], 3);
      expect(result.length).assertEqual(3);
      expect(result[0].id).assertEqual('b');
      expect(result[1].id).assertEqual('e');
      expect(result[2].id).assertEqual('d');
    });
    it('favoriteBonusPromotesWithinSameTier', 0, () => {
      // E 与 A 共享类型+城市（0.667）+ 收藏加成 0.1 → 超过 B
      const result: Heritage[] = recommendHeritages(LIST, 'a', ['e'], 2);
      expect(result[0].id).assertEqual('e');
      expect(result[1].id).assertEqual('b');
    });
    it('fillsWeakCandidatesAfterStrongOnes', 0, () => {
      const result: Heritage[] = recommendHeritages(LIST, 'a', [], 10);
      expect(result.length).assertEqual(4);
      expect(result[3].id).assertEqual('c');
    });
    it('returnsEmptyForUnknownCurrentId', 0, () => {
      expect(recommendHeritages(LIST, 'missing', [], 3).length).assertEqual(0);
    });
  });

  describe('ThemeRecommendations', () => {
    it('excludesThemedAndFavoritedEntries', 0, () => {
      const favorites: Favorite[] = [makeFavorite('b')];
      const result: Heritage[] = buildThemeRecommendations(LIST, [A], favorites, 3);
      expect(result.length).assertEqual(3);
      expect(result[0].id).assertEqual('e');
      expect(result[1].id).assertEqual('d');
      for (let i = 0; i < result.length; i++) {
        expect(result[i].id === 'a').assertEqual(false);
        expect(result[i].id === 'b').assertEqual(false);
      }
    });
    it('respectsMaxCount', 0, () => {
      const result: Heritage[] = buildThemeRecommendations(LIST, [A], [], 2);
      expect(result.length).assertEqual(2);
      expect(result[0].id).assertEqual('b');
    });
    it('returnsEmptyWithoutThemedHeritage', 0, () => {
      expect(buildThemeRecommendations(LIST, [], [], 3).length).assertEqual(0);
    });
  });
}
