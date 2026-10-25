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

/**
 * LWW 冲突判定（M6.3 合并规则原语，L13 从 SyncService 抽出为纯函数）。
 *
 * 规则：版本时间大者胜；完全相等时 deviceId 字典序**小**者胜
 * （确定性兜底：两端同时写入也收敛到同一条，不来回覆盖）。
 * 同一函数也用于「实体 updatedAt vs 墓碑 deletedAt」的比较——墓碑用 deletedAt 作版本时间。
 * 返回 true 表示远端版本胜出，应采纳远端（或维持远端删除）。
 */
export function lwwRemoteWins(localUpdatedAt: number, localDeviceId: string,
  remoteUpdatedAt: number, remoteDeviceId: string): boolean {
  if (remoteUpdatedAt !== localUpdatedAt) {
    return remoteUpdatedAt > localUpdatedAt;
  }
  return remoteDeviceId < localDeviceId;
}
