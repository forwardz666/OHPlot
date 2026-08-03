// ArkSciDAVis Export Dialog
// Dialog for exporting table data to CSV/ASCII format.
// DocumentViewPicker picks the target; the queued exportASCII command
// writes into the sandbox and the asciiExported event (QtEventHost)
// copies the file out to the picker URI.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { picker } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';
import { getAppString } from '../../components/LocaleHelper';
import {
  ACCENT, TEXT, TEXT_MUTED, TEXT_LIST, TEXT_HINT, TEXT_EMPTY,
  PANEL_BORDER, BTN_BG, BTN_BG_ACCENT, BTN_TEXT, BTN_TEXT_ACCENT,
  RADIUS_4, RADIUS_8, BTN_HEIGHT, BTN_GAP,
  FS_DIALOG_TITLE, FS_DIALOG_LABEL, FS_DIALOG_BODY, FS_DIALOG_SMALL, FS_DIALOG_HINT,
  SPACING_4, SPACING_6, SPACING_8, SPACING_12, SPACING_16,
  BACKDROP_COLOR, SHADOW_RADIUS, SHADOW_COLOR, SHADOW_OFFSET_X, SHADOW_OFFSET_Y
} from '../../components/Theme';

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
      this.statusMsg = getAppString('msg_select_table');
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
      this.statusMsg = getAppString('msg_export_failed') + (e as Error).message;
    }
  }

  build() {
    if (this.isVisible) {
      Stack() {
        // Modal backdrop
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(BACKDROP_COLOR)
          .onClick(() => {
            this.isVisible = false;
          })

        // Dialog box
        Column() {
          // Title
          Text($r('app.string.dlg_export_title'))
            .fontSize(FS_DIALOG_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT)
            .margin({ top: SPACING_16, bottom: SPACING_12 })

          Scroll() {
            Column() {
              // Table selection
              Row() {
                Text($r('app.string.dlg_export_table'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(80)
                if (this.tableList.length > 0) {
                  Scroll() {
                    Column() {
                      ForEach(this.tableList, (table: TableInfo) => {
                        Text(table.name)
                          .fontSize(FS_DIALOG_SMALL)
                          .fontColor(table.name === this.selectedTable ? ACCENT : TEXT_LIST)
                          .fontWeight(table.name === this.selectedTable ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: SPACING_4, bottom: SPACING_4, left: SPACING_6 })
                          .width('100%')
                          .onClick(() => { this.selectedTable = table.name; })
                      }, (table: TableInfo) => table.name)
                    }
                  }
                  .layoutWeight(1)
                  .height(100)
                  .border({ width: 1, color: PANEL_BORDER })
                } else {
                  Text($r('app.string.common_no_tables'))
                    .fontSize(FS_DIALOG_SMALL)
                    .fontColor(TEXT_EMPTY)
                }
              }
              .width('100%')
              .margin({ bottom: SPACING_12 })

              // Separator
              Row() {
                Text($r('app.string.dlg_separator'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(80)
                ForEach(this.separators, (label: string, idx: number) => {
                  Text(label)
                    .fontSize(FS_DIALOG_SMALL)
                    .fontColor(idx === this.selSepIdx ? ACCENT : TEXT_LIST)
                    .fontWeight(idx === this.selSepIdx ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: SPACING_6, right: SPACING_6 })
                    .onClick(() => {
                      this.selSepIdx = idx;
                      this.separator = this.separatorValues[idx];
                    })
                }, (label: string) => label)
              }
              .width('100%')
              .margin({ bottom: SPACING_8 })

              // Column names toggle
              Row() {
                Text($r('app.string.dlg_export_include_names'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.includeColNames })
                  .onChange((val: boolean) => { this.includeColNames = val; })
              }
              .width('100%')
              .margin({ bottom: SPACING_6 })

              // Status message
              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(FS_DIALOG_HINT)
                  .fontColor(TEXT_HINT)
                  .margin({ top: SPACING_8, bottom: SPACING_4 })
              }
            }
            .padding({ left: SPACING_16, right: SPACING_16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Buttons
          Row() {
            Button($r('app.string.common_cancel'))
              .fontSize(FS_DIALOG_LABEL)
              .height(BTN_HEIGHT)
              .backgroundColor(BTN_BG)
              .fontColor(BTN_TEXT)
              .borderRadius(RADIUS_4)
              .onClick(() => {
                this.isVisible = false;
              })
            Button($r('app.string.dlg_export_action'))
              .fontSize(FS_DIALOG_LABEL)
              .height(BTN_HEIGHT)
              .backgroundColor(BTN_BG_ACCENT)
              .fontColor(BTN_TEXT_ACCENT)
              .borderRadius(RADIUS_4)
              .margin({ left: BTN_GAP })
              .onClick(() => {
                this.onExport();
              })
          }
          .width('100%')
          .padding({ left: SPACING_16, right: SPACING_16, bottom: SPACING_16 })
          .justifyContent(FlexAlign.End)
        }
        .width(380)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(RADIUS_8)
        .shadow({ radius: SHADOW_RADIUS, color: SHADOW_COLOR, offsetX: SHADOW_OFFSET_X, offsetY: SHADOW_OFFSET_Y })
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
