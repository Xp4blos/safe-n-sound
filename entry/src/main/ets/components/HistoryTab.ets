import { SoundRecord } from '../model/SoundModels';
import { EnvelopeMini } from './EnvelopeMini';

function twoDigits(n: number): string {
  return n < 10 ? '0' + n : n.toString();
}

function clockTime(ms: number): string {
  const d = new Date(ms);
  return twoDigits(d.getHours()) + ':' + twoDigits(d.getMinutes());
}

// Chronological list of everything the phone has heard (newest first), one entry per sound.
@Component
export struct HistoryTab {
  @Prop sounds: SoundRecord[] = [];
  onOpen: (id: number) => void = (id: number): void => {};

  @Builder
  row(record: SoundRecord) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        if (record.name !== '') {
          Text(record.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
        } else if (record.template === '') {
          Text($r('app.string.learning_sound')).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.muted'))
        } else {
          Text($r('app.string.unknown_sound')).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_surface'))
        }
        Text($r('app.string.heard_times', record.timesHeard)).fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.last_seen', clockTime(record.lastSeenMs))).fontSize(14).fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      EnvelopeMini({ envelope: record.profile.envelope })
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
    .onClick((): void => {
      this.onOpen(record.id);
    })
  }

  build() {
    Column() {
      if (this.sounds.length === 0) {
        Text($r('app.string.empty_history'))
          .fontSize(16)
          .fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center)
          .padding(32)
      } else {
        List({ space: 12 }) {
          ForEach(this.sounds, (record: SoundRecord) => {
            ListItem() {
              this.row(record)
            }
          }, (record: SoundRecord) => record.id.toString() + '|' + record.timesHeard + '|' + record.name + '|' +
            record.template.length)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 24, bottom: 16 })
    .justifyContent(this.sounds.length === 0 ? FlexAlign.Center : FlexAlign.Start)
  }
}
