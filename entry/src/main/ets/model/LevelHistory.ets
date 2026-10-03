// Rolling record of the sound level over the last 8 seconds, one bar per 125 ms slot, for the
// equaliser-style chart. Pure logic: the caller supplies the clock.
export class LevelHistory {
  static readonly BAR_MS: number = 125;
  static readonly BAR_COUNT: number = 64; // 64 x 125 ms = 8 s
  static readonly FLOOR_DB: number = -70; // at or below this a bar is empty
  static readonly CEIL_DB: number = -10; // at or above this a bar is full

  private values: number[] = [];
  private lastSlot: number = -1;

  constructor() {
    this.reset();
  }

  reset(): void {
    this.values = [];
    for (let i = 0; i < LevelHistory.BAR_COUNT; i++) {
      this.values.push(0);
    }
    this.lastSlot = -1;
  }

  // `db` is the level in dBFS. Within one slot the loudest value wins.
  push(db: number, nowMs: number): void {
    const slot = Math.floor(nowMs / LevelHistory.BAR_MS);
    if (this.lastSlot < 0) {
      this.lastSlot = slot;
    }
    if (slot > this.lastSlot) {
      const shift = Math.min(slot - this.lastSlot, LevelHistory.BAR_COUNT);
      this.values = this.values.slice(shift);
      for (let i = 0; i < shift; i++) {
        this.values.push(0);
      }
      this.lastSlot = slot;
    }
    const last = LevelHistory.BAR_COUNT - 1;
    this.values[last] = Math.max(this.values[last], LevelHistory.normalise(db));
  }

  // Oldest first, newest last, each 0..1.
  bars(): number[] {
    return this.values.slice();
  }

  private static normalise(db: number): number {
    const v = (db - LevelHistory.FLOOR_DB) / (LevelHistory.CEIL_DB - LevelHistory.FLOOR_DB);
    return Math.min(1, Math.max(0, v));
  }
}
