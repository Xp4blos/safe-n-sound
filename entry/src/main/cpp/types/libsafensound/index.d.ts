export interface DetectedEvent {
  startSec: number;
  durationSec: number;
  kind: number; // 0 = tonal (alarm/beep), 1 = pulsed (repeated beeps / door ring)
  fingerprint: number[]; // 29 floats
}

export interface EngineResult {
  levelDb: number;
  events: DetectedEvent[];
}

export interface MatchResult {
  index: number; // -1 when no saved sound matches
  score: number;
}

export const createEngine: (sampleRate: number) => number;
export const destroyEngine: (handle: number) => void;
export const process: (handle: number, pcm: ArrayBuffer) => EngineResult;
export const matchFingerprint: (fp: number[], saved: number[][]) => MatchResult;
