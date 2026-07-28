// ArkSciDAVis Table Page
// Displays spreadsheet data loaded from Qt backend.
// Used in Level 2 to replace the Qt table view.
import { DataTable } from '../components/DataTable';
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

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

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct TablePage {
  @State tableName: string = '';
  @State refreshKey: number = 0;
  @State tableList: TableInfo[] = [];

  aboutToAppear(): void {
    this.loadTableList();
  }

  loadTableList(): void {
    let injector = qohos as QohosInjector;
    let result = injector.callQtCommand('getTableList', '{}');
    hilog.info(DOMAIN, TAG, 'TablePage getTableList: %{public}s', result);
    try {
      let parsed = JSON.parse(result) as TableListResponse;
      if (parsed.success && parsed.data && parsed.data.length > 0) {
        this.tableList = parsed.data;
        // Auto-select the first table if none selected
        if (!this.tableName) {
          this.tableName = parsed.data[0].name;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'TablePage parse error: %{public}s', JSON.stringify(e));
    }
  }

  onRefresh(): void {
    if (this.tableName) {
      this.refreshKey++;
    }
    // Also refresh the table list from backend
    this.loadTableList();
  }

  onSelectTable(name: string): void {
    this.tableName = name;
    this.refreshKey++; // force reload even if same name
  }

  build() {
    Column() {
      // Toolbar row
      Row() {
        Text('Table: ' + (this.tableName || '(none)'))
          .fontSize(14)
          .fontColor('#333333')
          .layoutWeight(1)
        if (this.tableList.length > 1) {
          // Table selector: show all tables, highlight current
          Scroll() {
            Row() {
              ForEach(this.tableList, (table: TableInfo) => {
                Text(table.name)
                  .fontSize(12)
                  .fontColor(table.name === this.tableName ? '#0078D7' : '#666666')
                  .fontWeight(table.name === this.tableName ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 8, right: 8 })
                  .onClick(() => this.onSelectTable(table.name))
              }, (table: TableInfo) => table.name)
            }
          }
          .height(28)
          .flexGrow(1)
        }
        Button('Refresh')
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

      // Data table
      DataTable({ tableName: this.tableName, refreshKey: this.refreshKey })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
