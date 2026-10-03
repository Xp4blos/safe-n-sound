import { createEngine, destroyEngine, matchFingerprint, process as nativeProcess } from 'libsafensound.so';
import { DetectedEvent, EngineResult, MatchResult } from '../model/SoundModels';
import { MatcherPort } from './SoundPipeline';

// Typed wrapper around the native engine handle. Converts native results into the app's own model types.
export class NativeEngine {
  private handle: number;
  private destroyed: boolean = false;

  private constructor(handle: number) {
    this.handle = handle;
  }

  static create(sampleRate: number): NativeEngine {
    return new NativeEngine(createEngine(sampleRate));
  }

  process(pcm: ArrayBuffer): EngineResult {
    const native = nativeProcess(this.handle, pcm);
    const events: DetectedEvent[] = [];
    for (const e of native.events) {
      const ev: DetectedEvent = {
        startSec: e.startSec,
        durationSec: e.durationSec,
        kind: e.kind,
        fingerprint: e.fingerprint
      };
      events.push(ev);
    }
    const result: EngineResult = { levelDb: native.levelDb, events: events };
    return result;
  }

  // Safe to call more than once.
  destroy(): void {
    if (!this.destroyed) {
      this.destroyed = true;
      destroyEngine(this.handle);
    }
  }
}

export class NativeMatcher implements MatcherPort {
  matchFingerprint(fp: number[], saved: number[][]): MatchResult {
    const native = matchFingerprint(fp, saved);
    const result: MatchResult = { index: native.index, score: native.score };
    return result;
  }
}
