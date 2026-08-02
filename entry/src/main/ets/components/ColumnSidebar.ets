// ColumnSidebar — right-side panel showing column properties for the
// selected column in a table.  Mirrors the UI style of MatrixOpsDialog.ets
// (font sizes, colours, spacing).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from './LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface ColumnInfo {
  col: number;
  name: string;
  type: string;
  description: string;
  formula: string;
  plotDesignation: string;
}

interface ColumnInfoResponse {
  success: boolean;
  data?: ColumnInfo[];
  error?: string;
}

// Injector interface matching the libqohos.so export shape.
interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct ColumnSidebar {
  @Link selectedCol: number;
  @Prop @Watch('onTableNameChange') tableName: string = '';
  @State columns: ColumnInfo[] = [];
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    this.fetchColumnInfo();
  }

  onTableNameChange(): void {
    this.fetchColumnInfo();
  }

  fetchColumnInfo(): void {
    if (!this.tableName) {
      this.columns = [];
      return;
    }
    this.isLoading = true;
    try {
      const injector: QohosInjector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getColumnInfo',
        JSON.stringify({ tableId: this.tableName }));
      hilog.info(DOMAIN, TAG, 'ColumnSidebar getColumnInfo: %{public}s', result);
      const parsed: ColumnInfoResponse = JSON.parse(result) as ColumnInfoResponse;
      if (parsed.success && parsed.data) {
        this.columns = parsed.data;
        // 问题1b: auto-select the first column on mount so the
        // properties/description panel is visible immediately instead of
        // waiting for a tap on the column list (selectedCol starts at -1).
        // Syncing the @Link back to TablePage is acceptable — an explicit
        // first-column selection is the intended default state.
        if (this.selectedCol < 0 && this.columns.length > 0) {
          this.selectedCol = this.columns[0].col;
        }
      } else {
        this.columns = [];
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ColumnSidebar parse error: %{public}s',
        (e as Error).message);
      this.columns = [];
    }
    this.isLoading = false;
  }

  private selectedInfo(): ColumnInfo | undefined {
    if (this.selectedCol < 0 || this.columns.length === 0) {
      return undefined;
    }
    for (let i = 0; i < this.columns.length; i++) {
      if (this.columns[i].col === this.selectedCol) {
        return this.columns[i];
      }
    }
    return undefined;
  }

  @Builder
  propRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#555555')
        .width(100)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)
      Text(value || '\u2014')
        .fontSize(13)
        .fontColor('#333333')
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(2)
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 6 })
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      // ── Header ─────────────────────────────────────────────────────────
      Text(getAppString('sidebar_column_props'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .padding({ left: 12, right: 12, top: 12, bottom: 6 })
        .width('100%')

      Divider()
        .color('#E0E0E0')
        .width('100%')

      // ── Column list ────────────────────────────────────────────────────
      if (this.columns.length > 0) {
        Text(getAppString('sidebar_columns'))
          .fontSize(12)
          .fontColor('#888888')
          .padding({ left: 12, right: 12, top: 8, bottom: 4 })
          .width('100%')

        Scroll() {
          Column() {
            ForEach(this.columns, (col: ColumnInfo, idx: number) => {
              Row() {
                Text((idx + 1).toString())
                  .fontSize(11)
                  .fontColor('#AAAAAA')
                  .width(24)
                  .textAlign(TextAlign.Center)
                Text(col.name)
                  .fontSize(12)
                  .fontColor(col.col === this.selectedCol ? '#0078D7' : '#333333')
                  .fontWeight(col.col === this.selectedCol ? FontWeight.Medium : FontWeight.Normal)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .maxLines(1)
              }
              .width('100%')
              .height(28)
              .padding({ left: 12, right: 12 })
              .backgroundColor(col.col === this.selectedCol ? '#E8F4FD' : Color.Transparent)
              .borderRadius(4)
              .onClick(() => {
                this.selectedCol = col.col;
              })
            }, (col: ColumnInfo) => col.col.toString())
          }
          .width('100%')
          .padding({ top: 2, bottom: 4 })
        }
        .height(140)
        .width('100%')
        .scrollBar(BarState.Auto)

        Divider()
          .color('#E0E0E0')
          .width('100%')
      } else if (this.isLoading) {
        Text(getAppString('common_loading'))
          .fontSize(12)
          .fontColor('#999999')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .width('100%')
      }

      // ── Selected column properties ─────────────────────────────────────
      if (this.selectedCol >= 0) {
        Text(getAppString('sidebar_properties'))
          .fontSize(12)
          .fontColor('#888888')
          .padding({ left: 12, right: 12, top: 8, bottom: 4 })
          .width('100%')

        Scroll() {
          Column() {
            if (this.selectedCol >= 0 && this.selectedCol < this.columns.length) {
              this.propRow(getAppString('sidebar_col_name'),
                this.columns[this.selectedCol].name)
              this.propRow(getAppString('sidebar_description'),
                this.columns[this.selectedCol].description)
              this.propRow(getAppString('sidebar_type'),
                this.columns[this.selectedCol].type
                  ? this.columns[this.selectedCol].type
                  : getAppString('sidebar_type_numeric'))
              this.propRow(getAppString('sidebar_format'), '\u2014')
              this.propRow(getAppString('sidebar_plot_desig'),
                this.columns[this.selectedCol].plotDesignation)
              this.propRow(getAppString('sidebar_formula'),
                this.columns[this.selectedCol].formula)
            } else {
              Text(getAppString('msg_no_column_selected'))
                .fontSize(12)
                .fontColor('#999999')
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      }
    }
    .width(260)
    .height('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { left: 1 }, color: '#E0E0E0' })
  }
}
