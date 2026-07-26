// ArkSciDAVis About Dialog
@Component
export struct AboutDialog {
  @Link currentLocale: string;
  @State isVisible: boolean = false;

  build() {
    if (this.isVisible) {
      Stack() {
        // Modal backdrop
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => {
            this.isVisible = false;
          })

        // Dialog box
        Column() {
          // Title
          Text($r('app.string.about_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 20, bottom: 8 })

          // Version
          Text($r('app.string.about_version'))
            .fontSize(14)
            .fontColor('#555555')
            .margin({ bottom: 6 })

          // Description
          Text($r('app.string.about_desc'))
            .fontSize(12)
            .fontColor('#777777')
            .textAlign(TextAlign.Center)
            .margin({ left: 20, right: 20, bottom: 6 })

          // Copyright
          Text($r('app.string.about_copyright'))
            .fontSize(11)
            .fontColor('#999999')
            .margin({ bottom: 16 })

          // Close button
          Button($r('app.string.about_close'))
            .fontSize(14)
            .width(100)
            .height(32)
            .backgroundColor('#E0E0E0')
            .fontColor('#333333')
            .borderRadius(4)
            .onClick(() => {
              this.isVisible = false;
            })
        }
        .width(300)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
        .padding({ bottom: 20 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
  }

  show(): void {
    this.isVisible = true;
  }

  close(): void {
    this.isVisible = false;
  }
}
