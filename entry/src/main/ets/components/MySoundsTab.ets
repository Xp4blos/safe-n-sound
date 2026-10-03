import { SoundCatalog } from '../model/SoundCatalog';
import { SoundRecord } from '../model/SoundModels';

// The named sounds: alert switch per sound; tap one to rename or delete it.
@Component
export struct MySoundsTab {
  @Prop sounds: SoundRecord[] = [];
  onOpen: (id: number) => void = (id: number): void => {};
  onToggleAlerts: (id: number, enabled: boolean) => void = (id: number, enabled: boolean): void => {};

  @Builder
  row(record: SoundRecord) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(record.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
        Text(SoundCatalog.describe(record.profile)).fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.heard_times', record.timesHeard)).fontSize(14).fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick((): void => {
        this.onOpen(record.id);
      })

      Column({ space: 4 }) {
        Text($r('app.string.alerts_label')).fontSize(12).fontColor($r('app.color.muted'))
        Toggle({ type: ToggleType.Switch, isOn: record.alertsEnabled })
          .onChange((isOn: boolean): void => {
            this.onToggleAlerts(record.id, isOn);
          })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
  }

  build() {
    Column() {
      if (this.sounds.length === 0) {
        Text($r('app.string.mysounds_empty'))
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
          }, (record: SoundRecord) => record.id.toString() + '|' + record.name + '|' + record.alertsEnabled + '|' +
            record.timesHeard)
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
