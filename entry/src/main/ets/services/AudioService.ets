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
// Developer switch: log every detected event with its fingerprint (for tuning the matcher on real audio).
const LOG_EVENT_FINGERPRINTS: boolean = false;

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
  private session: number = 0; // bumped by every start and stop so a start can tell it was cancelled

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
    const session = ++this.session;
    this.setState('starting');
    const granted = await this.requestMicrophone(context);
    if (session !== this.session) {
      return; // stopped while the permission dialog was open; stop() already reset the state
    }
    if (!granted) {
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
      if (session !== this.session) {
        await capturer.release();
        this.engine?.destroy();
        this.engine = undefined;
        this.pipeline = undefined;
        return;
      }
      this.capturer = capturer;
      capturer.on('readData', (buffer: ArrayBuffer): void => {
        this.onBuffer(buffer);
      });
      capturer.on('stateChange', (s: audio.AudioState): void => {
        // Ignore events from a capturer we already released ourselves (stop() makes it report STOPPED).
        if (this.capturer !== capturer) {
          return;
        }
        if (this.state === 'listening' &&
          (s === audio.AudioState.STATE_STOPPED || s === audio.AudioState.STATE_RELEASED)) {
          hilog.warn(LOG_DOMAIN, TAG, 'Capturer stopped unexpectedly (state %{public}d)', s);
          this.fail();
        }
      });
      await capturer.start();
      if (session !== this.session) {
        await this.release();
        return;
      }
      this.setState('listening');
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'Failed to start listening: %{public}s', JSON.stringify(e));
      this.fail();
    }
  }

  // For the app lifecycle: system permission dialogs also send the ability to the background while
  // start() is still waiting, so only an actual listening session is stopped.
  async stopIfListening(): Promise<void> {
    if (this.state === 'listening') {
      await this.stop();
    }
  }

  // App left the foreground: end a listening session, and cancel a start that is still waiting on a
  // permission dialog or the capturer, so the microphone never ends up running in the background.
  async onBackground(): Promise<void> {
    if (this.state === 'starting') {
      await this.stop();
    } else {
      await this.stopIfListening();
    }
  }

  // Idempotent; releases the microphone and the native engine.
  async stop(): Promise<void> {
    this.session++;
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
      if (LOG_EVENT_FINGERPRINTS) {
        for (const ev of result.events) {
          hilog.info(LOG_DOMAIN, TAG, 'EVT start=%{public}s dur=%{public}s kind=%{public}d fp=%{public}s',
            ev.startSec.toFixed(2), ev.durationSec.toFixed(2), ev.kind,
            ev.fingerprint.map((v: number): string => v.toFixed(4)).join(','));
        }
      }
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
      if (result.authResults.length > 0 && result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      // After an earlier denial the system shows no dialog; send the user to Settings instead.
      const shown = result.dialogShownResults;
      if (shown !== undefined && shown.length > 0 && !shown[0]) {
        const statuses = await atManager.requestPermissionOnSetting(context, [MIC_PERMISSION]);
        return statuses.length > 0 && statuses[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      }
      return false;
    } catch (e) {
      hilog.error(LOG_DOMAIN, TAG, 'Permission request failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  private setState(state: ListenState): void {
    hilog.info(LOG_DOMAIN, TAG, 'State %{public}s -> %{public}s', this.state, state);
    this.state = state;
    this.onState(state);
  }
}
