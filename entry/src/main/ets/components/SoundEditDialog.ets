// Dialog to name a remembered sound and choose whether to be notified when it is heard again.
@CustomDialog
export struct SoundEditDialog {
  controller?: CustomDialogController;
  recordId: number = 0;
  initialName: string = '';
  initialAlerts: boolean = true;
  onSave: (id: number, name: string, alertsEnabled: boolean) => void =
    (id: number, name: string, alertsEnabled: boolean): void => {};
  @State draftName: string = '';
  @State draftAlerts: boolean = true;

  aboutToAppear(): void {
    this.draftName = this.initialName;
    this.draftAlerts = this.initialAlerts;
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.dialog_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_surface'))

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
            this.onSave(this.recordId, this.draftName, this.draftAlerts);
            this.controller?.close();
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
  }
}
