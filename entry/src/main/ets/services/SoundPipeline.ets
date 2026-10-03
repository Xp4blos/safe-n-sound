import { CatalogOutcome, SoundCatalog } from '../model/SoundCatalog';
import { DetectedEvent, MatchResult } from '../model/SoundModels';

// Narrow ports so the pipeline can be tested without the native library, vibrator or storage.
export interface MatcherPort {
  matchFingerprint(fp: number[], saved: number[][]): MatchResult;
}

export interface AlertPort {
  vibrate(): void;
  notifyKnownSound(name: string): Promise<void>;
}

export interface SavePort {
  save(): Promise<void>;
}

// What happens when the engine reports finished events: match, remember, alert, persist.
export class SoundPipeline {
  // The phone's own vibration motor is picked up by its microphone as a low rumble. Events that start
  // while we are vibrating (plus a short tail) are that feedback, not a new sound, and are ignored.
  static readonly VIBRATION_MS: number = 750; // two 300 ms pulses and the gap between them
  static readonly FEEDBACK_TAIL_MS: number = 500;

  private catalog: SoundCatalog;
  private matcher: MatcherPort;
  private alerts: AlertPort;
  private saver: SavePort;
  private lastVibrationMs: number = -1e15;

  constructor(catalog: SoundCatalog, matcher: MatcherPort, alerts: AlertPort, saver: SavePort) {
    this.catalog = catalog;
    this.matcher = matcher;
    this.alerts = alerts;
    this.saver = saver;
  }

  // `captureStartMs` is the wall-clock time of the engine's first sample; event offsets are relative to it.
  // `nowMs` is the wall-clock time of this call, i.e. when any vibration starts.
  handle(events: DetectedEvent[], captureStartMs: number, nowMs: number = Date.now()): CatalogOutcome[] {
    const outcomes: CatalogOutcome[] = [];
    for (const ev of events) {
      const eventMs = captureStartMs + Math.round(ev.startSec * 1000);
      if (eventMs >= this.lastVibrationMs &&
        eventMs < this.lastVibrationMs + SoundPipeline.VIBRATION_MS + SoundPipeline.FEEDBACK_TAIL_MS) {
        continue;
      }
      const match = this.matcher.matchFingerprint(ev.fingerprint, this.catalog.fingerprints());
      const outcome = this.catalog.registerEvent(ev, match.index, eventMs);
      this.alerts.vibrate();
      this.lastVibrationMs = nowMs;
      if (outcome.shouldNotify) {
        this.alerts.notifyKnownSound(outcome.record.name);
      }
      outcomes.push(outcome);
    }
    if (outcomes.length > 0) {
      this.saver.save();
    }
    return outcomes;
  }
}
