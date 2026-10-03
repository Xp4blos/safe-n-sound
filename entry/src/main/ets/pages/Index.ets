import { common } from '@kit.AbilityKit';
import { HistoryTab } from '../components/HistoryTab';
import { ListenTab } from '../components/ListenTab';
import { LevelHistory } from '../model/LevelHistory';
import { SoundRecord } from '../model/SoundModels';
import { AlertService } from '../services/AlertService';
import { AudioService, ListenState } from '../services/AudioService';
import { ServiceHub } from '../services/ServiceHub';
import { SoundStore } from '../services/SoundStore';

function copyRecord(r: SoundRecord): SoundRecord {
  const copy: SoundRecord = {
    id: r.id, kind: r.kind, fingerprint: r.fingerprint, name: r.name, alertsEnabled: r.alertsEnabled,
    timesHeard: r.timesHeard, lastSeenMs: r.lastSeenMs, lastNotifiedMs: r.lastNotifiedMs, recentMs: r.recentMs
  };
  return copy;
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State listenState: ListenState = 'idle';
  @State bars: number[] = new LevelHistory().bars();
  @State notificationsOn: boolean = true;
  @State lastSound: SoundRecord | undefined = undefined;
  @State lastSoundIsNew: boolean = false;
  @State sounds: SoundRecord[] = [];
  private levelHistory: LevelHistory = new LevelHistory();
  private alerts: AlertService = new AlertService();
  private store: SoundStore | undefined = undefined;
  private audioService: AudioService | undefined = undefined;

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
    const service = new AudioService(store, this.alerts);
    service.onLevel = (db: number): void => {
      this.levelHistory.push(db, Date.now());
      this.bars = this.levelHistory.bars();
    };
    service.onSound = (record: SoundRecord, isNew: boolean): void => {
      this.lastSound = copyRecord(record);
      this.lastSoundIsNew = isNew;
      this.refreshSounds();
    };
    service.onState = (state: ListenState): void => {
      this.listenState = state;
      if (state !== 'listening') {
        this.levelHistory.reset();
        this.bars = this.levelHistory.bars();
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

  private async saveEdit(id: number, name: string, alertsEnabled: boolean): Promise<void> {
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

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        ListenTab({
          state: this.listenState,
          bars: this.bars,
          notificationsOn: this.notificationsOn,
          lastSound: this.lastSound,
          lastSoundIsNew: this.lastSoundIsNew,
          onToggle: (): void => {
            this.toggleListening();
          }
        })
      }
      .tabBar($r('app.string.tab_listen'))

      TabContent() {
        HistoryTab({
          sounds: this.sounds,
          onEdit: (id: number, name: string, alertsEnabled: boolean): void => {
            this.saveEdit(id, name, alertsEnabled);
          },
          onToggleAlerts: (id: number, enabled: boolean): void => {
            this.setAlerts(id, enabled);
          }
        })
      }
      .tabBar($r('app.string.tab_history'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onChange((index: number): void => {
      this.currentTab = index;
    })
  }
}
