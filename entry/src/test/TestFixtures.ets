/**
 * 本地单元测试公共夹具（M11）：构造最小可用的 Heritage / Favorite / Theme。
 * 仅测试使用，不进入 HAP 包；字段与模型保持同构，避免测试数据与真实结构漂移。
 */

import { Heritage } from '../main/ets/model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../main/ets/model/Types';
import { Favorite } from '../main/ets/model/Favorite';
import { Theme } from '../main/ets/model/Theme';

/** 构造一条最小遗址（详情字段全部为空，仅保留推荐/图谱需要的维度） */
export function makeHeritage(id: string, name: string, era: HeritageEra,
  type: HeritageType, city: HeritageCity): Heritage {
  return {
    id: id,
    name: name,
    era: era,
    type: type,
    city: city,
    coverImage: '',
    summary: `${name}简介`,
    detail: {
      intro: '',
      discovery: '',
      events: [],
      poems: [],
      tourism: {
        overview: '',
        guide: { hours: '', tickets: '', contact: '', address: '' },
        itinerary: '',
        interpretation: ''
      },
      highlights: [],
      specs: [],
      artifacts: [],
      images: []
    }
  };
}

/** 构造一条收藏记录（仅推荐排除/主题推荐需要 itemId） */
export function makeFavorite(itemId: string): Favorite {
  return {
    id: `fav-${itemId}`,
    itemId: itemId,
    tags: [],
    themeIds: [],
    createdAt: 1000,
    updatedAt: 1000,
    deviceId: 'test-device'
  };
}

/** 构造一个主题（仅图谱布局需要 id/name/colorIndex） */
export function makeTheme(id: string, name: string, colorIndex: number): Theme {
  return {
    id: id,
    name: name,
    colorIndex: colorIndex,
    createdAt: 1000,
    updatedAt: 1000,
    deviceId: 'test-device'
  };
}
