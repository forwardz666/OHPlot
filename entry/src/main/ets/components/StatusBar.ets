// ArkSciDAVis Status Bar Component
import * as Theme from './Theme';

@Component
export struct StatusBar {
  statusText: string = '';

  build() {
    Row() {
      Text(this.statusText)
        .fontSize(Theme.FS_STATUS)
        .fontColor(Theme.TEXT_STATUS)
        .textAlign(TextAlign.Start)
        .layoutWeight(1)
        .padding({ left: 8 })
    }
    .width('100%')
    .height(Theme.H_STATUS)
    .backgroundColor(Theme.STATUS_BG)
    .border({ width: { top: 1 }, color: Theme.LINE })
  }
}
