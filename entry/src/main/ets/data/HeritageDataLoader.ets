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
import { Heritage, HeritageDetail, Poem, SpecItem, Artifact } from '../model/Heritage';

const DOMAIN = 0x0000;
const TAG = 'HeritageDataLoader';
const DATA_FILE = 'heritage_data.json';

export class HeritageDataLoader {
  /**
   * 进程内缓存：rawfile 预置数据是只读的，一次解析全程复用。
   * 详情页、M2 收藏页、M4 推荐都只走内存，避免重复读 rawfile + 全量解析（R2）。
   * 注意：返回的是同一份数组引用，调用方只读、不得就地修改。
   */
  private static cachedList: Heritage[] | null = null;

  /**
   * 从 rawfile 读取并解析全部预置文化条目（带进程内缓存）。
   * 单条数据非法/解析失败时跳过该条并记录日志，不中断整体加载（UI 层兜底）。
   */
  static async loadHeritageList(context: common.Context): Promise<Heritage[]> {
    const cached: Heritage[] | null = HeritageDataLoader.cachedList;
    if (cached !== null) {
      return cached;
    }
    const resourceManager = context.resourceManager;
    const rawFile: Uint8Array = await resourceManager.getRawFileContent(DATA_FILE);
    const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(rawFile));
    const result: Heritage[] = HeritageDataLoader.parseHeritageList(text, DATA_FILE);
    // 踩坑第 17 条：整表解析出 0 条 = 加载失败（rawfile 读不到/文件损坏/枚举整体漂移），
    // 必须抛异常让调用方走兜底（预览器注入 mock），否则「失败」被静默成「空数据」，
    // 页面只显示「预置数据为空」、mock 兜底永不触发（M1.6 曾因此回归）。空结果不入缓存。
    if (result.length === 0) {
      throw new Error(`parse 0 heritages from ${DATA_FILE}, treat as load failure`);
    }
    HeritageDataLoader.cachedList = result;
    return result;
  }

  /**
   * 唯一解析入口：JSON 文本 → Heritage[]。
   *
   * rawfile 数据与预览兜底数据（MockHeritages）都必须走这里：
   * 这样两份数据共用同一套字段校验 / 兜底 / 枚举合法性检查，
   * 结构一旦漂移会立刻在解析结果里暴露，不会出现「预览器能跑、真机不对」（R3）。
   *
   * @param source 数据来源标识，仅用于日志定位
   */
  static parseHeritageList(text: string, source: string): Heritage[] {
    const result: Heritage[] = [];
    let parsed: object[] = [];
    try {
      parsed = JSON.parse(text) as object[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'json parse failed (%{public}s): %{public}s', source, JSON.stringify(err));
      return result;
    }
    for (let i = 0; i < parsed.length; i++) {
      const item = HeritageDataLoader.parseHeritage(parsed[i], i);
      if (item !== null) {
        result.push(item);
      }
    }
    hilog.info(DOMAIN, TAG, 'loaded %{public}d heritages from %{public}s', result.length, source);
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
        tourism: HeritageDataLoader.getStr(detailObj, 'tourism'),
        highlights: HeritageDataLoader.getStrArray(detailObj, 'highlights'),
        specs: HeritageDataLoader.getSpecArray(detailObj, 'specs'),
        artifacts: HeritageDataLoader.getArtifactArray(detailObj, 'artifacts')
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

  /** M1.7：解析遗址档案键值数组（字段缺失/非法项兜底为空） */
  private static getSpecArray(rec: Record<string, Object>, key: string): SpecItem[] {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return [];
    }
    const arr = v as Object[];
    const result: SpecItem[] = [];
    for (let i = 0; i < arr.length; i++) {
      const obj = arr[i] as Record<string, Object>;
      const label: string = HeritageDataLoader.getStr(obj, 'label');
      if (label === '') {
        continue; // 无名称的档案项跳过
      }
      const spec: SpecItem = {
        label: label,
        value: HeritageDataLoader.getStr(obj, 'value')
      };
      result.push(spec);
    }
    return result;
  }

  /** M1.7：解析代表性出土文物数组（无名称项跳过） */
  private static getArtifactArray(rec: Record<string, Object>, key: string): Artifact[] {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return [];
    }
    const arr = v as Object[];
    const result: Artifact[] = [];
    for (let i = 0; i < arr.length; i++) {
      const obj = arr[i] as Record<string, Object>;
      const name: string = HeritageDataLoader.getStr(obj, 'name');
      if (name === '') {
        continue; // 无名称的文物项跳过
      }
      const artifact: Artifact = {
        name: name,
        desc: HeritageDataLoader.getStr(obj, 'desc')
      };
      result.push(artifact);
    }
    return result;
  }
}