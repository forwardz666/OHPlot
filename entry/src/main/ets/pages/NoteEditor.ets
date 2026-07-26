// ArkSciDAVis Note Editor Component
@Component
export struct NoteEditor {
  @Link currentLocale: string;
  @State noteText: string = '';

  build() {
    Column() {
      Row() {
        Text($r('app.string.notes_title'))
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 8, top: 4, bottom: 4 })
      }
      .width('100%')
      .backgroundColor('#F5F5F5')
      .border({ width: { bottom: 1 }, color: '#CCCCCC' })

      TextArea({ text: this.noteText, placeholder: '...' })
        .width('100%')
        .layoutWeight(1)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.noteText = value;
        })
    }
    .width('100%')
    .height('100%')
  }
}
