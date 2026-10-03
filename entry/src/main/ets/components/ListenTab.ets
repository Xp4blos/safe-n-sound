import { ListenState } from '../services/AudioService';
import { SoundRecord } from '../model/SoundModels';
import { LevelChart } from './LevelChart';
import { PulsingMic } from './PulsingMic';

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
  @Prop bars: number[] = [];
  @Prop notificationsOn: boolean = true;
  @Prop lastSound: SoundRecord | undefined = undefined;
  @Prop lastSoundIsNew: boolean = false;
  onToggle: () => void = (): void => {};

  private isListening(): boolean {
    return this.state === 'listening';
  }

  private level(): number {
    return this.bars.length > 0 ? this.bars[this.bars.length - 1] : 0;
  }

  @Builder
  stateMessage() {
    if (this.state === 'permission_denied') {
      Text($r('app.string.state_permission_denied'))
        .fontSize(14)
        .fontColor($r('app.color.danger'))
        .textAlign(TextAlign.Center)
    } else if (this.state === 'error') {
      Text($r('app.string.state_error'))
        .fontSize(14)
        .fontColor($r('app.color.danger'))
        .textAlign(TextAlign.Center)
    } else if (this.state === 'starting') {
      Text($r('app.string.state_starting')).fontSize(16).fontColor($r('app.color.muted'))
    } else if (this.state === 'listening') {
      Text($r('app.string.state_listening')).fontSize(16).fontColor($r('app.color.accent'))
    } else {
      Text($r('app.string.state_idle')).fontSize(16).fontColor($r('app.color.muted'))
    }
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
            Text(this.lastSound.name).fontSize(18).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_surface'))
          } else {
            Text($r('app.string.sound_default_name', this.lastSound.id)).fontSize(18)
              .fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
          }
          if (this.lastSoundIsNew) {
            Text($r('app.string.sound_new_suffix')).fontSize(12).fontColor($r('app.color.accent'))
          }
        }
        Text(this.lastSound.kind === 1 ? $r('app.string.kind_pulsed') : $r('app.string.kind_tonal'))
          .fontSize(14).fontColor($r('app.color.muted'))
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
    Column({ space: 16 }) {
      LevelChart({ bars: this.bars })

      PulsingMic({ level: this.level(), active: this.isListening() })

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

      this.lastSoundCard()

      if (!this.notificationsOn) {
        Text($r('app.string.notifications_off')).fontSize(13).fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 24, bottom: 16 })
    .justifyContent(FlexAlign.Start)
  }
}
