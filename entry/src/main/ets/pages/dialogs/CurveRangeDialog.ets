// CurveRangeDialog — "Plot range" dialog.
// Mirrors Qt CurveRangeDialog: QGroupBox with curve name label,
// From/To SpinBoxes for row range. On OK dispatches setCurveRange
// backend command (mirrors CurveRangeDialog::accept which calls
// d_curve->setRowRange + d_graph->updatePlot).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'CurveRangeDialog';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface SetCurveRangeArgs {
  curveIdx: number;
  startRow: number;
  endRow: number;
}

interface CurveInfoData {
  curveIdx: number;
  curveName: string;
  startRow: number;
  endRow: number;
  maxRows: number;
}

interface CurveInfoResponse {
  success: boolean;
  data?: CurveInfoData;
  error?: string;
}

@Component
export struct CurveRangeDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop curveIdx: number = -1;
  @State curveName: string = '';
  @State fromRow: number = 1;
  @State toRow: number = 1;
  @State maxRows: number = 1;
  @State statusMsg: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  private loadData(): void {
    this.statusMsg = '';
    const idx: number = AppStorage.get<number>('curveRangeIdx') ?? this.curveIdx;
    if (idx < 0) {
      this.curveName = '';
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getCurveInfo',
        JSON.stringify({ curveIdx: idx }));
      const parsed = JSON.parse(result) as CurveInfoResponse;
      if (parsed.success && parsed.data) {
        this.curveName = parsed.data.curveName;
        // Qt uses 0-based internally, display 1-based
        this.fromRow = parsed.data.startRow + 1;
        this.toRow = parsed.data.endRow + 1;
        this.maxRows = parsed.data.maxRows;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getCurveInfo failed: %{public}s', (e as Error).message);
    }
  }

  onOk(): void {
    const idx: number = AppStorage.get<number>('curveRangeIdx') ?? this.curveIdx;
    if (idx < 0) {
      this.statusMsg = getAppString('dlg_curve_range_no_curve');
      return;
    }
    // Convert back to 0-based
    const startVal: number = this.fromRow - 1;
    const endVal: number = this.toRow - 1;
    const safeStart: number = Math.min(startVal, endVal);
    const safeEnd: number = Math.max(startVal, endVal);
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('setCurveRange',
        JSON.stringify({
          curveIdx: idx,
          startRow: safeStart,
          endRow: safeEnd,
        } as SetCurveRangeArgs));
      hilog.info(DOMAIN, TAG, 'setCurveRange(%{public}d, %{public}d..%{public}d): %{public}s',
        idx, safeStart, safeEnd, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setCurveRange failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
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
          Text(getAppString('dlg_curve_range_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Column({ space: 10 }) {
            // Data set name
            Row() {
              Text(getAppString('dlg_curve_range_dataset'))
                .fontSize(13).fontColor('#555555').width(100)
              Text(this.curveName)
                .fontSize(13).fontColor('#333333').fontWeight(FontWeight.Medium)
            }.width('100%')

            // From row
            Row() {
              Text(getAppString('dlg_curve_range_from'))
                .fontSize(13).fontColor('#555555').width(100)
              TextInput({ text: this.fromRow.toString() })
                .layoutWeight(1).fontSize(13).type(InputType.Number)
                .onChange((v: string) => {
                  const n: number = parseInt(v, 10);
                  if (!isNaN(n)) {
                    this.fromRow = Math.max(1, Math.min(n, this.maxRows));
                  }
                })
            }.width('100%')

            // To row
            Row() {
              Text(getAppString('dlg_curve_range_to'))
                .fontSize(13).fontColor('#555555').width(100)
              TextInput({ text: this.toRow.toString() })
                .layoutWeight(1).fontSize(13).type(InputType.Number)
                .onChange((v: string) => {
                  const n: number = parseInt(v, 10);
                  if (!isNaN(n)) {
                    this.toRow = Math.max(1, Math.min(n, this.maxRows));
                  }
                })
            }.width('100%')

            // Range slider
            Row() {
              Text('1')
                .fontSize(11).fontColor('#999999')
              Slider({
                value: this.fromRow,
                min: 1,
                max: this.maxRows,
                step: 1,
              })
                .layoutWeight(1)
                .onChange((v: number) => { this.fromRow = v; })
              Slider({
                value: this.toRow,
                min: 1,
                max: this.maxRows,
                step: 1,
              })
                .layoutWeight(1)
                .onChange((v: number) => { this.toRow = v; })
              Text(this.maxRows.toString())
                .fontSize(11).fontColor('#999999')
            }
            .width('100%')

            if (this.statusMsg) {
              Text(this.statusMsg)
                .fontSize(11).fontColor('#CC3333')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // Bottom buttons: OK / Close
          Row() {
            Button(getAppString('common_close'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onOk(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: 12 })
          .justifyContent(FlexAlign.End)
        }
        .width(360)
        .constraintSize({ maxHeight: '60%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
