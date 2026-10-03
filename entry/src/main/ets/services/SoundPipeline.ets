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
  private catalog: SoundCatalog;
  private matcher: MatcherPort;
  private alerts: AlertPort;
  private saver: SavePort;

  constructor(catalog: SoundCatalog, matcher: MatcherPort, alerts: AlertPort, saver: SavePort) {
    this.catalog = catalog;
    this.matcher = matcher;
    this.alerts = alerts;
    this.saver = saver;
  }

  // `captureStartMs` is the wall-clock time of the engine's first sample; event offsets are relative to it.
  handle(events: DetectedEvent[], captureStartMs: number): CatalogOutcome[] {
    const outcomes: CatalogOutcome[] = [];
    for (const ev of events) {
      const match = this.matcher.matchFingerprint(ev.fingerprint, this.catalog.fingerprints());
      const nowMs = captureStartMs + Math.round(ev.startSec * 1000);
      const outcome = this.catalog.registerEvent(ev, match.index, nowMs);
      this.alerts.vibrate();
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
