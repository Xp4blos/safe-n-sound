import { describe, it, expect } from '@ohos/hypium';
import { LevelHistory } from '../main/ets/model/LevelHistory';

export default function levelHistoryTest() {
  describe('levelHistory', () => {
    it('starts_with_a_full_row_of_zero_bars', 0, () => {
      const bars = new LevelHistory().bars();
      expect(bars.length).assertEqual(LevelHistory.BAR_COUNT);
      expect(bars.every((b: number): boolean => b === 0)).assertTrue();
    });

    it('loud_level_fills_the_newest_bar_and_quiet_level_is_zero', 0, () => {
      const loud = new LevelHistory();
      loud.push(-10, 1000);
      expect(loud.bars()[LevelHistory.BAR_COUNT - 1]).assertEqual(1);
      const quiet = new LevelHistory();
      quiet.push(-100, 1000);
      expect(quiet.bars()[LevelHistory.BAR_COUNT - 1]).assertEqual(0);
    });

    it('levels_are_clamped_to_zero_one', 0, () => {
      const h = new LevelHistory();
      h.push(30, 1000);
      expect(h.bars()[LevelHistory.BAR_COUNT - 1]).assertEqual(1);
      h.push(-500, 2000);
      expect(h.bars()[LevelHistory.BAR_COUNT - 1]).assertEqual(0);
    });

    it('keeps_the_loudest_value_within_one_bar', 0, () => {
      const h = new LevelHistory();
      h.push(-60, 1000);
      h.push(-20, 1050);
      h.push(-70, 1100);
      const expected = (-20 - LevelHistory.FLOOR_DB) / (LevelHistory.CEIL_DB - LevelHistory.FLOOR_DB);
      expect(Math.abs(h.bars()[LevelHistory.BAR_COUNT - 1] - expected) < 1e-9).assertTrue();
    });

    it('new_time_slot_scrolls_older_bars_left', 0, () => {
      const h = new LevelHistory();
      h.push(-10, 1000);
      h.push(-100, 1000 + LevelHistory.BAR_MS);
      const bars = h.bars();
      expect(bars[LevelHistory.BAR_COUNT - 2]).assertEqual(1);
      expect(bars[LevelHistory.BAR_COUNT - 1]).assertEqual(0);
    });

    it('silence_gap_inserts_empty_bars_and_old_data_falls_off', 0, () => {
      const h = new LevelHistory();
      h.push(-10, 1000);
      h.push(-100, 1000 + 3 * LevelHistory.BAR_MS);
      expect(h.bars()[LevelHistory.BAR_COUNT - 4]).assertEqual(1);
      h.push(-100, 1000 + 1000 * LevelHistory.BAR_MS);
      expect(h.bars().every((b: number): boolean => b === 0)).assertTrue();
    });

    it('window_covers_eight_seconds', 0, () => {
      expect(LevelHistory.BAR_COUNT * LevelHistory.BAR_MS).assertEqual(8000);
    });

    it('reset_clears_the_chart', 0, () => {
      const h = new LevelHistory();
      h.push(-10, 1000);
      h.reset();
      expect(h.bars().every((b: number): boolean => b === 0)).assertTrue();
    });
  });
}
