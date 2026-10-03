export interface SoundProfile {
  dominantHz: number;
  durationSec: number;
  beepCount: number;
  beepsPerSec: number;
  repetition: number; // 0 single, 1 repeated, 2 continuous
  modulation: number; // 0 steady, 1 pulsed, 2 sweeping
  envelope: number[]; // 8 points, max 1
}

export interface EngineEvent {
  type: string; // 'alarm' (unrecognised tonal sound) or 'custom' (a stored sound recognised again)
  timeSec: number; // engine stream time of the detection
  startSec: number; // start of the matched sound (custom)
  confidence: number;
  freqHz: number;
  levelDb: number;
  label: string; // custom: the label the sound was stored under, else ''
}

export interface EngineResult {
  levelDb: number;
  bands: number[]; // 16 live spectrum bars, 0..1
  events: EngineEvent[];
}

export interface LearnResult {
  ok: boolean;
  message: string; // why it failed, when !ok
  template: ArrayBuffer; // serialised sound (feature numbers, not audio)
  profile: SoundProfile;
  consistency: number;
}

export const createEngine: (sampleRate: number) => number;
export const destroyEngine: (handle: number) => void;
export const process: (handle: number, pcm: ArrayBuffer) => EngineResult;
export const learnSound: (handle: number, label: string, eventTimeSec: number) => LearnResult;
export const trainSound: (handle: number, label: string, takes: ArrayBuffer[]) => LearnResult;
export const checkTake: (handle: number, take: ArrayBuffer) => LearnResult;
export const addSound: (handle: number, template: ArrayBuffer) => boolean;
export const removeSound: (handle: number, label: string) => boolean;
