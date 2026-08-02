// ArkSciDAVis Table Page
// Displays spreadsheet data loaded from Qt backend.
// Used in Level 2 to replace the Qt table view.
import { DataTable } from '../components/DataTable';
import { ColumnSidebar } from '../components/ColumnSidebar';
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../components/LocaleHelper';

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
  @State selectedRow: number = -1;
  @State selectedCol: number = -1;
  @State tableList: TableInfo[] = [];
  @StorageProp('pendingTableRefresh') @Watch('onPendingTableRefreshChange') pendingTableRefresh: string = '';
  @StorageProp('pendingTableListRefresh') @Watch('onPendingTableListRefreshChange') pendingTableListRefresh: string = '';
  private lastRefreshTime: number = 0;
  private lastListRefreshTime: number = 0;

  aboutToAppear(): void {
    this.loadTableList();
  }

  onPendingTableRefreshChange(): void {
    if (this.pendingTableRefresh === '') return;
    this.debouncedRefreshData(this.pendingTableRefresh);
  }

  onPendingTableListRefreshChange(): void {
    if (this.pendingTableListRefresh === '') return;
    this.debouncedRefreshList();
  }

  private debouncedRefreshData(value: string): void {
    const now: number = Date.now();
    if (now - this.lastRefreshTime < 500) return;
    this.lastRefreshTime = now;
    const tid: string = (value.indexOf('|') >= 0) ? value.split('|')[0] : value;
    hilog.info(DOMAIN, TAG, 'Auto-refresh table data for %{public}s (raw: %{public}s)', tid, value);
    if (this.tableName) {
      this.refreshKey++;
    }
  }

  private debouncedRefreshList(): void {
    const now: number = Date.now();
    if (now - this.lastListRefreshTime < 500) return;
    this.lastListRefreshTime = now;
    hilog.info(DOMAIN, TAG, 'Auto-refresh table list');
    this.loadTableList();
  }

  loadTableList(): void {
    try {
      let injector = qohos as QohosInjector;
      let result = injector.callQtCommand('getTableList', '{}');
      hilog.info(DOMAIN, TAG, 'TablePage getTableList: %{public}s', result);
      let parsed = JSON.parse(result) as TableListResponse;
      if (parsed.success && parsed.data && parsed.data.length > 0) {
        this.tableList = parsed.data;
        // Auto-select the first table if none selected
        if (!this.tableName) {
          this.tableName = parsed.data[0].name;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'TablePage parse error: %{public}s', (e as Error).message);
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
        Text(getAppString('page_table_prefix') + (this.tableName || getAppString('common_empty')))
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

      // Data table + column sidebar
      Row() {
        DataTable({
          tableName: this.tableName,
          refreshKey: this.refreshKey,
          selectedRow: $selectedRow,
          selectedCol: $selectedCol
        })
          .layoutWeight(1)

        ColumnSidebar({
          selectedCol: $selectedCol,
          tableName: this.tableName
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
