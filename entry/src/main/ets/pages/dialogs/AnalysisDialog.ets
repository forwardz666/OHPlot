// ArkSciDAVis analysis dialog (Phase 3).
// One dialog serves the whole desktop Analysis menu: it lists the active
// plot's analysable curves (getGraphCurves) and shows the parameter
// fields the selected operation needs, then dispatches the queued
// analyzeCurve backend command.  Results come back as message /
// resultsLog events toasted by QtEventHost.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface GraphCurvesResponse {
  success: boolean;
  curves?: string[];
  error?: string;
}

interface AnalyzeCurveArgs {
  op: string;
  curve: string;
  order?: number;
  method?: number;
  points?: number;
  filterType?: number;
  freq?: number;
  freq2?: number;
}

const OP_TITLES: Map<string, string> = new Map([
  ['fit_linear', 'Fit Linear'],
  ['fit_poly', 'Fit Polynomial'],
  ['fit_gauss', 'Fit Gaussian'],
  ['fit_lorentz', 'Fit Lorentzian'],
  ['fit_sigmoidal', 'Fit Boltzmann (Sigmoidal)'],
  ['fft', 'FFT'],
  ['smooth', 'Smooth'],
  ['interpolate', 'Interpolate'],
  ['differentiate', 'Differentiate'],
  ['integrate', 'Integrate'],
  ['fft_filter', 'FFT Filter'],
]);

const SMOOTH_METHODS: string[] = ['Savitzky-Golay', 'FFT', 'Moving Average'];
const INTERP_METHODS: string[] = ['Linear', 'Cubic', 'Akima'];
const FILTER_TYPES: string[] = ['Low Pass', 'High Pass', 'Band Pass', 'Band Block'];

function fetchCurves(): string[] {
  try {
    const injector = qohos as QohosInjector;
    const result: string = injector.callQtCommand('getGraphCurves', '{}');
    const parsed = JSON.parse(result) as GraphCurvesResponse;
    if (parsed.success && parsed.curves) {
      return parsed.curves;
    }
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'getGraphCurves failed: %{public}s', (e as Error).message);
  }
  return [];
}

@Component
export struct AnalysisDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop op: string = 'fit_linear';
  @State curves: string[] = [];
  @State selectedCurve: number = 0;
  @State statusMsg: string = '';
  // Operation parameters (kept as text; parsed on Apply)
  @State orderText: string = '2';
  @State pointsText: string = '5';
  @State interpPointsText: string = '1000';
  @State smoothMethod: number = 0;   // index into SMOOTH_METHODS (backend is 1-based)
  @State interpMethod: number = 0;   // index into INTERP_METHODS (backend 0-based)
  @State filterType: number = 0;     // index into FILTER_TYPES (backend is 1-based)
  @State freqText: string = '0.1';
  @State freq2Text: string = '0.2';

  currentOp(): string {
    // @Prop may lag one frame behind the dispatcher; it stores the op in
    // AppStorage synchronously (same workaround as tableOpsTarget).
    return AppStorage.get<string>('analysisOp') ?? this.op;
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.curves = fetchCurves();
      // Default to the most recently added curve, like the backend does.
      this.selectedCurve = this.curves.length > 0 ? this.curves.length - 1 : 0;
      this.statusMsg = this.curves.length === 0 ? 'The active plot has no analysable curves.' : '';
    }
  }

  onApply(): void {
    if (this.curves.length === 0) {
      this.statusMsg = 'The active plot has no analysable curves.';
      return;
    }
    const op: string = this.currentOp();
    const args: AnalyzeCurveArgs = { op: op, curve: this.curves[this.selectedCurve] };
    if (op === 'fit_poly') {
      const order: number = parseInt(this.orderText);
      args.order = isNaN(order) ? 2 : order;
    } else if (op === 'smooth') {
      args.method = this.smoothMethod + 1;
      const pts: number = parseInt(this.pointsText);
      args.points = isNaN(pts) ? 5 : pts;
      if (this.smoothMethod === 0) {
        const order: number = parseInt(this.orderText);
        args.order = isNaN(order) ? 2 : order;
      }
    } else if (op === 'interpolate') {
      args.method = this.interpMethod;
      const pts: number = parseInt(this.interpPointsText);
      args.points = isNaN(pts) ? 1000 : pts;
    } else if (op === 'fft_filter') {
      args.filterType = this.filterType + 1;
      const f1: number = parseFloat(this.freqText);
      const f2: number = parseFloat(this.freq2Text);
      if (isNaN(f1) || (this.filterType >= 2 && isNaN(f2))) {
        this.statusMsg = 'Please enter valid frequencies.';
        return;
      }
      args.freq = f1;
      if (this.filterType >= 2) { args.freq2 = f2; }
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('analyzeCurve', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'analyzeCurve(%{public}s) queued: %{public}s', op, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'analyzeCurve failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
  }

  @Builder
  MethodPicker(labels: string[], selected: number, onPick: (idx: number) => void) {
    Row() {
      ForEach(labels, (label: string, idx: number) => {
        Text(label)
          .fontSize(12)
          .fontColor(idx === selected ? '#0078D7' : '#666666')
          .fontWeight(idx === selected ? FontWeight.Bold : FontWeight.Normal)
          .padding({ top: 3, bottom: 3, left: 6, right: 10 })
          .onClick(() => { onPick(idx); })
      }, (label: string, idx: number) => idx + ':' + label)
    }
    .width('100%')
  }

  @Builder
  NumberField(label: string, value: string, onChange: (val: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#555555')
        .layoutWeight(1)
      TextInput({ text: value })
        .fontSize(13)
        .width(100)
        .height(34)
        .onChange((val: string) => { onChange(val); })
    }
    .width('100%')
    .margin({ bottom: 8 })
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
          Text(OP_TITLES.get(this.currentOp()) ?? 'Analysis')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text('Curve:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                if (this.curves.length > 0) {
                  Scroll() {
                    Column() {
                      ForEach(this.curves, (name: string, idx: number) => {
                        Text(name)
                          .fontSize(12)
                          .fontColor(idx === this.selectedCurve ? '#0078D7' : '#666666')
                          .fontWeight(idx === this.selectedCurve ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 3, bottom: 3, left: 6 })
                          .width('100%')
                          .onClick(() => { this.selectedCurve = idx; })
                      }, (name: string, idx: number) => idx + ':' + name)
                    }
                  }
                  .layoutWeight(1)
                  .height(90)
                  .border({ width: 1, color: '#D0D0D0' })
                } else {
                  Text('No curves')
                    .fontSize(12)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .margin({ bottom: 12 })

              if (this.currentOp() === 'fit_poly') {
                this.NumberField('Polynomial order (2-9):', this.orderText,
                  (val: string) => { this.orderText = val; })
              } else if (this.currentOp() === 'smooth') {
                Text('Method:')
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(SMOOTH_METHODS, this.smoothMethod,
                  (idx: number) => { this.smoothMethod = idx; })
                this.NumberField('Points:', this.pointsText,
                  (val: string) => { this.pointsText = val; })
                if (this.smoothMethod === 0) {
                  this.NumberField('Polynomial order:', this.orderText,
                    (val: string) => { this.orderText = val; })
                }
              } else if (this.currentOp() === 'interpolate') {
                Text('Method:')
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(INTERP_METHODS, this.interpMethod,
                  (idx: number) => { this.interpMethod = idx; })
                this.NumberField('Points:', this.interpPointsText,
                  (val: string) => { this.interpPointsText = val; })
              } else if (this.currentOp() === 'fft_filter') {
                Text('Filter type:')
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(FILTER_TYPES, this.filterType,
                  (idx: number) => { this.filterType = idx; })
                this.NumberField(this.filterType >= 2 ? 'Low frequency:' : 'Cutoff frequency:',
                  this.freqText, (val: string) => { this.freqText = val; })
                if (this.filterType >= 2) {
                  this.NumberField('High frequency:', this.freq2Text,
                    (val: string) => { this.freq2Text = val; })
                }
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
            Button('Cancel')
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button('Apply')
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onApply(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(420)
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

// ── Correlate (two table columns) ───────────────────────────────────────
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

interface CorrelateArgs {
  tableId: string;
  col1: number;
  col2: number;
}

function fetchTableCols(tableId: string): string[] {
  try {
    const injector = qohos as QohosInjector;
    const result: string = injector.callQtCommand('getTableData',
      JSON.stringify({ tableId: tableId } as GetTableDataArgs));
    const parsed = JSON.parse(result) as TableDataResponse;
    if (parsed.success && parsed.data && parsed.data.colNames) {
      return parsed.data.colNames;
    }
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'fetchTableCols failed: %{public}s', (e as Error).message);
  }
  return [];
}

@Component
export struct CorrelateDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop tableId: string = '';
  @State colNames: string[] = [];
  @State col1: number = 0;
  @State col2: number = 1;
  @State statusMsg: string = '';

  target(): string {
    return AppStorage.get<string>('tableOpsTarget') ?? this.tableId;
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.colNames = fetchTableCols(this.target());
      this.col1 = 0;
      this.col2 = this.colNames.length > 1 ? 1 : 0;
      this.statusMsg = this.colNames.length < 2 ? 'The table needs at least two columns.' : '';
    }
  }

  onApply(): void {
    if (this.colNames.length < 2) {
      this.statusMsg = 'The table needs at least two columns.';
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('correlate',
        JSON.stringify({ tableId: this.target(), col1: this.col1, col2: this.col2 } as CorrelateArgs));
      hilog.info(DOMAIN, TAG, 'correlate(%{public}d,%{public}d) queued: %{public}s',
        this.col1, this.col2, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'correlate failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
  }

  @Builder
  ColumnPicker(label: string, selected: number, onPick: (idx: number) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#555555')
        .width(80)
      Scroll() {
        Column() {
          ForEach(this.colNames, (name: string, idx: number) => {
            Text(name)
              .fontSize(12)
              .fontColor(idx === selected ? '#0078D7' : '#666666')
              .fontWeight(idx === selected ? FontWeight.Bold : FontWeight.Normal)
              .padding({ top: 3, bottom: 3, left: 6 })
              .width('100%')
              .onClick(() => { onPick(idx); })
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

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text('Correlate — ' + this.target())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              this.ColumnPicker('Column 1:', this.col1, (idx: number) => { this.col1 = idx; })
              this.ColumnPicker('Column 2:', this.col2, (idx: number) => { this.col2 = idx; })
              Text('Pick the same column twice for an autocorrelation.')
                .fontSize(10)
                .fontColor('#999999')
                .alignSelf(ItemAlign.Start)

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
            Button('Cancel')
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button('Correlate')
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onApply(); })
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
