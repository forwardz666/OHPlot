// ArkSciDAVis Export Dialog
// Dialog for exporting table data to CSV/ASCII format.
// DocumentViewPicker picks the target; the queued exportASCII command
// writes into the sandbox and the asciiExported event (QtEventHost)
// copies the file out to the picker URI.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { picker } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface TableInfo {
  name: string;
  label: string;
  rows: number;
  cols: number;
}

interface TableListResponse {
  success: boolean;
  data?: TableInfo[];
  error?: string;
}

// exportASCII command payload (mirrors scidavis/src/main.cpp).
interface ExportAsciiArgs {
  tableId: string;
  path: string;
  separator: string;
  colNames: boolean;
}

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct ExportDialog {
  // aboutToAppear only fires once (the component stays mounted while
  // build() short-circuits on isVisible), so refresh the table list
  // every time the dialog becomes visible.
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State tableList: TableInfo[] = [];
  @State selectedTable: string = '';
  @State separator: string = '\t';
  @State includeColNames: boolean = true;
  @State statusMsg: string = '';

  private separators: string[] = ['Tab', 'Comma', 'Semicolon', 'Space'];
  private separatorValues: string[] = ['\t', ',', ';', ' '];
  private selSepIdx: number = 0;

  aboutToAppear(): void {
    this.loadTableList();
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadTableList();
    }
  }

  loadTableList(): void {
    let injector = qohos as QohosInjector;
    let result = injector.callQtCommand('getTableList', '{}');
    try {
      let parsed = JSON.parse(result) as TableListResponse;
      if (parsed.success && parsed.data) {
        this.tableList = parsed.data;
        if (!this.selectedTable && parsed.data.length > 0) {
          this.selectedTable = parsed.data[0].name;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ExportDialog load tables error: %{public}s', JSON.stringify(e));
    }
  }

  async onExport(): Promise<void> {
    if (!this.selectedTable) {
      this.statusMsg = 'Please select a table first.';
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker();
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [this.selectedTable + '.txt'];
      const uris: string[] = await docPicker.save(opts);
      if (uris.length === 0) {
        return; // user cancelled
      }
      // QtEventHost copies the sandbox file to this URI on asciiExported.
      AppStorage.setOrCreate<string>('pendingExportUri', uris[0]);
      const ctx = getContext(this) as common.UIAbilityContext;
      const dest: string = ctx.filesDir + '/' + this.selectedTable + '.txt';
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('exportASCII', JSON.stringify({
        tableId: this.selectedTable,
        path: dest,
        separator: this.separator,
        colNames: this.includeColNames
      } as ExportAsciiArgs));
      hilog.info(DOMAIN, TAG, 'exportASCII(%{public}s) queued: %{public}s', dest, result);
      this.isVisible = false; // toast arrives via the event channel
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ExportDialog picker failed: %{public}s', (e as Error).message);
      this.statusMsg = 'Export failed: ' + (e as Error).message;
    }
  }

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
          Text('Export ASCII Data')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Table selection
              Row() {
                Text('Table:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                if (this.tableList.length > 0) {
                  Scroll() {
                    Column() {
                      ForEach(this.tableList, (table: TableInfo) => {
                        Text(table.name)
                          .fontSize(12)
                          .fontColor(table.name === this.selectedTable ? '#0078D7' : '#666666')
                          .fontWeight(table.name === this.selectedTable ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 3, bottom: 3, left: 6 })
                          .width('100%')
                          .onClick(() => { this.selectedTable = table.name; })
                      }, (table: TableInfo) => table.name)
                    }
                  }
                  .layoutWeight(1)
                  .height(100)
                  .border({ width: 1, color: '#D0D0D0' })
                } else {
                  Text('No tables available')
                    .fontSize(12)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .margin({ bottom: 12 })

              // Separator
              Row() {
                Text('Separator:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                ForEach(this.separators, (label: string, idx: number) => {
                  Text(label)
                    .fontSize(12)
                    .fontColor(idx === this.selSepIdx ? '#0078D7' : '#666666')
                    .fontWeight(idx === this.selSepIdx ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 6 })
                    .onClick(() => {
                      this.selSepIdx = idx;
                      this.separator = this.separatorValues[idx];
                    })
                }, (label: string) => label)
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Column names toggle
              Row() {
                Text('Include column names:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.includeColNames })
                  .onChange((val: boolean) => { this.includeColNames = val; })
              }
              .width('100%')
              .margin({ bottom: 6 })

              // Status message
              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(11)
                  .fontColor('#888888')
                  .margin({ top: 8, bottom: 4 })
              }
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Buttons
          Row() {
            Button('Cancel')
              .fontSize(14)
              .height(32)
              .backgroundColor('#E0E0E0')
              .fontColor('#333333')
              .borderRadius(4)
              .onClick(() => {
                this.isVisible = false;
              })
            Button('Export')
              .fontSize(14)
              .height(32)
              .backgroundColor('#0078D7')
              .fontColor('#FFFFFF')
              .borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => {
                this.onExport();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(380)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
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
