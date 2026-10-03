// "I've heard this sound before. Do you want to name it?" with the three choices of the spec.
@CustomDialog
export struct PromptDialog {
  controller?: CustomDialogController;
  onNameIt: () => void = (): void => {};
  onNotNow: () => void = (): void => {};
  onNever: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.prompt_title')).fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_surface'))
      Text($r('app.string.prompt_text')).fontSize(16).fontColor($r('app.color.muted'))

      Button($r('app.string.prompt_name'))
        .width('100%')
        .backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.on_accent'))
        .onClick((): void => {
          this.controller?.close();
          this.onNameIt();
        })
      Button($r('app.string.prompt_later'))
        .width('100%')
        .backgroundColor($r('app.color.accent_soft'))
        .fontColor($r('app.color.accent'))
        .onClick((): void => {
          this.controller?.close();
          this.onNotNow();
        })
      Button($r('app.string.prompt_never'))
        .width('100%')
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.muted'))
        .onClick((): void => {
          this.controller?.close();
          this.onNever();
        })
    }
    .padding(24)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(24)
  }
}
