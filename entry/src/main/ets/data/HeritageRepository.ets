/**
 * 预置数据仓库（M4）：页面唯一的数据加载入口。
 *
 * 职责：
 * 1. rawfile 优先：内部走 HeritageDataLoader（进程内缓存 + 唯一解析入口）；
 * 2. 失败兜底：加载/解析失败（含预览器无法读 rawfile）时注入 MOCK_HERITAGES，isMock=true；
 * 3. 统一映射：一次构建并按 id 缓存 Map，收藏页/笔记页/图谱页不再各自建表；
 * 4. 不向页面抛异常：页面只消费 HeritageLoadResult，避免 7 份重复 try/catch + mock 逻辑。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Heritage } from '../model/Heritage';
import { HeritageDataLoader } from './HeritageDataLoader';
import { MOCK_HERITAGES } from './MockHeritages';

const DOMAIN = 0x0000;
const TAG = 'HeritageRepository';

/** 页面消费的加载结果（list 只读，byId 只读） */
export interface HeritageLoadResult {
  list: Heritage[];
  byId: Map<string, Heritage>;
  isMock: boolean;
}

export class HeritageRepository {
  /** 真实数据 id 映射缓存（rawfile 只读，一次构建全程复用） */
  private static cachedMap: Map<string, Heritage> | null = null;
  /** mock 数据 id 映射缓存（预览器/加载失败兜底，单独缓存避免与真实映射混淆） */
  private static cachedMockMap: Map<string, Heritage> | null = null;

  /**
   * 加载预置数据；任何失败都转为 mock 结果，不向页面抛异常。
   * @param context 允许 undefined（极端环境/预览器），此时直接返回 mock。
   */
  static async load(context: common.Context | undefined): Promise<HeritageLoadResult> {
    if (context === undefined) {
      hilog.error(DOMAIN, TAG, 'host context unavailable, fallback to mock');
      return HeritageRepository.mockResult();
    }
    try {
      const list: Heritage[] = await HeritageDataLoader.loadHeritageList(context);
      if (HeritageRepository.cachedMap === null) {
        HeritageRepository.cachedMap = HeritageRepository.buildMap(list);
      }
      const result: HeritageLoadResult = {
        list: list,
        byId: HeritageRepository.cachedMap,
        isMock: false
      };
      return result;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'load failed, fallback to mock: %{public}s', JSON.stringify(err));
      return HeritageRepository.mockResult();
    }
  }

  /** 预览/加载失败兜底结果（同一份 mock 数组与映射） */
  static mockResult(): HeritageLoadResult {
    if (HeritageRepository.cachedMockMap === null) {
      HeritageRepository.cachedMockMap = HeritageRepository.buildMap(MOCK_HERITAGES);
    }
    const result: HeritageLoadResult = {
      list: MOCK_HERITAGES,
      byId: HeritageRepository.cachedMockMap,
      isMock: true
    };
    return result;
  }

  private static buildMap(list: Heritage[]): Map<string, Heritage> {
    const map: Map<string, Heritage> = new Map();
    for (let i = 0; i < list.length; i++) {
      map.set(list[i].id, list[i]);
    }
    return map;
  }
}
