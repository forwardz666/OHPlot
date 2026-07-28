// OHPlot Script Console Dialog (placeholder stub)
@CustomDialog
export struct ScriptConsoleDialog {
  controller: CustomDialogController;

  build() {
    Column() {
      Text('Script Console')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 20, bottom: 8 })

      TextArea({ placeholder: 'Scripting backend is not yet available on OpenHarmony.' })
        .enabled(false)
        .width(280)
        .height(160)
        .fontSize(13)
        .fontColor('#555555')
        .backgroundColor('#F5F5F5')
        .borderRadius(4)
        .margin({ bottom: 8 })

      Text('TODO: muParser/Python console will be wired in a later phase.')
        .fontSize(11)
        .fontColor('#999999')
        .margin({ bottom: 16 })

      Button('Close')
        .fontSize(14)
        .width(100)
        .height(32)
        .backgroundColor('#E0E0E0')
        .fontColor('#333333')
        .borderRadius(4)
        .onClick(() => {
          this.controller.close();
        })
    }
    .width(300)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
    .padding({ bottom: 20 })
    .alignItems(HorizontalAlign.Center)
  }
}
