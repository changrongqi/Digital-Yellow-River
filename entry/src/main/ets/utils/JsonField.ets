/**
 * JSON 字段读取助手（M4）：统一类型校验与兜底，避免各服务/加载器各写一份 getStr/getNum/getStrArray。
 *
 * 规则：
 * - 字符串字段：字符串原样返回；数字/布尔按字符串返回（兼容存量数据）；对象/数组等非法类型返回空串；
 * - 数字字段：仅接受 number，其余返回 0；
 * - 字符串数组：仅接受数组，逐项保留 string/number/boolean（转字符串），跳过对象/数组等非法项。
 * 全程不使用 any、不使用解构赋值。
 */

export class JsonField {
  /** 读取字符串字段（缺失/非法返回空串） */
  static getStr(rec: Record<string, Object>, key: string): string {
    const v: Object | undefined = rec[key];
    if (v === undefined || v === null) {
      return '';
    }
    if (typeof v === 'string') {
      return v as string;
    }
    if (typeof v === 'number' || typeof v === 'boolean') {
      return String(v);
    }
    return '';
  }

  /** 读取数字字段（缺失/非法返回 0） */
  static getNum(rec: Record<string, Object>, key: string): number {
    const v: Object | undefined = rec[key];
    if (typeof v === 'number') {
      return v as number;
    }
    return 0;
  }

  /** 读取字符串数组（缺失/非法返回空数组，非法项跳过） */
  static getStrArray(rec: Record<string, Object>, key: string): string[] {
    const v: Object | undefined = rec[key];
    if (!Array.isArray(v)) {
      return [];
    }
    const arr = v as Object[];
    const result: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item: Object = arr[i];
      if (typeof item === 'string') {
        result.push(item as string);
      } else if (typeof item === 'number' || typeof item === 'boolean') {
        result.push(String(item));
      }
    }
    return result;
  }
}
