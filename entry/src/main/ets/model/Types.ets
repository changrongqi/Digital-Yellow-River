/**
 * 数据模型：基础枚举定义
 * 三个组织维度：遗址年代 / 遗址类型 / 沿线城市
 *
 * 注意：枚举成员名必须为合法标识符（英文），值使用中文字符串。
 */

/**
 * 遗址年代（年代轴线：仰韶 → 龙山 → 夏商 → 周 → 汉唐 → 宋）
 */
export enum HeritageEra {
  YANGSHAO = '仰韶',
  LONGSHAN = '龙山',
  XIA_SHANG = '夏商',
  ZHOU = '周',
  HAN_TANG = '汉唐',
  SONG = '宋'
}

/**
 * 遗址类型
 */
export enum HeritageType {
  CAPITAL_SITE = '都城遗址',
  TOMB_GROUP = '墓葬群',
  KILN_SITE = '窑址',
  ANCIENT_BUILDING = '古建筑'
}

/**
 * 沿线城市
 */
export enum HeritageCity {
  SANMENXIA = '三门峡',
  LUOYANG = '洛阳',
  ZHENGZHOU = '郑州',
  KAIFENG = '开封',
  PUYANG = '濮阳',
  ANYANG = '安阳'
}

/**
 * 枚举值校验辅助：judge 字符串是否为合法枚举值。
 * 用于 preloaded JSON 解析时的显式类型校验（ArkTS 无反射，需手动校验）。
 */
export function isValidEra(value: string): boolean {
  return value === HeritageEra.YANGSHAO || value === HeritageEra.LONGSHAN ||
    value === HeritageEra.XIA_SHANG || value === HeritageEra.ZHOU ||
    value === HeritageEra.HAN_TANG || value === HeritageEra.SONG;
}

export function isValidType(value: string): boolean {
  return value === HeritageType.CAPITAL_SITE || value === HeritageType.TOMB_GROUP ||
    value === HeritageType.KILN_SITE || value === HeritageType.ANCIENT_BUILDING;
}

export function isValidCity(value: string): boolean {
  return value === HeritageCity.SANMENXIA || value === HeritageCity.LUOYANG ||
    value === HeritageCity.ZHENGZHOU || value === HeritageCity.KAIFENG ||
    value === HeritageCity.PUYANG || value === HeritageCity.ANYANG;
}