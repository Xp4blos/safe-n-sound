import { describe, it, expect } from '@ohos/hypium';
import { SoundCatalog } from '../main/ets/model/SoundCatalog';
import { DetectedEvent, MatchResult } from '../main/ets/model/SoundModels';
import { AlertPort, MatcherPort, SavePort, SoundPipeline } from '../main/ets/services/SoundPipeline';

class FakeMatcher implements MatcherPort {
  answers: number[] = [];
  savedSeen: number = -1;
  private next: number = 0;

  matchFingerprint(fp: number[], saved: number[][]): MatchResult {
    this.savedSeen = saved.length;
    const index = this.next < this.answers.length ? this.answers[this.next] : -1;
    this.next++;
    const result: MatchResult = { index: index, score: index >= 0 ? 0.9 : 0 };
    return result;
  }
}

class FakeAlerts implements AlertPort {
  vibrations: number = 0;
  notified: string[] = [];

  vibrate(): void {
    this.vibrations++;
  }

  async notifyKnownSound(name: string): Promise<void> {
    this.notified.push(name);
  }
}

class FakeSaver implements SavePort {
  saves: number = 0;

  async save(): Promise<void> {
    this.saves++;
  }
}

function event(startSec: number): DetectedEvent {
  const fp: number[] = [];
  for (let i = 0; i < 29; i++) {
    fp.push(0.1);
  }
  const ev: DetectedEvent = { startSec: startSec, durationSec: 1, kind: 0, fingerprint: fp };
  return ev;
}

export default function soundPipelineTest() {
  describe('soundPipeline', () => {
    it('unknown_sound_is_added_vibrates_and_saves_without_notifying', 0, () => {
      const matcher = new FakeMatcher();
      const alerts = new FakeAlerts();
      const saver = new FakeSaver();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, matcher, alerts, saver);
      const outcomes = pipeline.handle([event(0)], 1000000);
      expect(outcomes.length).assertEqual(1);
      expect(outcomes[0].isNew).assertTrue();
      expect(alerts.vibrations).assertEqual(1);
      expect(alerts.notified.length).assertEqual(0);
      expect(saver.saves).assertEqual(1);
      expect(catalog.records().length).assertEqual(1);
    });

    it('named_sound_heard_again_notifies_with_its_name', 0, () => {
      const matcher = new FakeMatcher();
      matcher.answers = [-1, 0];
      const alerts = new FakeAlerts();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, matcher, alerts, new FakeSaver());
      pipeline.handle([event(0)], 1000000);
      catalog.rename(1, 'Doorbell');
      const outcomes = pipeline.handle([event(0)], 1100000);
      expect(outcomes[0].isNew).assertFalse();
      expect(alerts.notified.length).assertEqual(1);
      expect(alerts.notified[0]).assertEqual('Doorbell');
      expect(matcher.savedSeen).assertEqual(1);
    });

    it('every_detection_vibrates_but_rapid_repeats_notify_once', 0, () => {
      const matcher = new FakeMatcher();
      matcher.answers = [-1, 0, 0];
      const alerts = new FakeAlerts();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, matcher, alerts, new FakeSaver());
      pipeline.handle([event(0)], 1000000);
      catalog.rename(1, 'Alarm');
      pipeline.handle([event(0), event(2)], 1100000);
      expect(alerts.vibrations).assertEqual(3);
      expect(alerts.notified.length).assertEqual(1);
    });

    it('event_time_is_capture_start_plus_event_offset', 0, () => {
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, new FakeMatcher(), new FakeAlerts(), new FakeSaver());
      pipeline.handle([event(2.5)], 1000000);
      expect(catalog.records()[0].lastSeenMs).assertEqual(1002500);
    });

    it('event_starting_during_our_own_vibration_is_ignored', 0, () => {
      const alerts = new FakeAlerts();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, new FakeMatcher(), alerts, new FakeSaver());
      // First event at t=1000 s is handled at wall-clock 1002000 ms and vibrates the phone.
      pipeline.handle([event(1)], 1000000 - 1000, 1002000);
      // The motor's noise shows up as an event starting 0.5 s after the vibration began: ignore it.
      const outcomes = pipeline.handle([event(3)], 1000000 - 1000, 1003500);
      expect(outcomes.length).assertEqual(0);
      expect(alerts.vibrations).assertEqual(1);
      expect(catalog.records().length).assertEqual(1);
    });

    it('event_starting_after_the_vibration_window_is_handled', 0, () => {
      const alerts = new FakeAlerts();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, new FakeMatcher(), alerts, new FakeSaver());
      pipeline.handle([event(1)], 1000000 - 1000, 1002000);
      // Starts 5 s after the vibration began, well past vibration plus tail.
      const outcomes = pipeline.handle([event(7)], 1000000 - 1000, 1009000);
      expect(outcomes.length).assertEqual(1);
      expect(alerts.vibrations).assertEqual(2);
    });

    it('event_that_started_before_the_vibration_is_still_handled', 0, () => {
      const alerts = new FakeAlerts();
      const catalog = new SoundCatalog([]);
      const pipeline = new SoundPipeline(catalog, new FakeMatcher(), alerts, new FakeSaver());
      pipeline.handle([event(1)], 1000000 - 1000, 1002000);
      // A different sound that began 1.5 s before that vibration, reported late because it closed late.
      const outcomes = pipeline.handle([event(0.5)], 1000000 - 1000, 1003000);
      expect(outcomes.length).assertEqual(1);
    });

    it('empty_event_list_does_nothing', 0, () => {
      const alerts = new FakeAlerts();
      const saver = new FakeSaver();
      const pipeline = new SoundPipeline(new SoundCatalog([]), new FakeMatcher(), alerts, saver);
      expect(pipeline.handle([], 1000000).length).assertEqual(0);
      expect(alerts.vibrations).assertEqual(0);
      expect(saver.saves).assertEqual(0);
    });
  });
}
