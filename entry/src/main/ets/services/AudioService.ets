import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SoundRecord } from '../model/SoundModels';
import { AlertService } from './AlertService';
import { NativeEngine, NativeMatcher } from './NativeEngine';
import { SoundPipeline } from './SoundPipeline';
import { SoundStore } from './SoundStore';

const LOG_DOMAIN: number = 0x3201;
const TAG: string = 'AudioService';
const SAMPLE_RATE: number = 16000;
const MIC_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

export type ListenState = 'idle' | 'starting' | 'listening' | 'permission_denied' | 'error';

// Owns the microphone: permission, capture, feeding the native engine, and handing events to the pipeline.
// Foreground only; the ability stops it when the app leaves the foreground.
export class AudioService {
  onLevel: (db: number) => void = (db: number): void => {};
  onSound: (record: SoundRecord, isNew: boolean) => void = (record: SoundRecord, isNew: boolean): void => {};
  onState: (state: ListenState) => void = (state: ListenState): void => {};

  private store: SoundStore;
  private alerts: AlertService;
  private state: ListenState = 'idle';
  private capturer: audio.AudioCapturer | undefined;
  private engine: NativeEngine | undefined;
  private pipeline: SoundPipeline | undefined;
  private captureStartMs: number = 0;

  constructor(store: SoundStore, alerts: AlertService) {
    this.store = store;
    this.alerts = alerts;
  }

  currentState(): ListenState {
    return this.state;
  }

  async start(context: common.UIAbilityContext): Promise<void> {
    if (this.state === 'starting' || this.state === 'listening') {
      return;
    }
    this.setState('starting');
    if (!(await this.requestMicrophone(context))) {
      this.setState('permission_denied');
      return;
    }
    try {
      this.engine = NativeEngine.create(SAMPLE_RATE);
      this.pipeline = new SoundPipeline(this.store.catalog(), new NativeMatcher(), this.alerts, this.store);
      this.captureStartMs = Date.now();
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: { source: audio.SourceType.SOURCE_TYPE_MIC, capturerFlags: 0 }
      };
      const capturer = await audio.createAudioCapturer(options);
      this.capturer = capturer;
      capturer.on('readData', (buffer: ArrayBuffer): void => {
        this.onBuffer(buffer);
      });
      capturer.on('stateChange', (s: audio.AudioState): void => {
        if (this.state === 'listening' &&
          (s === audio.AudioState.STATE_STOPPED || s === audio.AudioState.STATE_RELEASED)) {
          hilog.warn(LOG_DOMAIN, TAG, 'Capturer stopped unexpectedly (state %{public}d)', s);
          this.fail();
        }
      });
      await capturer.start();
      this.setState('listening');
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'Failed to start listening: %{public}s', JSON.stringify(e));
      this.fail();
    }
  }

  // Idempotent; releases the microphone and the native engine.
  async stop(): Promise<void> {
    await this.release();
    if (this.state !== 'permission_denied' && this.state !== 'error') {
      this.setState('idle');
    }
  }

  private fail(): void {
    this.release();
    this.setState('error');
  }

  private async release(): Promise<void> {
    const capturer = this.capturer;
    const engine = this.engine;
    this.capturer = undefined;
    this.engine = undefined;
    this.pipeline = undefined;
    if (capturer !== undefined) {
      try {
        capturer.off('readData');
        await capturer.stop();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, 'Stopping capturer: %{public}s', JSON.stringify(e));
      }
      try {
        await capturer.release();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, TAG, 'Releasing capturer: %{public}s', JSON.stringify(e));
      }
    }
    if (engine !== undefined) {
      engine.destroy();
    }
  }

  private onBuffer(buffer: ArrayBuffer): void {
    const engine = this.engine;
    const pipeline = this.pipeline;
    if (engine === undefined || pipeline === undefined) {
      return;
    }
    try {
      const result = engine.process(buffer);
      this.onLevel(result.levelDb);
      for (const outcome of pipeline.handle(result.events, this.captureStartMs)) {
        this.onSound(outcome.record, outcome.isNew);
      }
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'Processing audio failed: %{public}s', JSON.stringify(e));
    }
  }

  private async requestMicrophone(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [MIC_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'Permission request failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  private setState(state: ListenState): void {
    this.state = state;
    this.onState(state);
  }
}
