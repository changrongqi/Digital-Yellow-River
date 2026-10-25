/**
 * 路由工具（L6）：统一封装 router 的 push/back/getParams 与异常处理。
 *
 * 背景：各页面此前各自 try/catch（Discovery/Favorites 未包、其它页面各自写一份），
 * 异常处理口径不一致；`router` 的 pushUrl/back/getParams 在 HarmonyOS NEXT 已标记 deprecated，
 * 但当前迁移 Navigation 成本高，按计划保留为已知技术债（O3 基线）。
 *
 * 约定：
 * - 所有页面跳转/返回/取参统一走本工具，页面不再直接调用 router；
 * - 所有 SDK 调用包 try/catch，失败只记日志，不阻塞用户操作；
 * - 路由参数用显式 `RouteParams` 接口，避免 ArkTS 无类型对象字面量。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'RouterUtil';

/** 项目路由参数集合（只增不改；未使用的字段保持 undefined） */
export interface RouteParams {
  id?: string;         // 遗址 id（Detail）
  noteId?: string;     // 笔记 id（NoteEdit，空串=新建）
  heritageId?: string; // 遗址 id（EventDetail）
  eventIndex?: number; // 事件下标（EventDetail）
}

export class RouterUtil {
  /** 打开页面（params 可选） */
  static push(url: string, params?: RouteParams): void {
    try {
      router.pushUrl({ url: url, params: params });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'push %{public}s failed: %{public}s', url, JSON.stringify(err));
    }
  }

  /** 返回上一页 */
  static back(): void {
    try {
      router.back();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'back failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 读取当前页路由参数（异常/无参数返回 undefined；页面用下标读取单个字段） */
  static getParams(): Record<string, Object> | undefined {
    try {
      return router.getParams() as Record<string, Object> | undefined;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'getParams failed: %{public}s', JSON.stringify(err));
      return undefined;
    }
  }
}
