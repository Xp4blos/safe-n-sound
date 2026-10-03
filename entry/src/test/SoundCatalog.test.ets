import { describe, it, expect } from '@ohos/hypium';
import { SoundCatalog, CatalogOutcome } from '../main/ets/model/SoundCatalog';
import { DetectedEvent, SoundRecord } from '../main/ets/model/SoundModels';

function fingerprint(seed: number): number[] {
  const fp: number[] = [];
  for (let i = 0; i < 29; i++) {
    fp.push(seed + i / 100);
  }
  return fp;
}

function event(seed: number, startSec: number): DetectedEvent {
  const ev: DetectedEvent = { startSec: startSec, durationSec: 1, kind: 0, fingerprint: fingerprint(seed) };
  return ev;
}

function record(id: number, fp: number[]): SoundRecord {
  const r: SoundRecord = {
    id: id, kind: 0, fingerprint: fp, name: '', alertsEnabled: true, timesHeard: 1,
    lastSeenMs: 1000, lastNotifiedMs: 0, recentMs: [1000]
  };
  return r;
}

export default function soundCatalogTest() {
  describe('soundCatalog', () => {
    it('new_events_create_unnamed_records_with_increasing_ids', 0, () => {
      const catalog = new SoundCatalog([]);
      const first: CatalogOutcome = catalog.registerEvent(event(1, 0), -1, 100000);
      const second: CatalogOutcome = catalog.registerEvent(event(2, 0), -1, 100500);
      expect(first.isNew).assertTrue();
      expect(first.shouldNotify).assertFalse();
      expect(first.record.id).assertEqual(1);
      expect(first.record.name).assertEqual('');
      expect(first.record.alertsEnabled).assertTrue();
      expect(second.record.id).assertEqual(2);
      expect(catalog.records().length).assertEqual(2);
    });

    it('matched_event_increments_times_heard', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      const again = catalog.registerEvent(event(1, 5), 0, 105000);
      expect(again.isNew).assertFalse();
      expect(again.record.timesHeard).assertEqual(2);
      expect(again.record.lastSeenMs).assertEqual(105000);
      expect(catalog.records().length).assertEqual(1);
    });

    it('named_sound_notifies_once_per_cooldown', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      catalog.rename(1, 'Doorbell');
      expect(catalog.registerEvent(event(1, 0), 0, 200000).shouldNotify).assertTrue();
      expect(catalog.registerEvent(event(1, 0), 0, 205000).shouldNotify).assertFalse();
      expect(catalog.registerEvent(event(1, 0), 0, 211000).shouldNotify).assertTrue();
    });

    it('named_sound_with_alerts_off_never_notifies', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      catalog.rename(1, 'Doorbell');
      catalog.setAlerts(1, false);
      expect(catalog.registerEvent(event(1, 0), 0, 200000).shouldNotify).assertFalse();
      expect(catalog.registerEvent(event(1, 0), 0, 300000).shouldNotify).assertFalse();
    });

    it('unnamed_sound_never_notifies', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      expect(catalog.registerEvent(event(1, 0), 0, 200000).shouldNotify).assertFalse();
    });

    it('rename_trims_and_limits_and_clears', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      catalog.rename(1, '  Doorbell  ');
      expect(catalog.records()[0].name).assertEqual('Doorbell');
      catalog.rename(1, '   ');
      expect(catalog.records()[0].name).assertEqual('');
      catalog.rename(1, 'x'.repeat(100));
      expect(catalog.records()[0].name.length).assertEqual(40);
    });

    it('out_of_range_match_index_creates_a_new_record', 0, () => {
      const catalog = new SoundCatalog([]);
      const out = catalog.registerEvent(event(1, 0), 7, 100000);
      expect(out.isNew).assertTrue();
      expect(catalog.records().length).assertEqual(1);
    });

    it('recent_timestamps_are_capped', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      for (let i = 1; i <= 30; i++) {
        catalog.registerEvent(event(1, 0), 0, 100000 + i * 1000);
      }
      expect(catalog.records()[0].recentMs.length).assertEqual(20);
      expect(catalog.records()[0].timesHeard).assertEqual(31);
    });

    it('parse_of_invalid_json_gives_empty_catalog', 0, () => {
      expect(SoundCatalog.parse('{not json').records().length).assertEqual(0);
      expect(SoundCatalog.parse('').records().length).assertEqual(0);
      expect(SoundCatalog.parse('{"a":1}').records().length).assertEqual(0);
    });

    it('parse_drops_records_with_wrong_fingerprint_length', 0, () => {
      const bad = record(1, fingerprint(1).slice(0, 28));
      const good = record(2, fingerprint(2));
      const catalog = SoundCatalog.parse(JSON.stringify([bad, good]));
      expect(catalog.records().length).assertEqual(1);
      expect(catalog.records()[0].id).assertEqual(2);
    });

    it('parse_drops_records_with_missing_fields', 0, () => {
      expect(SoundCatalog.parse('[{"id":1}]').records().length).assertEqual(0);
    });

    it('serialize_then_parse_round_trips', 0, () => {
      const catalog = new SoundCatalog([]);
      catalog.registerEvent(event(1, 0), -1, 100000);
      catalog.rename(1, 'Alarm');
      const copy = SoundCatalog.parse(catalog.serialize());
      expect(copy.records().length).assertEqual(1);
      expect(copy.records()[0].name).assertEqual('Alarm');
      expect(copy.fingerprints()[0].length).assertEqual(29);
    });
  });
}
