/**
 * 本地单元测试（M11）：LWW 版本推进、JSON 字段助手、时间格式化、主题色兜底。
 * 全部为纯函数，不依赖设备/资源/网络，可在 Local Test 下直接执行。
 */

import { describe, it, expect } from '@ohos/hypium';
import { nextUpdatedAt, lwwRemoteWins } from '../main/ets/utils/LwwVersion';
import { JsonField } from '../main/ets/utils/JsonField';
import { formatDate, formatDateTime } from '../main/ets/utils/TimeFormat';
import { getThemeColor, THEME_PALETTE } from '../main/ets/model/Theme';

export default function coreLogicTest() {
  describe('LwwVersion', () => {
    it('nowGreaterThanPrevious', 0, () => {
      expect(nextUpdatedAt(100, 200)).assertEqual(200);
    });
    it('sameMillisecondAdvancesByOne', 0, () => {
      expect(nextUpdatedAt(200, 200)).assertEqual(201);
    });
    it('clockRollbackAdvancesByOne', 0, () => {
      expect(nextUpdatedAt(500, 120)).assertEqual(501);
    });
    it('zeroPreviousUsesNow', 0, () => {
      expect(nextUpdatedAt(0, 88)).assertEqual(88);
    });
  });

  describe('LwwRemoteWins', () => {
    it('remoteNewerWins', 0, () => {
      expect(lwwRemoteWins(100, 'dev-a', 200, 'dev-b')).assertTrue();
    });
    it('remoteOlderLoses', 0, () => {
      expect(lwwRemoteWins(200, 'dev-a', 100, 'dev-b')).assertFalse();
    });
    it('tieSmallerDeviceIdWins', 0, () => {
      // 时间完全相同 → deviceId 字典序小者胜（确定性兜底）
      expect(lwwRemoteWins(200, 'dev-b', 200, 'dev-a')).assertTrue();
    });
    it('tieLargerDeviceIdLoses', 0, () => {
      expect(lwwRemoteWins(200, 'dev-a', 200, 'dev-b')).assertFalse();
    });
    it('identicalVersionAndDeviceLoses', 0, () => {
      // 完全同版本同设备：不是「更新」，不采纳远端，避免无意义覆盖
      expect(lwwRemoteWins(200, 'dev-a', 200, 'dev-a')).assertFalse();
    });
    it('remoteEditNewerThanLocalTombstoneWins', 0, () => {
      // 实体 updatedAt vs 墓碑 deletedAt：编辑晚于删除 → 采纳远端实体，不静默丢失
      expect(lwwRemoteWins(200, 'tomb-dev', 300, 'edit-dev')).assertTrue();
    });
    it('remoteEditOlderThanLocalTombstoneKeepsDeleted', 0, () => {
      // 远端记录早于本地删除 → 维持删除，离线旧记录不复活
      expect(lwwRemoteWins(300, 'tomb-dev', 200, 'old-dev')).assertFalse();
    });
    it('tombstoneTieFallsBackToDeviceId', 0, () => {
      expect(lwwRemoteWins(300, 'dev-b', 300, 'dev-a')).assertTrue();
      expect(lwwRemoteWins(300, 'dev-a', 300, 'dev-b')).assertFalse();
    });
    it('bothDirectionsNeverDisagree', 0, () => {
      // 同一对版本最多只有一方胜出，保证双端收敛而不是来回覆盖
      // 本机 dev-a / 远端 dev-b：远端 id 更大，平局时远端不赢
      const forward: boolean = lwwRemoteWins(100, 'dev-a', 100, 'dev-b');
      // 本机 dev-b / 远端 dev-a：远端 id 更小，平局时远端赢
      const backward: boolean = lwwRemoteWins(100, 'dev-b', 100, 'dev-a');
      expect(forward).assertFalse();
      expect(backward).assertTrue();
    });
  });

  describe('JsonField', () => {
    it('getStrKeepsStringAndCoercesPrimitive', 0, () => {
      // ArkTS 禁止无类型对象字面量，测试数据用 JSON.parse 构造 Record
      const rec: Record<string, Object> = JSON.parse(
        '{"s":"文本","n":42,"b":true,"bad":{"nested":1}}') as Record<string, Object>;
      expect(JsonField.getStr(rec, 's')).assertEqual('文本');
      expect(JsonField.getStr(rec, 'n')).assertEqual('42');
      expect(JsonField.getStr(rec, 'b')).assertEqual('true');
      expect(JsonField.getStr(rec, 'bad')).assertEqual('');
      expect(JsonField.getStr(rec, 'missing')).assertEqual('');
    });
    it('getNumOnlyAcceptsNumber', 0, () => {
      const rec: Record<string, Object> = JSON.parse('{"n":7,"s":"7"}') as Record<string, Object>;
      expect(JsonField.getNum(rec, 'n')).assertEqual(7);
      expect(JsonField.getNum(rec, 's')).assertEqual(0);
      expect(JsonField.getNum(rec, 'missing')).assertEqual(0);
    });
    it('getStrArrayFiltersInvalidItems', 0, () => {
      const rec: Record<string, Object> = JSON.parse(
        '{"arr":["甲",2,true,{"x":1}],"bad":"not-array"}') as Record<string, Object>;
      const arr: string[] = JsonField.getStrArray(rec, 'arr');
      expect(arr.length).assertEqual(3);
      expect(arr[0]).assertEqual('甲');
      expect(arr[1]).assertEqual('2');
      expect(arr[2]).assertEqual('true');
      expect(JsonField.getStrArray(rec, 'bad').length).assertEqual(0);
      expect(JsonField.getStrArray(rec, 'missing').length).assertEqual(0);
    });
  });

  describe('TimeFormat', () => {
    it('formatDatePadsMonthAndDay', 0, () => {
      const ts: number = new Date(2026, 0, 2, 3, 4).getTime();
      expect(formatDate(ts)).assertEqual('2026-01-02');
    });
    it('formatDateTimePadsHourAndMinute', 0, () => {
      const ts: number = new Date(2026, 2, 5, 8, 7).getTime();
      expect(formatDateTime(ts)).assertEqual('2026-03-05 08:07');
    });
  });

  describe('ThemePalette', () => {
    it('returnsPaletteColorByIndex', 0, () => {
      expect(getThemeColor(0)).assertEqual(THEME_PALETTE[0]);
      expect(getThemeColor(1)).assertEqual(THEME_PALETTE[1]);
    });
    it('wrapsOutOfRangeIndexAndFallsBackForNegative', 0, () => {
      expect(getThemeColor(THEME_PALETTE.length)).assertEqual(THEME_PALETTE[0]);
      expect(getThemeColor(THEME_PALETTE.length + 2)).assertEqual(THEME_PALETTE[2]);
      expect(getThemeColor(-1)).assertEqual(THEME_PALETTE[0]);
    });
  });
}
