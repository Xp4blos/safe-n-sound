import { SoundCatalog } from '../model/SoundCatalog';
import { SoundRecord } from '../model/SoundModels';
import { ListenState } from '../services/AudioService';
import { PulsingMic } from './PulsingMic';
import { SpectrumView } from './SpectrumView';

function twoDigits(n: number): string {
  return n < 10 ? '0' + n : n.toString();
}

function clockTime(ms: number): string {
  const d = new Date(ms);
  return twoDigits(d.getHours()) + ':' + twoDigits(d.getMinutes()) + ':' + twoDigits(d.getSeconds());
}

@Component
export struct ListenTab {
  @Prop state: ListenState = 'idle';
  @Prop columns: number[] = [];
  @Prop marks: number[] = [];
  @Prop level: number = 0;
  @Prop notificationsOn: boolean = true;
  @Prop lastSound: SoundRecord | undefined = undefined;
  @Prop lastSoundIsNew: boolean = false;
  @Prop alertRecord: SoundRecord | undefined = undefined;
  onToggle: () => void = (): void => {};
  onTeach: () => void = (): void => {};

  private isListening(): boolean {
    return this.state === 'listening';
  }

  private recentCount(record: SoundRecord): number {
    return record.recentMs.filter((t: number): boolean => record.lastSeenMs - t <= 30000).length;
  }

  @Builder
  stateMessage() {
    if (this.state === 'permission_denied') {
      Text($r('app.string.state_permission_denied'))
        .fontSize(14).fontColor($r('app.color.danger')).textAlign(TextAlign.Center)
    } else if (this.state === 'error') {
      Text($r('app.string.state_error'))
        .fontSize(14).fontColor($r('app.color.danger')).textAlign(TextAlign.Center)
    } else if (this.state === 'starting') {
      Text($r('app.string.state_starting')).fontSize(16).fontColor($r('app.color.muted'))
    } else if (this.state === 'listening') {
      Text($r('app.string.state_listening')).fontSize(16).fontColor($r('app.color.accent'))
    } else {
      Text($r('app.string.state_idle')).fontSize(16).fontColor($r('app.color.muted'))
    }
  }

  // Full-width card for a named sound that was just heard: impossible to miss.
  @Builder
  alertCard(record: SoundRecord) {
    Column({ space: 6 }) {
      Text($r('app.string.alert_card_title', record.name))
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_accent'))
      Text($r('app.string.at_time', clockTime(record.lastSeenMs)))
        .fontSize(16).fontColor($r('app.color.on_accent'))
      if (this.recentCount(record) > 1) {
        Text($r('app.string.alert_ongoing', this.recentCount(record)))
          .fontSize(14).fontColor($r('app.color.on_accent'))
      } else {
        Text($r('app.string.alert_once', record.timesHeard))
          .fontSize(14).fontColor($r('app.color.on_accent'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .borderRadius(20)
    .backgroundColor($r('app.color.accent'))
  }

  @Builder
  lastSoundCard() {
    Column({ space: 4 }) {
      Text($r('app.string.last_detected')).fontSize(12).fontColor($r('app.color.muted'))
      if (this.lastSound === undefined) {
        Text($r('app.string.nothing_yet')).fontSize(16).fontColor($r('app.color.on_surface'))
      } else {
        Row({ space: 8 }) {
          if (this.lastSound.name !== '') {
            Text(this.lastSound.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
          } else {
            Text($r('app.string.unknown_sound')).fontSize(18).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_surface'))
          }
          if (this.lastSoundIsNew) {
            Text($r('app.string.sound_new_suffix')).fontSize(12).fontColor($r('app.color.accent'))
          }
        }
        Text(SoundCatalog.describe(this.lastSound.profile)).fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.at_time', clockTime(this.lastSound.lastSeenMs)))
          .fontSize(14).fontColor($r('app.color.muted'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        SpectrumView({ columns: this.columns, marks: this.marks })

        PulsingMic({
          level: this.level,
          active: this.isListening(),
          onTap: (): void => {
            this.onToggle();
          }
        })

        this.stateMessage()

        Button(this.isListening() ? $r('app.string.btn_stop') :
          (this.state === 'permission_denied' || this.state === 'error' ? $r('app.string.btn_retry') :
          $r('app.string.btn_start')))
          .width('100%')
          .height(52)
          .fontSize(18)
          .backgroundColor(this.isListening() ? $r('app.color.surface') : $r('app.color.accent'))
          .fontColor(this.isListening() ? $r('app.color.accent') : $r('app.color.on_accent'))
          .enabled(this.state !== 'starting')
          .onClick((): void => {
            this.onToggle();
          })

        Button($r('app.string.teach_button'))
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent'))
          .enabled(this.state !== 'starting')
          .onClick((): void => {
            this.onTeach();
          })

        if (this.alertRecord !== undefined) {
          this.alertCard(this.alertRecord)
        }

        this.lastSoundCard()

        if (!this.notificationsOn) {
          Text($r('app.string.notifications_off')).fontSize(13).fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
