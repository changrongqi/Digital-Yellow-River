/**
 * 工具函数（M4.0）：年代主题色系统（详情页视觉基调）。
 *
 * 设计说明（用户确认方向：年代主题色，克制低饱和，无无意义视觉糖）：
 * - 六个年代各一套主题色，取色自该年代的代表性器物/材质，形成文化隐喻：
 *   仰韶=彩陶红 / 龙山=黑陶灰 / 夏商=青铜绿 / 周=玄青 / 汉唐=鎏金赭 / 宋=青瓷；
 * - deep：横幅渐变起色、时间轴年份与节点、点缀强调；
 * - mid：横幅渐变止色（deep→mid 渐变构成英雄横幅）；
 * - soft：诗词卡浅底等大面积浅色容器；
 * - 饱和度刻意压低（避免高饱和视觉噪点），白字在 deep/mid 上对比度充足；
 * - 未匹配年代兜底 App 主棕色系，保证任何数据都有可用主题。
 *
 * 纯函数无状态，ArkTS 对象字面量逐字段对应 EraTheme 接口（踩坑 2）。
 */

import { HeritageEra } from '../model/Types';

/** 年代主题色（三档：深/中/浅） */
export interface EraTheme {
  deep: string;  // 深色：横幅渐变起、时间轴节点/年份、点缀
  mid: string;   // 中色：横幅渐变止
  soft: string;  // 浅色：诗词卡底等浅色容器
}

/** 兜底主题（App 主棕色系，未匹配年代时使用） */
const DEFAULT_THEME: EraTheme = { deep: '#6D4C41', mid: '#8D6E63', soft: '#EFEBE9' };

/** 按年代取主题色（era 为枚举中文字符串值；纯函数） */
export function getEraTheme(era: string): EraTheme {
  const theme: EraTheme = { deep: '', mid: '', soft: '' };
  if (era === HeritageEra.YANGSHAO) {
    // 彩陶红：仰韶彩陶的赭红陶色
    theme.deep = '#7A3B2E';
    theme.mid = '#A05B44';
    theme.soft = '#F5E7E1';
  } else if (era === HeritageEra.LONGSHAN) {
    // 黑陶灰：龙山黑陶的深灰磨光质感
    theme.deep = '#3A392F';
    theme.mid = '#5E5C4E';
    theme.soft = '#EFEEE8';
  } else if (era === HeritageEra.XIA_SHANG) {
    // 青铜绿：夏商青铜器的铜绿锈色
    theme.deep = '#405138';
    theme.mid = '#61784F';
    theme.soft = '#EAF0E5';
  } else if (era === HeritageEra.ZHOU) {
    // 玄青：周代礼器玉璧与青铜的深青
    theme.deep = '#2F4754';
    theme.mid = '#4C6B7D';
    theme.soft = '#E6EDF1';
  } else if (era === HeritageEra.HAN_TANG) {
    // 鎏金赭：汉唐鎏金器物的赭金
    theme.deep = '#7F5423';
    theme.mid = '#A87C3B';
    theme.soft = '#F5ECDC';
  } else if (era === HeritageEra.SONG) {
    // 青瓷：宋代青瓷的天青釉色
    theme.deep = '#466960';
    theme.mid = '#6F908A';
    theme.soft = '#E7F0EE';
  } else {
    return DEFAULT_THEME;
  }
  return theme;
}
