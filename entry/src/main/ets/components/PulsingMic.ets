// Microphone disc whose halo grows and shrinks with the live sound level (0..1). Tapping it starts or stops
// listening, like the main button.
@Component
export struct PulsingMic {
  @Prop level: number = 0;
  @Prop active: boolean = false;
  onTap: () => void = (): void => {};
  private baseSize: number = 112;
  private extraSize: number = 88;

  build() {
    Stack() {
      Circle()
        .width(this.baseSize + (this.active ? this.level * this.extraSize : 0))
        .height(this.baseSize + (this.active ? this.level * this.extraSize : 0))
        .fill($r('app.color.accent_soft'))
        .animation({ duration: 150, curve: Curve.EaseOut })
      Circle()
        .width(this.baseSize)
        .height(this.baseSize)
        .fill(this.active ? $r('app.color.accent') : $r('app.color.muted'))
      SymbolGlyph($r('sys.symbol.mic'))
        .fontSize(48)
        .fontColor([$r('app.color.on_accent')])
    }
    .width(this.baseSize + this.extraSize)
    .height(this.baseSize + this.extraSize)
    .onClick((): void => {
      this.onTap();
    })
  }
}
