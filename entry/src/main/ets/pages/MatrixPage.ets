// ArkSciDAVis Matrix Page
// Read-only matrix data grid loaded from Qt backend via getMatrixData.
// Follows TablePage.ets data-loading pattern and DataTable.ets grid rendering.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface MatrixData {
  rows: number;
  cols: number;
  cells: string[][];
}

interface MatrixResponse {
  success: boolean;
  data?: MatrixData;
  error?: string;
}

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct MatrixPage {
  @Prop @Watch('onMatrixNameChange') matrixName: string = '';
  @State refreshKey: number = 0;
  @State cells: string[][] = [];
  @State numRows: number = 0;
  @State numCols: number = 0;
  @State isLoading: boolean = false;
  // Pre-computed column widths: computed once in loadCurrentMatrix(), not per render
  @State colWidths: number[] = [];

  aboutToAppear(): void {
    this.loadCurrentMatrix();
  }

  onMatrixNameChange(): void {
    this.loadCurrentMatrix();
  }

  onRefreshKeyChange(): void {
    if (this.matrixName) {
      this.loadCurrentMatrix();
    }
  }

  loadCurrentMatrix(): void {
    if (!this.matrixName) {
      this.cells = [];
      this.numRows = 0;
      this.numCols = 0;
      this.colWidths = [];
      return;
    }
    this.isLoading = true;
    try {
      let injector = qohos as QohosInjector;
      let result = injector.callQtCommand('getMatrixData', JSON.stringify({ matrixId: this.matrixName }));
      hilog.info(DOMAIN, TAG, 'MatrixPage getMatrixData: %{public}s', result);
      let parsed = JSON.parse(result) as MatrixResponse;
      if (parsed.success && parsed.data) {
        this.cells = parsed.data.cells || [];
        this.numRows = parsed.data.rows || 0;
        this.numCols = parsed.data.cols || 0;
        hilog.info(DOMAIN, TAG,
          'MatrixPage diag: rows=%{public}d cols=%{public}d cellsLen=%{public}d',
          this.numRows, this.numCols, this.cells.length);
      } else {
        this.cells = [];
        this.numRows = 0;
        this.numCols = 0;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'MatrixPage parse error: %{public}s', JSON.stringify(e));
      this.cells = [];
      this.numRows = 0;
      this.numCols = 0;
    }
    // Pre-compute column widths once after data loads
    this.colWidths = this.computeColWidths(this.cells);
    this.isLoading = false;
  }

  /**
   * Returns the display width of a single character.
   * CJK characters (Chinese, Japanese, Korean) are approximately 2x wider than ASCII.
   */
  private charDisplayWidth(ch: string): number {
    const code: number = ch.charCodeAt(0);
    if (code >= 0x20 && code <= 0x7e) {
      return 1;
    }
    if (code >= 0x4e00 && code <= 0x9fff) {
      return 2;
    }
    if (code >= 0x3400 && code <= 0x4dbf) {
      return 2;
    }
    if (code >= 0xff00 && code <= 0xffef) {
      return 2;
    }
    if (code >= 0x3000 && code <= 0x303f) {
      return 2;
    }
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
   * Pure helper: compute optimal column widths from cell data.
   * Called once per data load, NOT per render.
   */
  private computeColWidths(cells: string[][]): number[] {
    const charWidth: number = 8;
    const minPadding: number = 20;
    const minWidth: number = 60;
    const maxWidth: number = 200;
    const widths: number[] = [];
    for (let c = 0; c < this.numCols; c++) {
      let maxLen: number = 0;
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

  /**
   * Check if a cell value is numeric (for right-alignment).
   */
  private isNumeric(value: string): boolean {
    if (value === '') {
      return false;
    }
    const trimmed: string = value.trim();
    if (trimmed === '') {
      return false;
    }
    const num: number = Number(trimmed);
    return !isNaN(num);
  }

  onRefresh(): void {
    if (this.matrixName) {
      this.refreshKey++;
    }
  }

  build() {
    Column() {
      // Toolbar row
      Row() {
        Text(getAppString('menu_matrix') + ': ' + (this.matrixName || getAppString('common_empty')))
          .fontSize(14)
          .fontColor('#333333')
          .layoutWeight(1)
        Button($r('app.string.common_refresh'))
          .fontSize(12)
          .height(28)
          .onClick(() => {
            this.onRefresh();
          })
      }
      .width('100%')
      .height(36)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#F8F8F8')
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 1 }, color: '#E0E0E0' })

      // Matrix grid area
      if (this.numRows === 0 && this.numCols === 0 && !this.isLoading) {
        // Empty state
        Column() {
          Text(this.matrixName
            ? 'Matrix "' + this.matrixName + '" is empty'
            : 'No matrix selected')
            .fontSize(16)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .width('100%')
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
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .border({ width: 1, color: '#CCCCCC' })
      } else {
        // Matrix grid: Stack with header on top, scrollable body below
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
                    .backgroundColor('#FAFAFA')
                    .border({ width: { right: 1, bottom: 1 }, color: '#E0E0E0' })

                  ForEach(rowData, (cell: string, colIdx: number) => {
                    const textAlign: TextAlign = this.isNumeric(cell) ? TextAlign.End : TextAlign.Start;
                    Text(cell || '')
                      .width(this.colWidths[colIdx] ?? 60)
                      .height(24)
                      .fontSize(12)
                      .fontColor('#000000')
                      .padding({ left: 6, right: 6 })
                      .textAlign(textAlign)
                      .backgroundColor('#FFFFFF')
                      .border({ width: { right: 1, bottom: 1 }, color: '#E8E8E8' })
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
            // Empty top-left corner
            Text('')
              .width(40)
              .height(28)
              .backgroundColor('#F5F5F5')
              .border({ width: { right: 1, bottom: 1 }, color: '#D0D0D0' })

            // Column numbers 1..cols
            ForEach(this.colWidths, (_: number, idx: number) => {
              Text((idx + 1).toString())
                .width(this.colWidths[idx] ?? 60)
                .height(28)
                .fontSize(12)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
                .backgroundColor('#F5F5F5')
                .border({ width: { right: 1, bottom: 1 }, color: '#D0D0D0' })
            }, (idx: number) => 'h' + idx.toString())
          }
          .width('100%')
          .height(28)
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .border({ width: 1, color: '#CCCCCC' })
      }
    }
    .width('100%')
    .height('100%')
  }
}
