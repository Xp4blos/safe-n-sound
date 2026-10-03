// Plain data shapes shared by the services and UI. They mirror the native module's declarations
// (entry/src/main/cpp/types/libsafensound/index.d.ts) so the pure logic here never imports the native library.

export interface DetectedEvent {
  startSec: number;
  durationSec: number;
  kind: number; // 0 = tonal (alarm/beep), 1 = pulsed (repeated beeps / door ring)
  fingerprint: number[];
}

export interface EngineResult {
  levelDb: number;
  events: DetectedEvent[];
}

export interface MatchResult {
  index: number; // -1 when no saved sound matches
  score: number;
}

export interface SoundRecord {
  id: number;
  kind: number;
  fingerprint: number[];
  name: string; // '' means the user has not named it yet
  alertsEnabled: boolean;
  timesHeard: number;
  lastSeenMs: number;
  lastNotifiedMs: number; // 0 = never notified
  recentMs: number[]; // timestamps of the most recent occurrences, oldest first
}
