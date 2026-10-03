// Equaliser-style live view: the last 8 seconds of sound, oldest on the left. Each column shows the 16 frequency
// bands (low at the bottom) as brightness; moments the engine reacted to are highlighted in orange.
@Component
export struct SpectrumView {
  @Prop @Watch('redraw') columns: number[] = [];
  @Prop @Watch('redraw') marks: number[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private bandCount: number = 16;
  private viewHeight: number = 140;

  redraw(): void {
    const w = this.canvasWidth;
    const h = this.canvasHeight;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);
    const columnCount = Math.floor(this.columns.length / this.bandCount);
    if (columnCount === 0) {
      return;
    }
    const cw = w / columnCount;
    const ch = h / this.bandCount;
    for (let c = 0; c < columnCount; c++) {
      const marked = this.marks.length > c && this.marks[c] === 1;
      for (let b = 0; b < this.bandCount; b++) {
        const v = this.columns[c * this.bandCount + b];
        if (v < 0.04) {
          continue;
        }
        const alpha = 0.18 + 0.82 * v;
        this.ctx.fillStyle = marked ? 'rgba(245,166,35,' + alpha + ')' : 'rgba(86,142,245,' + alpha + ')';
        this.ctx.fillRect(c * cw + 0.5, h - (b + 1) * ch + 0.5, Math.max(1, cw - 1), Math.max(1, ch - 1));
      }
      if (marked) {
        this.ctx.fillStyle = 'rgba(245,166,35,1)';
        this.ctx.fillRect(c * cw, 0, Math.max(1, cw - 0.5), 3);
      }
    }
  }

  build() {
    Column() {
      Canvas(this.ctx)
        .width('100%')
        .height(this.viewHeight)
        .borderRadius(12)
        .backgroundColor($r('app.color.surface'))
        .onReady((): void => {
          this.redraw();
        })
        .onAreaChange((oldValue: Area, newValue: Area): void => {
          this.canvasWidth = Number(newValue.width);
          this.canvasHeight = Number(newValue.height);
          this.redraw();
        })
      Row() {
        Text($r('app.string.chart_caption_start')).fontSize(12).fontColor($r('app.color.muted'))
        Blank()
        Text($r('app.string.chart_caption_end')).fontSize(12).fontColor($r('app.color.muted'))
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
  }
}
