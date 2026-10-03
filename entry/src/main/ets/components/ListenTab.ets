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

  private hasProblem(): boolean {
    return this.state === 'permission_denied' || this.state === 'error';
  }

  private recentCount(record: SoundRecord): number {
    return record.recentMs.filter((t: number): boolean => record.lastSeenMs - t <= 30000).length;
  }

  private chipColor(): ResourceColor {
    if (this.isListening()) {
      return $r('app.color.success');
    }
    return this.hasProblem() ? $r('app.color.danger') : $r('app.color.muted');
  }

  // Header: app name and a status chip (colour dot + words), so the state is never only a colour.
  @Builder
  header() {
    Row() {
      Text($r('app.string.app_title'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.on_surface'))
      Blank()
      Row({ space: 8 }) {
        Circle().width(9).height(9).fill(this.chipColor())
        if (this.state === 'permission_denied') {
          Text($r('app.string.state_chip_denied')).fontSize(13).fontColor($r('app.color.on_surface'))
        } else if (this.state === 'error') {
          Text($r('app.string.state_chip_error')).fontSize(13).fontColor($r('app.color.on_surface'))
        } else if (this.state === 'starting') {
          Text($r('app.string.state_starting')).fontSize(13).fontColor($r('app.color.on_surface'))
        } else if (this.isListening()) {
          Text($r('app.string.state_listening')).fontSize(13).fontColor($r('app.color.on_surface'))
        } else {
          Text($r('app.string.state_idle')).fontSize(13).fontColor($r('app.color.on_surface'))
        }
      }
      .padding({ left: 12, right: 14, top: 8, bottom: 8 })
      .borderRadius(20)
      .backgroundColor($r('app.color.surface_alt'))
    }
    .width('100%')
  }

  @Builder
  problemCard() {
    Column({ space: 4 }) {
      if (this.state === 'permission_denied') {
        Text($r('app.string.state_permission_denied')).fontSize(14).fontColor($r('app.color.on_surface'))
      } else {
        Text($r('app.string.state_error')).fontSize(14).fontColor($r('app.color.on_surface'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1.5, color: $r('app.color.danger') })
  }

  // Full-width card for a named sound that was just heard: impossible to miss.
  @Builder
  alertCard(record: SoundRecord) {
    Row({ space: 16 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.bell'))
          .fontSize(30)
          .fontColor([$r('app.color.on_accent')])
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#33FFFFFF')

      Column({ space: 4 }) {
        Text($r('app.string.alert_card_title', record.name))
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_accent'))
        Text($r('app.string.at_time', clockTime(record.lastSeenMs)))
          .fontSize(15).fontColor($r('app.color.on_accent')).opacity(0.9)
        if (this.recentCount(record) > 1) {
          Text($r('app.string.alert_ongoing', this.recentCount(record)))
            .fontSize(13).fontColor($r('app.color.on_accent')).opacity(0.9)
        } else {
          Text($r('app.string.alert_once', record.timesHeard))
            .fontSize(13).fontColor($r('app.color.on_accent')).opacity(0.9)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(20)
    .borderRadius(26)
    .linearGradient({ angle: 120, colors: [[$r('app.color.accent'), 0], [$r('app.color.accent_end'), 1]] })
    .shadow({ radius: 20, color: '#443B7BF0', offsetY: 8 })
  }

  @Builder
  lastSoundCard() {
    Column({ space: 6 }) {
      Text($r('app.string.last_detected')).fontSize(12).fontColor($r('app.color.muted'))
      if (this.lastSound === undefined) {
        Text($r('app.string.nothing_yet')).fontSize(16).fontColor($r('app.color.on_surface'))
      } else {
        Row({ space: 8 }) {
          if (this.lastSound.name !== '') {
            Text(this.lastSound.name).fontSize(19).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
          } else {
            Text($r('app.string.unknown_sound')).fontSize(19).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_surface'))
          }
          if (this.lastSoundIsNew) {
            Text($r('app.string.sound_new_suffix'))
              .fontSize(11).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_accent'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .backgroundColor($r('app.color.accent'))
          }
        }
        Text(SoundCatalog.describe(this.lastSound.profile)).fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.at_time', clockTime(this.lastSound.lastSeenMs)))
          .fontSize(13).fontColor($r('app.color.muted'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .borderRadius(22)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.header()

        // A named sound was just heard: the card sits at the very top so it is visible without scrolling.
        if (this.alertRecord !== undefined) {
          this.alertCard(this.alertRecord)
        }

        SpectrumView({ columns: this.columns, marks: this.marks })

        Column({ space: 6 }) {
          PulsingMic({
            level: this.level,
            active: this.isListening(),
            onTap: (): void => {
              this.onToggle();
            }
          })
          Text(this.isListening() ? $r('app.string.tap_to_stop') : $r('app.string.tap_to_start'))
            .fontSize(14)
            .fontColor($r('app.color.muted'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        if (this.hasProblem()) {
          this.problemCard()
        }

        Button(this.isListening() ? $r('app.string.btn_stop') :
          (this.hasProblem() ? $r('app.string.btn_retry') : $r('app.string.btn_start')), { type: ButtonType.Capsule })
          .width('100%')
          .height(56)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isListening() ? $r('app.color.danger') : $r('app.color.on_accent'))
          .backgroundColor(this.isListening() ? $r('app.color.surface') : Color.Transparent)
          .linearGradient(this.isListening() ?
            { angle: 90, colors: [[$r('app.color.surface'), 0], [$r('app.color.surface'), 1]] } :
            { angle: 90, colors: [[$r('app.color.accent'), 0], [$r('app.color.accent_end'), 1]] })
          .border({ width: this.isListening() ? 1.5 : 0, color: $r('app.color.danger') })
          .enabled(this.state !== 'starting')
          .onClick((): void => {
            this.onToggle();
          })

        Button({ type: ButtonType.Capsule }) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.plus')).fontSize(20).fontColor([$r('app.color.accent')])
            Text($r('app.string.teach_button')).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
          }
        }
        .width('100%')
        .height(52)
        .backgroundColor($r('app.color.surface_alt'))
        .enabled(this.state !== 'starting')
        .onClick((): void => {
          this.onTeach();
        })

        this.lastSoundCard()

        if (!this.notificationsOn) {
          Text($r('app.string.notifications_off')).fontSize(13).fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 20, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
