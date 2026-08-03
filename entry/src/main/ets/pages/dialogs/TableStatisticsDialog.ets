// TableStatisticsDialog — "Analysis > Statistics on Columns/Rows" dialog (batch 3).
// Statistics result display: table showing rows=statistics (N/Mean/SD/etc.)
// × columns=selected columns. Source table + type (columns/rows) setup.
// Populates by calling tableStatistics command and rendering the response.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface TableStatisticsArgs {
  tableId: string;
  type: string;
  targets?: number[];
}

interface StatColumn {
  name: string;
  rows: string;
  mean: string;
  standardDev: string;
  variance: string;
  sum: string;
  iMax: string;
  max: string;
  iMin: string;
  min: string;
  n: string;
}

interface StatRow {
  row: string;
  cols: string;
  mean: string;
  standardDev: string;
  variance: string;
  sum: string;
  max: string;
  min: string;
  n: string;
}

interface TableStatisticsResponse {
  success: boolean;
  queued?: boolean;
  type: string;
  columns?: StatColumn[];
  rows?: StatRow[];
  error?: string;
}

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

interface ColumnInfo {
  col: number;
  name: string;
  type: string;
}

interface ColumnInfoResponse {
  success: boolean;
  data?: ColumnInfo[];
  error?: string;
}

const COL_STAT_HEADERS: string[] = [
  'Col', 'Rows', 'Mean', 'StdDev', 'Variance', 'Sum', 'iMax', 'Max', 'iMin', 'Min', 'N'
];

const ROW_STAT_HEADERS: string[] = [
  'Row', 'Cols', 'Mean', 'StdDev', 'Variance', 'Sum', 'Max', 'Min', 'N'
];

@Component
export struct TableStatisticsDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop @Watch('onStatTypeChanged') statType: string = 'columns';
  @State tables: TableInfo[] = [];
  @State selTableIdx: number = -1;
  @State colNames: string[] = [];
  @State colIds: number[] = [];
  @State selected: boolean[] = [];
  @State statTypeIdx: number = 0; // 0=columns, 1=rows
  @State colResults: StatColumn[] = [];
  @State rowResults: StatRow[] = [];
  @State hasResults: boolean = false;
  @State statusMsg: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.reload();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.reload();
    }
  }

  onStatTypeChanged(): void {
    // Sync prop change to local index
    if (this.statType === 'rows') {
      this.statTypeIdx = 1;
    } else {
      this.statTypeIdx = 0;
    }
  }

  private reload(): void {
    this.tables = this.fetchTables();
    this.selTableIdx = this.tables.length > 0 ? 0 : -1;
    // Prefer prop value, fallback to 'columns' default
    this.statTypeIdx = this.statType === 'rows' ? 1 : 0;
    this.colResults = [];
    this.rowResults = [];
    this.hasResults = false;
    this.statusMsg = '';
    this.loadColumns();
  }

  private fetchTables(): TableInfo[] {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getTableList', '{}');
      const parsed = JSON.parse(result) as TableListResponse;
      if (parsed.success && parsed.data) {
        return parsed.data;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'TableStatisticsDialog getTableList failed: %{public}s',
        (e as Error).message);
    }
    return [];
  }

  private currentTable(): TableInfo | undefined {
    if (this.selTableIdx < 0 || this.selTableIdx >= this.tables.length) {
      return undefined;
    }
    return this.tables[this.selTableIdx];
  }

  private loadColumns(): void {
    const t = this.currentTable();
    this.colNames = [];
    this.colIds = [];
    this.selected = [];
    if (!t) {
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getColumnInfo',
        JSON.stringify({ tableId: t.name }));
      const parsed = JSON.parse(result) as ColumnInfoResponse;
      if (parsed.success && parsed.data) {
        const names: string[] = [];
        const ids: number[] = [];
        for (let i = 0; i < parsed.data.length; i++) {
          names.push(parsed.data[i].name);
          ids.push(parsed.data[i].col);
        }
        this.colNames = names;
        this.colIds = ids;
        this.selected = names.map((_n: string, idx: number) => idx > 0);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'TableStatisticsDialog getColumnInfo failed: %{public}s',
        (e as Error).message);
    }
  }

  onTablePick(idx: number): void {
    this.selTableIdx = idx;
    this.hasResults = false;
    this.loadColumns();
  }

  private onCalculate(): void {
    const t = this.currentTable();
    if (!t) {
      this.statusMsg = getAppString('msg_select_table');
      return;
    }
    const cols: number[] = [];
    for (let i = 0; i < this.selected.length; i++) {
      if (this.selected[i] && i < this.colIds.length) {
        cols.push(this.colIds[i]);
      }
    }
    if (cols.length === 0) {
      this.statusMsg = getAppString('msg_select_column');
      return;
    }
    const statType: string = this.statTypeIdx === 1 ? 'rows' : 'columns';
    const args: TableStatisticsArgs = {
      tableId: t.name,
      type: statType,
      targets: cols
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('tableStatistics', JSON.stringify(args));
      const parsed = JSON.parse(result) as TableStatisticsResponse;
      // tableStatistics is fire-and-forget: returns {"success":true,"queued":true}
      // No columns/rows data expected in response.
      if (parsed.success && parsed.queued) {
        this.statusMsg = getAppString('msg_done') || 'OK';
        // Show toast-like message that stats window was created
        // Reuse statusMsg mechanism for now
      } else if (parsed.success) {
        // Fallback: success but no queued flag — still treat as fire-and-forget
        this.statusMsg = getAppString('msg_done') || 'OK';
      } else if (parsed.error) {
        this.statusMsg = parsed.error;
      } else {
        this.statusMsg = getAppString('msg_no_table_selected');
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'tableStatistics failed: %{public}s', (e as Error).message);
      this.statusMsg = (e as Error).message;
    }
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('dlg_table_statistics'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Table picker
              Row() {
                Text(getAppString('dlg_export_table'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Scroll() {
                  Column() {
                    ForEach(this.tables, (t: TableInfo, idx: number) => {
                      Text(t.label.length > 0 ? t.label : t.name)
                        .fontSize(12)
                        .fontColor(idx === this.selTableIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.selTableIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.onTablePick(idx); })
                    }, (t: TableInfo, idx: number) => t.name + ':' + idx)
                  }
                }
                .layoutWeight(1)
                .height(60)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Stat type
              Row() {
                Text(getAppString('dlg_stat_type'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Row() {
                  Radio({ value: 'columns', group: 'statType' })
                    .checked(this.statTypeIdx === 0)
                    .onChange((isChecked: boolean) => {
                      if (isChecked) { this.statTypeIdx = 0; this.hasResults = false; }
                    })
                  Text(getAppString('table_stats_columns'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .margin({ left: 4, right: 12 })
                  Radio({ value: 'rows', group: 'statType' })
                    .checked(this.statTypeIdx === 1)
                    .onChange((isChecked: boolean) => {
                      if (isChecked) { this.statTypeIdx = 1; this.hasResults = false; }
                    })
                  Text(getAppString('table_stats_rows'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Column selection
              if (this.colNames.length > 0) {
                Text(getAppString('dlg_columns_to_analyze'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                Scroll() {
                  Row() {
                    ForEach(this.colNames, (name: string, idx: number) => {
                      Row() {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.selected[idx] })
                          .width(20).height(20)
                          .onChange((val: boolean) => {
                            const next: boolean[] = this.selected.slice();
                            next[idx] = val;
                            this.selected = next;
                          })
                        Text(name)
                          .fontSize(12)
                          .fontColor('#555555')
                          .margin({ left: 4 })
                      }
                      .margin({ right: 8 })
                    }, (name: string, idx: number) => idx + ':' + name)
                  }
                }
                .width('100%')
                .scrollable(ScrollDirection.Horizontal)
                .margin({ bottom: 8 })
              }

              // Calculate button
              Button(getAppString('dlg_calculate'))
                .fontSize(14).height(32)
                .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
                .alignSelf(ItemAlign.Center)
                .onClick(() => { this.onCalculate(); })

              // Results table
              if (this.hasResults) {
                Column() {
                  Text(getAppString('dlg_results'))
                    .fontSize(14)
                    .fontColor('#333333')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 6, top: 12 })

                  if (this.statTypeIdx === 0 && this.colResults.length > 0) {
                    // Column statistics
                    Scroll() {
                      Column() {
                        // Header
                        Row() {
                          ForEach(COL_STAT_HEADERS, (h: string, idx: number) => {
                            Text(h)
                              .fontSize(11)
                              .fontColor('#555555')
                              .fontWeight(FontWeight.Bold)
                              .padding(4)
                              .border({ width: 1, color: '#D0D0D0' })
                              .backgroundColor('#F0F0F0')
                          }, (h: string, idx: number) => h + ':' + idx)
                        }
                        // Data rows
                        ForEach(this.colResults, (col: StatColumn, rIdx: number) => {
                          Row() {
                            Text(col.name).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.rows).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.mean).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.standardDev).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.variance).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.sum).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.iMax).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.max).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.iMin).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.min).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(col.n).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                          }
                        }, (col: StatColumn, rIdx: number) => col.name + ':' + rIdx)
                      }
                    }
                    .scrollable(ScrollDirection.Horizontal)
                    .width('100%')
                  }

                  if (this.statTypeIdx === 1 && this.rowResults.length > 0) {
                    // Row statistics
                    Scroll() {
                      Column() {
                        Row() {
                          ForEach(ROW_STAT_HEADERS, (h: string, idx: number) => {
                            Text(h)
                              .fontSize(11)
                              .fontColor('#555555')
                              .fontWeight(FontWeight.Bold)
                              .padding(4)
                              .border({ width: 1, color: '#D0D0D0' })
                              .backgroundColor('#F0F0F0')
                          }, (h: string, idx: number) => h + ':' + idx)
                        }
                        ForEach(this.rowResults, (row: StatRow, rIdx: number) => {
                          Row() {
                            Text(row.row).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.cols).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.mean).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.standardDev).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.variance).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.sum).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.max).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.min).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                            Text(row.n).fontSize(11).fontColor('#333333')
                              .padding(4).border({ width: 1, color: '#E0E0E0' })
                          }
                        }, (row: StatRow, rIdx: number) => row.row + ':' + rIdx)
                      }
                    }
                    .scrollable(ScrollDirection.Horizontal)
                    .width('100%')
                  }
                }
                .width('100%')
                .margin({ top: 4 })
              }

              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(11)
                  .fontColor('#CC3333')
                  .margin({ top: 8 })
              }
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          Row() {
            Button(getAppString('common_close'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(500)
        .constraintSize({ maxHeight: '90%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
