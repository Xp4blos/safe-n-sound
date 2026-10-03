// Equaliser-style chart of the last 8 seconds of sound level. One mirrored bar per time slot, oldest on the
// left, so the chart scrolls like a waveform being recorded.
@Component
export struct LevelChart {
  @Prop bars: number[] = [];
  private chartHeight: number = 120;

  build() {
    Column() {
      Row() {
        ForEach(this.bars, (value: number, index: number) => {
          Column()
            .layoutWeight(1)
            .height(Math.max(4, value * this.chartHeight))
            .margin({ left: 0.75, right: 0.75 })
            .borderRadius(2)
            .backgroundColor($r('app.color.accent'))
            .opacity(0.35 + 0.65 * (index / Math.max(1, this.bars.length - 1)))
        }, (value: number, index: number) => index.toString() + ':' + value.toFixed(2))
      }
      .width('100%')
      .height(this.chartHeight)
      .alignItems(VerticalAlign.Center)

      Row() {
        Text($r('app.string.chart_caption_start'))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
        Blank()
        Text($r('app.string.chart_caption_end'))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
  }
}
