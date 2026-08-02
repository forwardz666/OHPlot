// AddCurveDialog — "Graph > Add/Remove Curve..." dialog (Phase 3b).
// Picks a table, one or more columns and a 2D plot style, then queues the
// add_curve backend command (schema: { tableId, cols: number[], style? }).
// Result toast arrives via the event channel (QtEventHost).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
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
  description: string;
  formula: string;
  plotDesignation: string;
}

interface ColumnInfoResponse {
  success: boolean;
  data?: ColumnInfo[];
  error?: string;
}

interface AddCurveArgs {
  tableId: string;
  cols: number[];
  style?: string;
}

interface CurveStyleDef {
  id: string;
  key: string;
}

// Plot style id -> resource key of its label (mirrors the graph curve
// style map used by the Plot menu / plot2D dialog).
const CURVE_STYLE_KEYS: CurveStyleDef[] = [
  { id: 'line', key: 'plot_line' },
  { id: 'scatter', key: 'plot_scatter' },
  { id: 'line_symbol', key: 'plot_line_symbol' },
  { id: 'vertical_bars', key: 'plot_vertical_bars' },
  { id: 'horizontal_bars', key: 'plot_horizontal_bars' },
  { id: 'area', key: 'plot_area' },
  { id: 'drop_lines', key: 'plot_vertical_drop_lines' },
  { id: 'spline', key: 'plot_spline' },
  { id: 'vertical_steps', key: 'plot_vertical_steps' },
  { id: 'horizontal_steps', key: 'plot_horizontal_steps' },
];

@Component
export struct AddCurveDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State tables: TableInfo[] = [];
  @State selTableIdx: number = -1;
  @State colNames: string[] = [];
  @State colIds: number[] = [];
  @State selected: boolean[] = [];
  @State styleIdx: number = 0;
  @State statusMsg: string = '';

  aboutToAppear(): void {
    // MainLayout mounts this dialog conditionally, so the component is
    // created with isVisible already true and @Watch never fires — load
    // the data here instead.
    if (this.isVisible) {
      this.reload();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.reload();
    }
  }

  private reload(): void {
    this.tables = this.fetchTables();
    this.selTableIdx = this.tables.length > 0 ? 0 : -1;
    this.styleIdx = 0;
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
      hilog.error(DOMAIN, TAG, 'AddCurveDialog getTableList failed: %{public}s',
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
        // Default: everything except the first column (the usual X column).
        this.selected = names.map((_n: string, idx: number) => idx > 0);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'AddCurveDialog getColumnInfo failed: %{public}s',
        (e as Error).message);
    }
  }

  onTablePick(idx: number): void {
    this.selTableIdx = idx;
    this.loadColumns();
  }

  onStylePick(idx: number): void {
    this.styleIdx = idx;
  }

  onAdd(): void {
    const t = this.currentTable();
    if (!t) {
      this.statusMsg = getAppString('msg_select_column');
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
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('add_curve',
        JSON.stringify({ tableId: t.name, cols: cols, style: CURVE_STYLE_KEYS[this.styleIdx].id } as AddCurveArgs));
      hilog.info(DOMAIN, TAG, 'add_curve(%{public}s, cols=%{public}s) queued: %{public}s',
        t.name, JSON.stringify(cols), result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'add_curve failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false; // result toast arrives via the event channel
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
          Text(getAppString('graph_add_remove_curve'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
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
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Text(getAppString('dlg_columns_to_plot'))
                .fontSize(13)
                .fontColor('#555555')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 4 })
              if (this.colNames.length > 0) {
                Scroll() {
                  Column() {
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
                          .margin({ left: 8 })
                      }
                      .width('100%')
                      .padding({ top: 3, bottom: 3, left: 6 })
                      .onClick(() => {
                        const next: boolean[] = this.selected.slice();
                        next[idx] = !next[idx];
                        this.selected = next;
                      })
                    }, (name: string, idx: number) => idx + ':' + name)
                  }
                }
                .width('100%')
                .height(120)
                .border({ width: 1, color: '#D0D0D0' })
              } else {
                Text(getAppString('common_no_columns'))
                  .fontSize(12)
                  .fontColor('#999999')
              }

              Row() {
                Text('Style:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Scroll() {
                  Column() {
                    ForEach(CURVE_STYLE_KEYS, (s: CurveStyleDef, idx: number) => {
                      Text(getAppString(s.key))
                        .fontSize(12)
                        .fontColor(idx === this.styleIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.styleIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.onStylePick(idx); })
                    }, (s: CurveStyleDef, idx: number) => s.id + ':' + idx)
                  }
                }
                .layoutWeight(1)
                .height(120)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ top: 12 })

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
            Button(getAppString('common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('graph_add_remove_curve'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onAdd(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(400)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
