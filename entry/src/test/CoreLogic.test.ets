/**
 * 本地单元测试（M11）：LWW 版本推进、JSON 字段助手、时间格式化、主题色兜底。
 * 全部为纯函数，不依赖设备/资源/网络，可在 Local Test 下直接执行。
 */

import { describe, it, expect } from '@ohos/hypium';
import { nextUpdatedAt } from '../main/ets/utils/LwwVersion';
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
