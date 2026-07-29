// OHPlot 2D plot dialog (Phase 2).
// The desktop Plot menu acts on the current column selection; touch users
// cannot reliably select columns in the Qt view, so this dialog collects
// the Y columns and dispatches the queued plot2D backend command
// (ApplicationWindow::multilayerPlot — never pops a dialog).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface TableDataPayload {
  name: string;
  rows: number;
  cols: number;
  colNames: string[];
}

interface TableDataResponse {
  success: boolean;
  data?: TableDataPayload;
  error?: string;
}

interface GetTableDataArgs {
  tableId: string;
}

interface Plot2DArgs {
  tableId: string;
  type: string;
  cols: number[];
}

// plot type id → title resource name (mirrors the plot2D style map in main.cpp)
const PLOT_TITLE_KEYS: Map<string, string> = new Map<string, string>([
  ['line', 'plot_line'],
  ['scatter', 'plot_scatter'],
  ['line_symbol', 'plot_line_symbol'],
  ['vertical_bars', 'plot_vertical_bars'],
  ['horizontal_bars', 'plot_horizontal_bars'],
  ['area', 'plot_area'],
  ['pie', 'plot_pie'],
  ['drop_lines', 'plot_vertical_drop_lines'],
  ['spline', 'plot_spline'],
  ['vertical_steps', 'plot_vertical_steps'],
  ['horizontal_steps', 'plot_horizontal_steps'],
  ['histogram', 'plot_histogram'],
  ['box', 'plot_box'],
]);

@Component
export struct Plot2DDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop tableId: string = '';
  @Prop plotType: string = 'line';
  @State colNames: string[] = [];
  @State selected: boolean[] = [];
  @State statusMsg: string = '';

  onVisibleChanged(): void {
    if (this.isVisible) {
      // @Prop may not have propagated in this frame; the dispatcher stores
      // the target/type in AppStorage synchronously (same pattern as
      // TableOpsDialog).
      const target: string = AppStorage.get<string>('tableOpsTarget') ?? this.tableId;
      this.colNames = this.fetchColNames(target);
      // Default: everything except the first column (the usual X column).
      this.selected = this.colNames.map((_name: string, idx: number) => idx > 0);
      this.statusMsg = '';
    }
  }

  private fetchColNames(tableId: string): string[] {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getTableData',
        JSON.stringify({ tableId: tableId } as GetTableDataArgs));
      const parsed = JSON.parse(result) as TableDataResponse;
      if (parsed.success && parsed.data && parsed.data.colNames) {
        return parsed.data.colNames;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Plot2DDialog fetchColNames failed: %{public}s',
        (e as Error).message);
    }
    return [];
  }

  private currentType(): string {
    return AppStorage.get<string>('plotType') ?? this.plotType;
  }

  private title(): string {
    const t: string = this.currentType();
    const key: string | undefined = PLOT_TITLE_KEYS.get(t);
    return (key !== undefined ? getAppString(key) : t) + ' — ' + this.tableId;
  }

  onPlot(): void {
    const cols: number[] = [];
    for (let i = 0; i < this.selected.length; i++) {
      if (this.selected[i]) { cols.push(i); }
    }
    const type: string = this.currentType();
    if (type === 'pie' && cols.length !== 1) {
      this.statusMsg = getAppString('msg_pie_one_column');
      return;
    }
    if (cols.length === 0) {
      this.statusMsg = getAppString('msg_select_column');
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const target: string = AppStorage.get<string>('tableOpsTarget') ?? this.tableId;
      const result: string = injector.callQtCommand('plot2D',
        JSON.stringify({ tableId: target, type: type, cols: cols } as Plot2DArgs));
      hilog.info(DOMAIN, TAG, 'plot2D(%{public}s, cols=%{public}s) queued: %{public}s',
        type, JSON.stringify(cols), result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'plot2D failed: %{public}s', (e as Error).message);
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
          Text(this.title())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Text($r('app.string.dlg_columns_to_plot'))
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
                .height(150)
                .border({ width: 1, color: '#D0D0D0' })
              } else {
                Text($r('app.string.common_no_columns'))
                  .fontSize(12)
                  .fontColor('#999999')
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
            Button($r('app.string.common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button($r('app.string.dlg_plot_action'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onPlot(); })
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
