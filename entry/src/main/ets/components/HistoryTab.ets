import { SoundRecord } from '../model/SoundModels';
import { SoundEditDialog } from './SoundEditDialog';

function twoDigits(n: number): string {
  return n < 10 ? '0' + n : n.toString();
}

function clockTime(ms: number): string {
  const d = new Date(ms);
  return twoDigits(d.getHours()) + ':' + twoDigits(d.getMinutes());
}

@Component
export struct HistoryTab {
  @Prop sounds: SoundRecord[] = [];
  onEdit: (id: number, name: string, alertsEnabled: boolean) => void =
    (id: number, name: string, alertsEnabled: boolean): void => {};
  onToggleAlerts: (id: number, enabled: boolean) => void = (id: number, enabled: boolean): void => {};

  private openEditor(record: SoundRecord): void {
    const controller: CustomDialogController = new CustomDialogController({
      builder: SoundEditDialog({
        recordId: record.id,
        initialName: record.name,
        initialAlerts: record.alertsEnabled,
        onSave: (id: number, name: string, alertsEnabled: boolean): void => {
          this.onEdit(id, name, alertsEnabled);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    controller.open();
  }

  @Builder
  row(record: SoundRecord) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        if (record.name !== '') {
          Text(record.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
        } else {
          Text($r('app.string.sound_default_name', record.id)).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_surface'))
        }
        Text(record.kind === 1 ? $r('app.string.kind_pulsed') : $r('app.string.kind_tonal'))
          .fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.heard_times', record.timesHeard))
          .fontSize(14).fontColor($r('app.color.muted'))
        Text($r('app.string.last_seen', clockTime(record.lastSeenMs)))
          .fontSize(14).fontColor($r('app.color.muted'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

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
    .onClick((): void => {
      this.openEditor(record);
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
            record.alertsEnabled)
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
