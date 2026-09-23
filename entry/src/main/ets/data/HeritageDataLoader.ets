/**
 * 预置数据层：rawfile/heritage_data.json → Heritage[]
 *
 * 踩坑提醒（计划书第 6 节）：
 * 1. ArkTS 无反射，JSON.parse 结果必须逐字段显式转换到 model 类型；
 * 2. 字段缺失/值为 null 时兜底返回空串/空数组（不做默认值幻觉）；
 * 3. 枚举字段做合法值校验（isValid*），非法条目跳过并告警，保证其余数据可用；
 * 4. 全程不使用 any。
 */

import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HeritageEra, HeritageType, HeritageCity, isValidEra, isValidType, isValidCity } from '../model/Types';
import { Heritage, HeritageDetail, Poem } from '../model/Heritage';

const DOMAIN = 0x0000;
const TAG = 'HeritageDataLoader';
const DATA_FILE = 'heritage_data.json';

export class HeritageDataLoader {
  /**
   * 从 rawfile 读取并解析全部预置文化条目。
   * 单条数据非法/解析失败时跳过该条并记录日志，不中断整体加载（UI 层兜底）。
   */
  static async loadHeritageList(context: common.Context): Promise<Heritage[]> {
    const resourceManager = context.resourceManager;
    const rawFile: Uint8Array = await resourceManager.getRawFileContent(DATA_FILE);
    const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(rawFile));
    const parsed: object[] = JSON.parse(text) as object[];
    const result: Heritage[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = HeritageDataLoader.parseHeritage(parsed[i], i);
      if (item !== null) {
        result.push(item);
      }
    }
    hilog.info(DOMAIN, TAG, 'loaded %{public}d heritages from %{public}s', result.length, DATA_FILE);
    return result;
  }

  /**
   * 解析单条 Heritage；不合法返回 null。
   */
  private static parseHeritage(obj: object, index: number): Heritage | null {
    try {
      const rec = obj as Record<string, Object>;
      const id: string = HeritageDataLoader.getStr(rec, 'id');
      const eraStr: string = HeritageDataLoader.getStr(rec, 'era');
      const typeStr: string = HeritageDataLoader.getStr(rec, 'type');
      const cityStr: string = HeritageDataLoader.getStr(rec, 'city');
      if (id === '' || !isValidEra(eraStr) || !isValidType(typeStr) || !isValidCity(cityStr)) {
        hilog.warn(DOMAIN, TAG, 'skip invalid item #%{public}d', index);
        return null;
      }

      const detailRec = rec['detail'] as Record<string, Object> | undefined;
      const emptyDetail: Record<string, Object> = {};
      if (detailRec === undefined || detailRec === null) {
        hilog.warn(DOMAIN, TAG, 'item %{public}s has no detail, use empty', id);
      }
      const detailObj: Record<string, Object> = detailRec === undefined ? emptyDetail : detailRec;

      const detail: HeritageDetail = {
        intro: HeritageDataLoader.getStr(detailObj, 'intro'),
        discovery: HeritageDataLoader.getStr(detailObj, 'discovery'),
        events: HeritageDataLoader.getStrArray(detailObj, 'events'),
        poems: HeritageDataLoader.getPoemArray(detailObj, 'poems'),
        tourism: HeritageDataLoader.getStr(detailObj, 'tourism')
      };

      const item: Heritage = {
        id: id,
        name: HeritageDataLoader.getStr(rec, 'name'),
        era: eraStr as HeritageEra,
        type: typeStr as HeritageType,
        city: cityStr as HeritageCity,
        coverImage: HeritageDataLoader.getStr(rec, 'coverImage'),
        summary: HeritageDataLoader.getStr(rec, 'summary'),
        detail: detail
      };
      return item;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parse error #%{public}d, detail: %{public}s', index, JSON.stringify(err));
      return null;
    }
  }

  private static getStr(rec: Record<string, Object>, key: string): string {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return '';
    }
    return String(v);
  }

  private static getStrArray(rec: Record<string, Object>, key: string): string[] {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return [];
    }
    const arr = v as Object[];
    const result: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      result.push(String(arr[i]));
    }
    return result;
  }

  private static getPoemArray(rec: Record<string, Object>, key: string): Poem[] {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return [];
    }
    const arr = v as Object[];
    const result: Poem[] = [];
    for (let i = 0; i < arr.length; i++) {
      const poemObj = arr[i] as Record<string, Object>;
      const poem: Poem = {
        title: HeritageDataLoader.getStr(poemObj, 'title'),
        author: HeritageDataLoader.getStr(poemObj, 'author'),
        content: HeritageDataLoader.getStr(poemObj, 'content')
      };
      result.push(poem);
    }
    return result;
  }
}