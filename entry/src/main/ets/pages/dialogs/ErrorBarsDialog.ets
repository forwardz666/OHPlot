// ErrorBarsDialog — "Graph > Add Error Bars..." dialog (Phase 3b).
// Picks a curve of the active graph plus an error mode (computed percent /
// stddev, or an existing table column) and a direction, then queues the
// add_error_bars backend command
// (schema: { curveName, mode: "compute"|"column", type?, percent?,
//           errTableId?, errColumnName?, direction? }).
// Result toast arrives via the event channel (QtEventHost).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface GraphCurvesResponse {
  success: boolean;
  curves?: string[];
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
  description: string;
  formula: string;
  plotDesignation: string;
}

interface ColumnInfoResponse {
  success: boolean;
  data?: ColumnInfo[];
  error?: string;
}

interface ErrorBarsArgs {
  curveName: string;
  mode: string;
  type?: number;
  percent?: number;
  errTableId?: string;
  errColumnName?: string;
  direction?: string;
}

@Component
export struct ErrorBarsDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State curves: string[] = [];
  @State curveIdx: number = -1;
  // 0 = compute (percent/stddev), 1 = column (existing column values).
  @State modeIdx: number = 0;
  // 0 = percent, 1 = standard deviation.
  @State typeIdx: number = 0;
  @State percentText: string = '5';
  @State errTables: TableInfo[] = [];
  @State errTableIdx: number = -1;
  @State errColNames: string[] = [];
  @State errColIdx: number = -1;
  // 0 = X, 1 = Y (backend default is 'y').
  @State directionIdx: number = 1;
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
    this.curves = this.fetchCurves();
    this.curveIdx = this.curves.length > 0 ? 0 : -1;
    this.modeIdx = 0;
    this.typeIdx = 0;
    this.percentText = '5';
    this.directionIdx = 1;
    this.statusMsg = '';
    this.errTables = this.fetchTables();
    this.errTableIdx = this.errTables.length > 0 ? 0 : -1;
    this.errColIdx = -1;
    this.loadErrColumns();
  }

  private fetchCurves(): string[] {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getGraphCurves', '{}');
      const parsed = JSON.parse(result) as GraphCurvesResponse;
      if (parsed.success && parsed.curves) {
        return parsed.curves;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ErrorBarsDialog getGraphCurves failed: %{public}s',
        (e as Error).message);
    }
    return [];
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
      hilog.error(DOMAIN, TAG, 'ErrorBarsDialog getTableList failed: %{public}s',
        (e as Error).message);
    }
    return [];
  }

  private currentErrTable(): TableInfo | undefined {
    if (this.errTableIdx < 0 || this.errTableIdx >= this.errTables.length) {
      return undefined;
    }
    return this.errTables[this.errTableIdx];
  }

  private loadErrColumns(): void {
    const t = this.currentErrTable();
    this.errColNames = [];
    this.errColIdx = -1;
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
        for (let i = 0; i < parsed.data.length; i++) {
          names.push(parsed.data[i].name);
        }
        this.errColNames = names;
        this.errColIdx = names.length > 0 ? 0 : -1;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ErrorBarsDialog getColumnInfo failed: %{public}s',
        (e as Error).message);
    }
  }

  onErrTablePick(idx: number): void {
    this.errTableIdx = idx;
    this.loadErrColumns();
  }

  onAdd(): void {
    if (this.curveIdx < 0 || this.curveIdx >= this.curves.length) {
      this.statusMsg = getAppString('msg_select_column');
      return;
    }
    const mode: string = this.modeIdx === 1 ? 'column' : 'compute';
    const direction: string = this.directionIdx === 0 ? 'x' : 'y';
    if (mode === 'column') {
      if (this.errColIdx < 0 || this.errColIdx >= this.errColNames.length) {
        this.statusMsg = getAppString('msg_select_column');
        return;
      }
      const t = this.currentErrTable();
      if (!t) {
        this.statusMsg = getAppString('msg_select_column');
        return;
      }
      try {
        const injector = qohos as QohosInjector;
        const result: string = injector.callQtCommand('add_error_bars',
          JSON.stringify({
            curveName: this.curves[this.curveIdx],
            mode: mode,
            errTableId: t.name,
            errColumnName: this.errColNames[this.errColIdx],
            direction: direction
          } as ErrorBarsArgs));
        hilog.info(DOMAIN, TAG, 'add_error_bars(%{public}s, column) queued: %{public}s',
          this.curves[this.curveIdx], result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'add_error_bars failed: %{public}s', (e as Error).message);
      }
    } else {
      // compute mode: type 0 = percent (with percent value), 1 = stddev.
      const type: number = this.typeIdx === 1 ? 1 : 0;
      const args: ErrorBarsArgs = {
        curveName: this.curves[this.curveIdx],
        mode: mode,
        direction: direction
      };
      if (type === 0) {
        let percent: number = Number(this.percentText);
        if (!Number.isFinite(percent) || percent <= 0) {
          percent = 5.0;
        }
        args.type = 0;
        args.percent = percent;
      } else {
        args.type = 1;
      }
      try {
        const injector = qohos as QohosInjector;
        const result: string = injector.callQtCommand('add_error_bars', JSON.stringify(args));
        hilog.info(DOMAIN, TAG, 'add_error_bars(%{public}s, compute) queued: %{public}s',
          this.curves[this.curveIdx], result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'add_error_bars failed: %{public}s', (e as Error).message);
      }
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
          Text(getAppString('graph_add_error_bars'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text(getAppString('dlg_curve'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Scroll() {
                  Column() {
                    ForEach(this.curves, (name: string, idx: number) => {
                      Text(name)
                        .fontSize(12)
                        .fontColor(idx === this.curveIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.curveIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.curveIdx = idx; })
                    }, (name: string, idx: number) => idx + ':' + name)
                  }
                }
                .layoutWeight(1)
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('Mode:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Row() {
                  Text('Compute')
                    .fontSize(12)
                    .fontColor(this.modeIdx === 0 ? '#0078D7' : '#666666')
                    .fontWeight(this.modeIdx === 0 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.modeIdx = 0; })
                  Text('From column')
                    .fontSize(12)
                    .fontColor(this.modeIdx === 1 ? '#0078D7' : '#666666')
                    .fontWeight(this.modeIdx === 1 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.modeIdx = 1; })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .margin({ bottom: 12 })

              if (this.modeIdx === 0) {
                Row() {
                  Text('Type:')
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Row() {
                    Text('Percent')
                      .fontSize(12)
                      .fontColor(this.typeIdx === 0 ? '#0078D7' : '#666666')
                      .fontWeight(this.typeIdx === 0 ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                      .onClick(() => { this.typeIdx = 0; })
                    Text('StdDev')
                      .fontSize(12)
                      .fontColor(this.typeIdx === 1 ? '#0078D7' : '#666666')
                      .fontWeight(this.typeIdx === 1 ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                      .onClick(() => { this.typeIdx = 1; })
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 8 })

                if (this.typeIdx === 0) {
                  Row() {
                    Text('Percent:')
                      .fontSize(13)
                      .fontColor('#555555')
                      .width(80)
                    TextInput({ text: this.percentText })
                      .fontSize(13)
                      .layoutWeight(1)
                      .height(30)
                      .onChange((v: string) => { this.percentText = v; })
                  }
                  .width('100%')
                  .margin({ bottom: 12 })
                }
              } else {
                Row() {
                  Text(getAppString('dlg_export_table'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Scroll() {
                    Column() {
                      ForEach(this.errTables, (t: TableInfo, idx: number) => {
                        Text(t.label.length > 0 ? t.label : t.name)
                          .fontSize(12)
                          .fontColor(idx === this.errTableIdx ? '#0078D7' : '#666666')
                          .fontWeight(idx === this.errTableIdx ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 3, bottom: 3, left: 6 })
                          .width('100%')
                          .onClick(() => { this.onErrTablePick(idx); })
                      }, (t: TableInfo, idx: number) => t.name + ':' + idx)
                    }
                  }
                  .layoutWeight(1)
                  .height(80)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .margin({ bottom: 8 })

                Row() {
                  Text('Err. column:')
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Scroll() {
                    Column() {
                      ForEach(this.errColNames, (name: string, idx: number) => {
                        Text(name)
                          .fontSize(12)
                          .fontColor(idx === this.errColIdx ? '#0078D7' : '#666666')
                          .fontWeight(idx === this.errColIdx ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 3, bottom: 3, left: 6 })
                          .width('100%')
                          .onClick(() => { this.errColIdx = idx; })
                      }, (name: string, idx: number) => idx + ':' + name)
                    }
                  }
                  .layoutWeight(1)
                  .height(80)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .margin({ bottom: 12 })
              }

              Row() {
                Text('Direction:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Row() {
                  Text('X')
                    .fontSize(12)
                    .fontColor(this.directionIdx === 0 ? '#0078D7' : '#666666')
                    .fontWeight(this.directionIdx === 0 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.directionIdx = 0; })
                  Text('Y')
                    .fontSize(12)
                    .fontColor(this.directionIdx === 1 ? '#0078D7' : '#666666')
                    .fontWeight(this.directionIdx === 1 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.directionIdx = 1; })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .margin({ bottom: 8 })

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
            Button(getAppString('graph_add_error_bars'))
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
