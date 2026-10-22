/**
 * LWW 版本推进（M1 第二轮优化）：保证新版本严格大于旧版本。
 *
 * 背景：记录版本目前使用墙钟 Date.now()。设备时钟回拨、或同一毫秒内连续编辑时，
 * 新版本可能不大于旧版本，导致本地新编辑在同键 LWW 中输给旧版本。
 * 规则：正常取 now；若 now 不大于 previous，则取 previous + 1，保证严格递增。
 */
export function nextUpdatedAt(previous: number, now: number): number {
  return now > previous ? now : previous + 1;
}
