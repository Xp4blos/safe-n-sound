import { common } from '@kit.AbilityKit';
import { HistoryTab } from '../components/HistoryTab';
import { ListenTab } from '../components/ListenTab';
import { MySoundsTab } from '../components/MySoundsTab';
import { PromptDialog } from '../components/PromptDialog';
import { SoundDetailDialog } from '../components/SoundDetailDialog';
import { TakeStatus, TeachDialog } from '../components/TeachDialog';
import { SoundRecord } from '../model/SoundModels';
import { SpectrumHistory } from '../model/SpectrumHistory';
import { AlertService } from '../services/AlertService';
import { AudioService, ListenState } from '../services/AudioService';
import { PipelineListener } from '../services/SoundPipeline';
import { ServiceHub } from '../services/ServiceHub';
import { SoundStore } from '../services/SoundStore';

const TAKE_SECONDS: number = 6;
const ALERT_CARD_MS: number = 60000;
const UI_REFRESH_MS: number = 120;

function copyRecord(r: SoundRecord): SoundRecord {
  const copy: SoundRecord = {
    id: r.id, label: r.label, name: r.name, alertsEnabled: r.alertsEnabled, timesHeard: r.timesHeard,
    firstSeenMs: r.firstSeenMs, lastSeenMs: r.lastSeenMs, lastAlertMs: r.lastAlertMs, lastPromptMs: r.lastPromptMs,
    promptNever: r.promptNever, recentMs: r.recentMs.slice(), profile: r.profile, template: r.template
  };
  return copy;
}

// Forwards the pipeline's notifications to the page.
class UiBridge implements PipelineListener {
  heard: (record: SoundRecord, isNew: boolean) => void = (record: SoundRecord, isNew: boolean): void => {};
  alert: (record: SoundRecord, timeMs: number) => void = (record: SoundRecord, timeMs: number): void => {};
  prompt: (record: SoundRecord) => void = (record: SoundRecord): void => {};
  detection: (timeMs: number) => void = (timeMs: number): void => {};
  changed: () => void = (): void => {};

  onSoundHeard(record: SoundRecord, isNew: boolean): void {
    this.heard(record, isNew);
  }

  onAlert(record: SoundRecord, timeMs: number): void {
    this.alert(record, timeMs);
  }

  onPrompt(record: SoundRecord): void {
    this.prompt(record);
  }

  onDetection(timeMs: number): void {
    this.detection(timeMs);
  }

  onChanged(): void {
    this.changed();
  }
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State listenState: ListenState = 'idle';
  @State columns: number[] = new SpectrumHistory().columns();
  @State marks: number[] = new SpectrumHistory().marks();
  @State level: number = 0;
  @State notificationsOn: boolean = true;
  @State lastSound: SoundRecord | undefined = undefined;
  @State lastSoundIsNew: boolean = false;
  @State alertRecord: SoundRecord | undefined = undefined;
  @State sounds: SoundRecord[] = [];
  private spectrum: SpectrumHistory = new SpectrumHistory();
  private lastUiMs: number = 0;
  private alertToken: number = 0;
  private alerts: AlertService = new AlertService();
  private store: SoundStore | undefined = undefined;
  private audioService: AudioService | undefined = undefined;
  private takeBuffers: ArrayBuffer[] = [];

  aboutToAppear(): void {
    this.setUp();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async setUp(): Promise<void> {
    const store = await SoundStore.open(this.context());
    this.store = store;
    this.refreshSounds();

    const bridge = new UiBridge();
    bridge.heard = (record: SoundRecord, isNew: boolean): void => {
      this.lastSound = copyRecord(record);
      this.lastSoundIsNew = isNew;
      this.refreshSounds();
    };
    bridge.alert = (record: SoundRecord, timeMs: number): void => {
      this.alertRecord = copyRecord(record);
      const token = ++this.alertToken;
      setTimeout((): void => {
        if (token === this.alertToken) {
          this.alertRecord = undefined;
        }
      }, ALERT_CARD_MS);
    };
    bridge.prompt = (record: SoundRecord): void => {
      this.openPrompt(record);
    };
    bridge.detection = (timeMs: number): void => {
      this.spectrum.markDetection(timeMs);
    };
    bridge.changed = (): void => {
      this.refreshSounds();
    };

    const service = new AudioService(store, this.alerts, bridge);
    service.onSpectrum = (bands: number[]): void => {
      const now = Date.now();
      this.spectrum.push(bands, now);
      if (now - this.lastUiMs >= UI_REFRESH_MS) {
        this.lastUiMs = now;
        this.columns = this.spectrum.columns();
        this.marks = this.spectrum.marks();
        this.level = this.spectrum.level();
      }
    };
    service.onState = (state: ListenState): void => {
      this.listenState = state;
      if (state !== 'listening') {
        this.spectrum.reset();
        this.columns = this.spectrum.columns();
        this.marks = this.spectrum.marks();
        this.level = 0;
      }
    };
    this.audioService = service;
    ServiceHub.audio = service;
  }

  // Newest first; copies so the UI sees a changed array even when records were updated in place.
  private refreshSounds(): void {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    const copies: SoundRecord[] = store.catalog().records().map((r: SoundRecord): SoundRecord => copyRecord(r));
    this.sounds = copies.sort((a: SoundRecord, b: SoundRecord): number => b.lastSeenMs - a.lastSeenMs);
  }

  private namedSounds(): SoundRecord[] {
    return this.sounds.filter((r: SoundRecord): boolean => r.name !== '');
  }

  // ---- listening --------------------------------------------------------------------------------

  private async toggleListening(): Promise<void> {
    const service = this.audioService;
    if (service === undefined) {
      return;
    }
    if (this.listenState === 'listening') {
      await service.stop();
      return;
    }
    this.notificationsOn = await this.alerts.ensureNotificationPermission(this.context());
    await service.start(this.context());
  }

  // ---- naming, details, deleting ----------------------------------------------------------------

  private openDetail(id: number): void {
    const store = this.store;
    const record = store === undefined ? undefined : store.catalog().find(id);
    if (record === undefined) {
      return;
    }
    const snapshot = copyRecord(record);
    const controller: CustomDialogController = new CustomDialogController({
      builder: SoundDetailDialog({
        record: snapshot,
        onSave: (soundId: number, name: string, alertsEnabled: boolean): void => {
          this.saveDetail(soundId, name, alertsEnabled);
        },
        onDelete: (soundId: number): void => {
          this.deleteSound(soundId);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    controller.open();
  }

  private async saveDetail(id: number, name: string, alertsEnabled: boolean): Promise<void> {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    store.catalog().rename(id, name);
    store.catalog().setAlerts(id, alertsEnabled);
    await store.save();
    this.refreshSounds();
  }

  private async setAlerts(id: number, enabled: boolean): Promise<void> {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    store.catalog().setAlerts(id, enabled);
    await store.save();
    this.refreshSounds();
  }

  private async deleteSound(id: number): Promise<void> {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    const removed = store.catalog().remove(id);
    if (removed !== undefined) {
      this.audioService?.forgetSound(removed.label);
      if (this.lastSound !== undefined && this.lastSound.id === id) {
        this.lastSound = undefined;
      }
      if (this.alertRecord !== undefined && this.alertRecord.id === id) {
        this.alertRecord = undefined;
      }
    }
    await store.save();
    this.refreshSounds();
  }

  // "I've heard this sound before. Do you want to name it?"
  private openPrompt(record: SoundRecord): void {
    const id = record.id;
    const controller: CustomDialogController = new CustomDialogController({
      builder: PromptDialog({
        onNameIt: (): void => {
          this.openDetail(id);
        },
        onNotNow: (): void => {},
        onNever: (): void => {
          this.neverAsk(id);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    controller.open();
  }

  private async neverAsk(id: number): Promise<void> {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    store.catalog().setPromptNever(id);
    await store.save();
  }

  // ---- teaching ---------------------------------------------------------------------------------

  private async openTeach(): Promise<void> {
    const service = this.audioService;
    if (service === undefined) {
      return;
    }
    if (this.listenState !== 'listening') {
      await this.toggleListening();
    }
    if (service.currentState() !== 'listening') {
      return;
    }
    this.takeBuffers = [];
    const controller: CustomDialogController = new CustomDialogController({
      builder: TeachDialog({
        recordTake: (): Promise<TakeStatus> => this.recordTake(),
        saveSound: (name: string): Promise<string> => this.saveTaught(name),
        discardTakes: (): void => {
          this.takeBuffers = [];
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: true,
      autoCancel: false
    });
    controller.open();
  }

  private async recordTake(): Promise<TakeStatus> {
    const service = this.audioService;
    if (service === undefined) {
      const none: TakeStatus = { ok: false, message: 'The microphone is not ready.' };
      return none;
    }
    try {
      const take = await service.recordTake(TAKE_SECONDS);
      const outcome = service.checkTake(take);
      if (outcome === undefined || !outcome.ok) {
        const bad: TakeStatus = { ok: false, message: outcome === undefined ? 'The microphone is not ready.' : outcome.message };
        return bad;
      }
      this.takeBuffers.push(take);
      const good: TakeStatus = { ok: true, message: '' };
      return good;
    } catch (e) {
      const failed: TakeStatus = { ok: false, message: 'Recording was interrupted.' };
      return failed;
    }
  }

  // Resolves to '' on success, otherwise the reason it failed.
  private async saveTaught(name: string): Promise<string> {
    const service = this.audioService;
    const store = this.store;
    if (service === undefined || store === undefined) {
      return 'The microphone is not ready.';
    }
    const label = store.catalog().reserveLabel();
    const outcome = service.trainSound(label, this.takeBuffers);
    if (outcome === undefined) {
      return 'The microphone is not ready.';
    }
    if (!outcome.ok) {
      return outcome.message.includes('match each other') ? 'The takes differ too much. Please record them again.' :
      outcome.message;
    }
    store.catalog().addTaught(label, name, outcome.template, outcome.profile, Date.now());
    this.takeBuffers = [];
    await store.save();
    this.refreshSounds();
    return '';
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        ListenTab({
          state: this.listenState,
          columns: this.columns,
          marks: this.marks,
          level: this.level,
          notificationsOn: this.notificationsOn,
          lastSound: this.lastSound,
          lastSoundIsNew: this.lastSoundIsNew,
          alertRecord: this.alertRecord,
          onToggle: (): void => {
            this.toggleListening();
          },
          onTeach: (): void => {
            this.openTeach();
          }
        })
      }
      .tabBar($r('app.string.tab_listen'))

      TabContent() {
        HistoryTab({
          sounds: this.sounds,
          onOpen: (id: number): void => {
            this.openDetail(id);
          }
        })
      }
      .tabBar($r('app.string.tab_history'))

      TabContent() {
        MySoundsTab({
          sounds: this.namedSounds(),
          onOpen: (id: number): void => {
            this.openDetail(id);
          },
          onToggleAlerts: (id: number, enabled: boolean): void => {
            this.setAlerts(id, enabled);
          }
        })
      }
      .tabBar($r('app.string.tab_mysounds'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onChange((index: number): void => {
      this.currentTab = index;
    })
  }
}
