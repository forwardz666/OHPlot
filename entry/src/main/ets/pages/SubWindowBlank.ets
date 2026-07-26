// Blank transparent page loaded into Qt sub-windows.
// Contains NO XComponent so the sub-window stays transparent and the
// main window's Qt-rendered XComponent surface shows through.
@Entry
@Component
struct SubWindowBlank {
  build() {
    Stack() {
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
