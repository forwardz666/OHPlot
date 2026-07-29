// OHPlot analysis dialog (Phase 3).
// One dialog serves the whole desktop Analysis menu: it lists the active
// plot's analysable curves (getGraphCurves) and shows the parameter
// fields the selected operation needs, then dispatches the queued
// analyzeCurve backend command.  Results come back as message /
// resultsLog events toasted by QtEventHost.
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

// Maps each operation to the resource name of its dialog title.
const OP_TITLE_KEYS: Map<string, string> = new Map([
  ['fit_linear', 'analysis_fit_linear'],
  ['fit_poly', 'dlg_title_fit_poly'],
  ['fit_gauss', 'analysis_fit_gaussian'],
  ['fit_lorentz', 'analysis_fit_lorentzian'],
  ['fit_sigmoidal', 'analysis_fit_boltzmann'],
  ['fft', 'analysis_fft'],
  ['smooth', 'analysis_smooth'],
  ['interpolate', 'dlg_title_interpolate'],
  ['differentiate', 'analysis_differentiate'],
  ['integrate', 'analysis_integrate'],
  ['fft_filter', 'dlg_title_fft_filter'],
]);

function smoothMethodLabels(): string[] {
  return [getAppString('dlg_method_savgol'), getAppString('dlg_method_fft'),
    getAppString('dlg_method_moving_avg')];
}
function interpMethodLabels(): string[] {
  return [getAppString('dlg_method_linear'), getAppString('dlg_method_cubic'),
    getAppString('dlg_method_akima')];
}
function filterTypeLabels(): string[] {
  return [getAppString('dlg_filter_low_pass'), getAppString('dlg_filter_high_pass'),
    getAppString('dlg_filter_band_pass'), getAppString('dlg_filter_band_block')];
}

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
      this.statusMsg = this.curves.length === 0 ? getAppString('msg_no_curves') : '';
    }
  }

  onApply(): void {
    if (this.curves.length === 0) {
      this.statusMsg = getAppString('msg_no_curves');
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
        this.statusMsg = getAppString('msg_valid_freq');
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
          Text(getAppString(OP_TITLE_KEYS.get(this.currentOp()) ?? 'dlg_title_analysis'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text($r('app.string.dlg_curve'))
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
                  Text($r('app.string.common_no_curves'))
                    .fontSize(12)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .margin({ bottom: 12 })

              if (this.currentOp() === 'fit_poly') {
                this.NumberField(getAppString('dlg_poly_order_range'), this.orderText,
                  (val: string) => { this.orderText = val; })
              } else if (this.currentOp() === 'smooth') {
                Text($r('app.string.dlg_method'))
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(smoothMethodLabels(), this.smoothMethod,
                  (idx: number) => { this.smoothMethod = idx; })
                this.NumberField(getAppString('dlg_points'), this.pointsText,
                  (val: string) => { this.pointsText = val; })
                if (this.smoothMethod === 0) {
                  this.NumberField(getAppString('dlg_poly_order'), this.orderText,
                    (val: string) => { this.orderText = val; })
                }
              } else if (this.currentOp() === 'interpolate') {
                Text($r('app.string.dlg_method'))
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(interpMethodLabels(), this.interpMethod,
                  (idx: number) => { this.interpMethod = idx; })
                this.NumberField(getAppString('dlg_points'), this.interpPointsText,
                  (val: string) => { this.interpPointsText = val; })
              } else if (this.currentOp() === 'fft_filter') {
                Text($r('app.string.dlg_filter_type'))
                  .fontSize(13).fontColor('#555555')
                  .alignSelf(ItemAlign.Start).margin({ bottom: 4 })
                this.MethodPicker(filterTypeLabels(), this.filterType,
                  (idx: number) => { this.filterType = idx; })
                this.NumberField(this.filterType >= 2 ? getAppString('dlg_low_freq') : getAppString('dlg_cutoff_freq'),
                  this.freqText, (val: string) => { this.freqText = val; })
                if (this.filterType >= 2) {
                  this.NumberField(getAppString('dlg_high_freq'), this.freq2Text,
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
            Button($r('app.string.common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button($r('app.string.common_apply'))
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
      this.statusMsg = this.colNames.length < 2 ? getAppString('msg_two_columns') : '';
    }
  }

  onApply(): void {
    if (this.colNames.length < 2) {
      this.statusMsg = getAppString('msg_two_columns');
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
          Text(getAppString('dlg_correlate') + ' — ' + this.target())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              this.ColumnPicker(getAppString('dlg_column_1'), this.col1, (idx: number) => { this.col1 = idx; })
              this.ColumnPicker(getAppString('dlg_column_2'), this.col2, (idx: number) => { this.col2 = idx; })
              Text($r('app.string.dlg_autocorr_hint'))
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
            Button($r('app.string.common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button($r('app.string.dlg_correlate'))
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
