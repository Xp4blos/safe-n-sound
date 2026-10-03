import { DetectedEvent, SoundRecord } from './SoundModels';

export const FINGERPRINT_LENGTH: number = 29;

export interface CatalogOutcome {
  record: SoundRecord;
  isNew: boolean;
  shouldNotify: boolean;
}

// The remembered sounds and the rules for updating them. Pure logic: no storage, no native calls.
export class SoundCatalog {
  static readonly ALERT_COOLDOWN_MS: number = 10000;
  static readonly MAX_NAME_LENGTH: number = 40;
  static readonly MAX_RECENT: number = 20;

  private items: SoundRecord[];

  constructor(records: SoundRecord[]) {
    this.items = records;
  }

  // Tolerant loader: anything unreadable or malformed is dropped rather than thrown.
  static parse(json: string): SoundCatalog {
    let parsed: Object;
    try {
      parsed = JSON.parse(json) as Object;
    } catch (e) {
      return new SoundCatalog([]);
    }
    if (!(parsed instanceof Array)) {
      return new SoundCatalog([]);
    }
    const records: SoundRecord[] = [];
    for (const item of parsed as Object[]) {
      const record = SoundCatalog.toRecord(item);
      if (record !== undefined) {
        records.push(record);
      }
    }
    return new SoundCatalog(records);
  }

  private static numberArray(value: Object | undefined, length: number): number[] | undefined {
    if (!(value instanceof Array)) {
      return undefined;
    }
    const out: number[] = [];
    for (const v of value as Object[]) {
      if (typeof v !== 'number') {
        return undefined;
      }
      out.push(v as number);
    }
    if (length >= 0 && out.length !== length) {
      return undefined;
    }
    return out;
  }

  private static toRecord(item: Object): SoundRecord | undefined {
    if (item === null || typeof item !== 'object') {
      return undefined;
    }
    const o = item as Record<string, Object>;
    const fingerprint = SoundCatalog.numberArray(o['fingerprint'], FINGERPRINT_LENGTH);
    const recent = SoundCatalog.numberArray(o['recentMs'], -1);
    if (fingerprint === undefined || recent === undefined) {
      return undefined;
    }
    if (typeof o['id'] !== 'number' || typeof o['kind'] !== 'number' || typeof o['name'] !== 'string' ||
      typeof o['alertsEnabled'] !== 'boolean' || typeof o['timesHeard'] !== 'number' ||
      typeof o['lastSeenMs'] !== 'number' || typeof o['lastNotifiedMs'] !== 'number') {
      return undefined;
    }
    const record: SoundRecord = {
      id: o['id'] as number,
      kind: o['kind'] as number,
      fingerprint: fingerprint,
      name: o['name'] as string,
      alertsEnabled: o['alertsEnabled'] as boolean,
      timesHeard: o['timesHeard'] as number,
      lastSeenMs: o['lastSeenMs'] as number,
      lastNotifiedMs: o['lastNotifiedMs'] as number,
      recentMs: recent.slice(-SoundCatalog.MAX_RECENT)
    };
    return record;
  }

  serialize(): string {
    return JSON.stringify(this.items);
  }

  records(): SoundRecord[] {
    return this.items;
  }

  // Fingerprints in the same order as records(), for the native matcher.
  fingerprints(): number[][] {
    return this.items.map((r: SoundRecord): number[] => r.fingerprint);
  }

  // `matchIndex` is the native matcher's answer for this event (-1 = no match).
  registerEvent(ev: DetectedEvent, matchIndex: number, nowMs: number): CatalogOutcome {
    if (matchIndex >= 0 && matchIndex < this.items.length) {
      const record = this.items[matchIndex];
      record.timesHeard += 1;
      record.lastSeenMs = nowMs;
      record.recentMs.push(nowMs);
      if (record.recentMs.length > SoundCatalog.MAX_RECENT) {
        record.recentMs = record.recentMs.slice(-SoundCatalog.MAX_RECENT);
      }
      const cooledDown = record.lastNotifiedMs === 0 ||
        nowMs - record.lastNotifiedMs >= SoundCatalog.ALERT_COOLDOWN_MS;
      const shouldNotify = record.name !== '' && record.alertsEnabled && cooledDown;
      if (shouldNotify) {
        record.lastNotifiedMs = nowMs;
      }
      const outcome: CatalogOutcome = { record: record, isNew: false, shouldNotify: shouldNotify };
      return outcome;
    }

    let maxId = 0;
    for (const r of this.items) {
      maxId = Math.max(maxId, r.id);
    }
    const created: SoundRecord = {
      id: maxId + 1, kind: ev.kind, fingerprint: ev.fingerprint.slice(), name: '', alertsEnabled: true,
      timesHeard: 1, lastSeenMs: nowMs, lastNotifiedMs: 0, recentMs: [nowMs]
    };
    this.items.push(created);
    const outcome: CatalogOutcome = { record: created, isNew: true, shouldNotify: false };
    return outcome;
  }

  rename(id: number, name: string): void {
    const record = this.find(id);
    if (record !== undefined) {
      record.name = name.trim().slice(0, SoundCatalog.MAX_NAME_LENGTH).trim();
    }
  }

  setAlerts(id: number, enabled: boolean): void {
    const record = this.find(id);
    if (record !== undefined) {
      record.alertsEnabled = enabled;
    }
  }

  private find(id: number): SoundRecord | undefined {
    return this.items.find((r: SoundRecord): boolean => r.id === id);
  }
}
