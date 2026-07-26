// ArkSciDAVis Status Bar Component
@Component
export struct StatusBar {
  statusText: string = '';

  build() {
    Row() {
      Text(this.statusText)
        .fontSize(12)
        .fontColor('#666666')
        .textAlign(TextAlign.Start)
        .layoutWeight(1)
        .padding({ left: 8 })
    }
    .width('100%')
    .height(24)
    .backgroundColor('#E8E8E8')
    .border({ width: { top: 1 }, color: '#CCCCCC' })
  }
}
