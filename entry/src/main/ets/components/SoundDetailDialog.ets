import { SoundCatalog } from '../model/SoundCatalog';
import { SoundRecord } from '../model/SoundModels';
import { EnvelopeMini } from './EnvelopeMini';

function twoDigits(n: number): string {
  return n < 10 ? '0' + n : n.toString();
}

function clockTime(ms: number): string {
  const d = new Date(ms);
  return twoDigits(d.getHours()) + ':' + twoDigits(d.getMinutes());
}

// Details of one sound: plain-words summary, pattern, name field, alert switch, delete.
@CustomDialog
export struct SoundDetailDialog {
  controller?: CustomDialogController;
  record: SoundRecord | undefined = undefined;
  onSave: (id: number, name: string, alertsEnabled: boolean) => void =
    (id: number, name: string, alertsEnabled: boolean): void => {};
  onDelete: (id: number) => void = (id: number): void => {};
  @State draftName: string = '';
  @State draftAlerts: boolean = true;
  @State confirmDelete: boolean = false;

  aboutToAppear(): void {
    this.draftName = this.record === undefined ? '' : this.record.name;
    this.draftAlerts = this.record === undefined ? true : this.record.alertsEnabled;
  }

  build() {
    Column({ space: 14 }) {
      Text($r('app.string.detail_title')).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))

      if (this.record !== undefined) {
        Text(SoundCatalog.describe(this.record.profile)).fontSize(16).fontColor($r('app.color.on_surface'))
        Row({ space: 16 }) {
          EnvelopeMini({ envelope: this.record.profile.envelope })
          Column({ space: 2 }) {
            Text($r('app.string.heard_times', this.record.timesHeard)).fontSize(13).fontColor($r('app.color.muted'))
            Text($r('app.string.first_heard', clockTime(this.record.firstSeenMs)))
              .fontSize(13).fontColor($r('app.color.muted'))
            Text($r('app.string.last_seen', clockTime(this.record.lastSeenMs)))
              .fontSize(13).fontColor($r('app.color.muted'))
          }
          .alignItems(HorizontalAlign.Start)
        }
      }

      TextInput({ text: this.draftName, placeholder: $r('app.string.dialog_name_hint') })
        .maxLength(40)
        .onChange((value: string): void => {
          this.draftName = value;
        })

      Row() {
        Text($r('app.string.dialog_alerts')).fontSize(16).fontColor($r('app.color.on_surface'))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.draftAlerts })
          .onChange((isOn: boolean): void => {
            this.draftAlerts = isOn;
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.btn_cancel'))
          .layoutWeight(1)
          .backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent'))
          .onClick((): void => {
            this.controller?.close();
          })
        Button($r('app.string.btn_save'))
          .layoutWeight(1)
          .backgroundColor($r('app.color.accent'))
          .fontColor($r('app.color.on_accent'))
          .onClick((): void => {
            if (this.record !== undefined) {
              this.onSave(this.record.id, this.draftName, this.draftAlerts);
            }
            this.controller?.close();
          })
      }
      .width('100%')

      Button(this.confirmDelete ? $r('app.string.detail_delete_confirm') : $r('app.string.detail_delete'))
        .width('100%')
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.danger'))
        .onClick((): void => {
          if (!this.confirmDelete) {
            this.confirmDelete = true;
            return;
          }
          if (this.record !== undefined) {
            this.onDelete(this.record.id);
          }
          this.controller?.close();
        })
    }
    .padding(24)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
  }
}
