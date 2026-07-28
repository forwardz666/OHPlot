// ArkSciDAVis DataTable Component
// A spreadsheet-style grid for displaying table data.
// Data is loaded from the Qt backend via callQtCommand NAPI.
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';

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
  @State selectedRow: number = -1;
  @State selectedCol: number = -1;
  @State isLoading: boolean = false;

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
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'DataTable parse error: %{public}s', JSON.stringify(e));
    }
    this.isLoading = false;
  }

  refreshFromQt(): void {
    this.loadCurrentTable();
  }

  build() {
    Column() {
      if (this.numRows === 0 && this.numCols === 0 && !this.isLoading) {
        // Empty state
        Column() {
          Text(this.tableName ? 'Table \'' + this.tableName + '\' is empty' : 'No table selected')
            .fontSize(16)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.isLoading && this.numRows === 0) {
        // Loading state
        Column() {
          Text('Loading...')
            .fontSize(16)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // Table header
        Row() {
          // Row number column header
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
              .flexGrow(1)
              .height(28)
              .fontSize(12)
              .fontColor('#333333')
              .padding({ left: 6, right: 6 })
              .backgroundColor('#F5F5F5')
              .border({ width: { right: 1, bottom: 1 }, color: '#D0D0D0' })
          }, (colName: string, idx: number) => 'h' + idx.toString())
        }
        .width('100%')

        // Table body - scrollable
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
                  Text(cell || '')
                    .flexGrow(1)
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
                }, (cell: string, colIdx: number) => 'c' + rowIdx.toString() + '_' + colIdx.toString())
              }
              .width('100%')
            }, (rowData: string[], rowIdx: number) => 'r' + rowIdx.toString())
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .border({ width: 1, color: '#CCCCCC' })
  }
}

// Helper interface for the qohos injector
interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}
