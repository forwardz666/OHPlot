// ArkSciDAVis DataTable Component
// A spreadsheet-style grid for displaying table data.
// Data is loaded from the Qt backend via callQtCommand NAPI.
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';
import { getAppString } from './LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface TableData {
  name: string;
  rows: number;
  cols: number;
  colNames: string[];
  data: string[][];
}

interface TableDataResponse {
  success: boolean;
  data?: TableData;
  error?: string;
}

@Component
export struct DataTable {
  @Prop @Watch('onTableNameChange') tableName: string = '';
  @Prop @Watch('onRefreshKeyChange') refreshKey: number = 0;
  @State colNames: string[] = [];
  @State cells: string[][] = [];
  @State numRows: number = 0;
  @State numCols: number = 0;
  @Link selectedRow: number;
  @Link selectedCol: number;
  @State isLoading: boolean = false;
  @State editingRow: number = -1;
  @State editingCol: number = -1;
  @State editingText: string = '';
  // Pre-computed column widths: computed once in loadCurrentTable(), not per render
  @State colWidths: number[] = [];

  aboutToAppear(): void {
    this.loadCurrentTable();
  }

  onTableNameChange(): void {
    this.loadCurrentTable();
  }

  onRefreshKeyChange(): void {
    if (this.tableName) {
      this.loadCurrentTable();
    }
  }

  loadCurrentTable(): void {
    if (!this.tableName) {
      this.colNames = [];
      this.cells = [];
      this.numRows = 0;
      this.numCols = 0;
      return;
    }
    this.isLoading = true;
    let injector = qohos as QohosInjector;
    let result = injector.callQtCommand('getTableData', JSON.stringify({ tableId: this.tableName }));
    hilog.info(DOMAIN, TAG, 'DataTable loadData: %{public}s', result);
    try {
      let parsed = JSON.parse(result) as TableDataResponse;
      if (parsed.success && parsed.data) {
        this.colNames = parsed.data.colNames || [];
        this.cells = parsed.data.data || [];
        this.numRows = parsed.data.rows || 0;
        this.numCols = parsed.data.cols || 0;
        hilog.info(DOMAIN, TAG,
          'DataTable diag: rows=%{public}d cols=%{public}d colNamesLen=%{public}d cellsLen=%{public}d',
          this.numRows, this.numCols, this.colNames.length, this.cells.length);
        if (this.cells.length > 0) {
          hilog.info(DOMAIN, TAG, 'DataTable diag: firstRow=%{public}s',
            JSON.stringify(this.cells[0]));
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'DataTable parse error: %{public}s', JSON.stringify(e));
    }
    // Pre-compute column widths once after data loads
    this.colWidths = this.computeColWidths(this.colNames, this.cells);
    this.isLoading = false;
  }

  /**
   * Returns the display width of a single character.
   * CJK characters (Chinese, Japanese, Korean) are approximately 2x wider than ASCII.
   */
  private charDisplayWidth(ch: string): number {
    const code: number = ch.charCodeAt(0);
    // ASCII printable
    if (code >= 0x20 && code <= 0x7e) {
      return 1;
    }
    // CJK Unified Ideographs
    if (code >= 0x4e00 && code <= 0x9fff) {
      return 2;
    }
    // CJK Unified Ideographs Extension A
    if (code >= 0x3400 && code <= 0x4dbf) {
      return 2;
    }
    // CJK Symbols / Fullwidth Forms / Halfwidth Forms
    if (code >= 0xff00 && code <= 0xffef) {
      return 2;
    }
    // CJK Punctuation (ideographic comma, period, quotes, brackets, etc.)
    if (code >= 0x3000 && code <= 0x303f) {
      return 2;
    }
    // Default: treat as width 1
    return 1;
  }

  /**
   * Returns the total display width of a string accounting for CJK double-width characters.
   */
  private strDisplayWidth(s: string): number {
    let total: number = 0;
    for (let i = 0; i < s.length; i++) {
      total += this.charDisplayWidth(s[i]);
    }
    return total;
  }

  /**
   * Pure helper: compute optimal column widths from header names and cell data.
   * Called once per data load, NOT per render (avoids O(R²×C) perf issue).
   */
  private computeColWidths(colNames: string[], cells: string[][]): number[] {
    const charWidth: number = 8;
    const minPadding: number = 20;
    const minWidth: number = 60;
    const maxWidth: number = 200;
    const widths: number[] = [];
    for (let c = 0; c < colNames.length; c++) {
      let maxLen: number = this.strDisplayWidth(colNames[c]);
      for (let r = 0; r < cells.length; r++) {
        if (c < cells[r].length) {
          const val: string = cells[r][c] || '';
          const displayLen: number = this.strDisplayWidth(val);
          if (displayLen > maxLen) {
            maxLen = displayLen;
          }
        }
      }
      const w: number = Math.max(minWidth, Math.min(maxWidth, maxLen * charWidth + minPadding));
      widths.push(w);
    }
    return widths;
  }

  commitEdit(rowIdx: number, colIdx: number): void {
    try {
      let injector = qohos as QohosInjector;
      let args = JSON.stringify({
        tableId: this.tableName,
        row: rowIdx,
        col: colIdx,
        value: this.editingText
      });
      let result = injector.callQtCommand('setCellValue', args);
      hilog.info(DOMAIN, TAG, 'setCellValue result: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setCellValue error: %{public}s', JSON.stringify(e));
    }
    this.editingRow = -1;
    this.editingCol = -1;
    this.loadCurrentTable();
  }

  refreshFromQt(): void {
    this.loadCurrentTable();
  }

  build() {
    if (this.numRows === 0 && this.numCols === 0 && !this.isLoading) {
      // Empty state
      Column() {
        Text(this.tableName
          ? getAppString('msg_table_empty_prefix') + this.tableName + getAppString('msg_table_empty_suffix')
          : getAppString('msg_no_table_selected'))
          .fontSize(16)
          .fontColor('#999999')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .border({ width: 1, color: '#CCCCCC' })
    } else if (this.isLoading && this.numRows === 0) {
      // Loading state
      Column() {
        Text($r('app.string.common_loading'))
          .fontSize(16)
          .fontColor('#999999')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .border({ width: 1, color: '#CCCCCC' })
    } else {
      // Table view: Stack with header on top, scrollable body below
      Stack({ alignContent: Alignment.TopStart }) {
        // Scrollable body - fills entire space
        Scroll() {
          Column() {
            ForEach(this.cells, (rowData: string[], rowIdx: number) => {
              Row() {
                // Row number
                Text((rowIdx + 1).toString())
                  .width(40)
                  .height(24)
                  .fontSize(11)
                  .fontColor('#999999')
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.selectedRow === rowIdx ? '#E3F2FD' : '#FAFAFA')
                  .border({ width: { right: 1, bottom: 1 }, color: '#E0E0E0' })

                ForEach(rowData, (cell: string, colIdx: number) => {
                  if (this.editingRow === rowIdx && this.editingCol === colIdx) {
                    TextInput({ text: this.editingText, placeholder: '' })
                      .fontSize(12)
                      .padding({ left: 6, right: 6 })
                      .height(24)
                      .width(this.colWidths[colIdx] ?? 60)
                      .backgroundColor('#FFFFFF')
                      .border({ width: { right: 1, bottom: 1 }, color: '#2196F3' })
                      .onSubmit(() => {
                        this.commitEdit(rowIdx, colIdx);
                      })
                      .onBlur(() => {
                        this.editingRow = -1;
                        this.editingCol = -1;
                      })
                      .onChange((value: string) => {
                        this.editingText = value;
                      })
                  } else {
                    Text(cell || '')
                      .width(this.colWidths[colIdx] ?? 60)
                      .height(24)
                      .fontSize(12)
                      .fontColor('#000000')
                      .padding({ left: 6, right: 6 })
                      .backgroundColor(
                        this.selectedRow === rowIdx && this.selectedCol === colIdx
                          ? '#BBDEFB' : this.selectedRow === rowIdx
                          ? '#E3F2FD' : '#FFFFFF')
                      .border({ width: { right: 1, bottom: 1 }, color: '#E8E8E8' })
                      .onClick(() => {
                        this.selectedRow = rowIdx;
                        this.selectedCol = colIdx;
                      })
                      .gesture(
                        TapGesture({ count: 2 }).onAction(() => {
                          this.editingRow = rowIdx;
                          this.editingCol = colIdx;
                          this.editingText = cell;
                        })
                      )
                  }
                }, (cell: string, colIdx: number) => 'c' + rowIdx.toString() + '_' + colIdx.toString())
              }
              .width('100%')
            }, (rowData: string[], rowIdx: number) => 'r' + rowIdx.toString())
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
        .padding({ top: 28 })

        // Header row - absolutely positioned at top
        Row() {
          Text('#')
            .width(40)
            .height(28)
            .fontSize(12)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .backgroundColor('#F5F5F5')
            .border({ width: { right: 1, bottom: 1 }, color: '#D0D0D0' })

          ForEach(this.colNames, (colName: string, idx: number) => {
            Text(colName)
              .width(this.colWidths[idx] ?? 60)
              .height(28)
              .fontSize(12)
              .fontColor('#333333')
              .padding({ left: 6, right: 6 })
              .backgroundColor('#F5F5F5')
              .border({ width: { right: 1, bottom: 1 }, color: '#D0D0D0' })
          }, (colName: string, idx: number) => 'h' + idx.toString())
        }
        .width('100%')
        .height(28)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .border({ width: 1, color: '#CCCCCC' })
    }
  }
}

// Helper interface for the qohos injector
interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}
