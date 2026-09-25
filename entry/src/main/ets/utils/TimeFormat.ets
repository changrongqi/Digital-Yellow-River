/**
 * 工具函数（M2.4）：时间戳格式化。
 *
 * 计划书 §3 分层：utils 存放通用工具函数（后续 M4 推荐算法等也落此层）。
 * 纯函数、无状态，被 Favorites / NoteEdit / Detail 三页共用，避免各页重复实现。
 */

/** 毫秒时间戳 → yyyy-MM-dd */
export function formatDate(ts: number): string {
  const d: Date = new Date(ts);
  const month: number = d.getMonth() + 1;
  const day: number = d.getDate();
  const monthStr: string = month < 10 ? `0${month}` : `${month}`;
  const dayStr: string = day < 10 ? `0${day}` : `${day}`;
  return `${d.getFullYear()}-${monthStr}-${dayStr}`;
}

/** 毫秒时间戳 → yyyy-MM-dd HH:mm */
export function formatDateTime(ts: number): string {
  const d: Date = new Date(ts);
  const hour: number = d.getHours();
  const minute: number = d.getMinutes();
  const hourStr: string = hour < 10 ? `0${hour}` : `${hour}`;
  const minuteStr: string = minute < 10 ? `0${minute}` : `${minute}`;
  return `${formatDate(ts)} ${hourStr}:${minuteStr}`;
}
