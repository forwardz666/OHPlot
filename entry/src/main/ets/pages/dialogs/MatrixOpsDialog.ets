// OHPlot matrix-operation dialogs (Phase 3).
// The desktop MatrixDialog / MatrixValuesDialog cannot be shown on the
// single-window QPA; these ArkTS dialogs collect the parameters and
// dispatch the queued backend commands (matrixSetDimensions /
// matrixSetFormula); results arrive as message events toasted by
// QtEventHost.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface SetDimensionsArgs {
  matrixId: string;
  rows: number;
  cols: number;
}

interface MatrixFormulaArgs {
  matrixId: string;
  formula: string;
}

function opsTarget(fallback: string): string {
  return AppStorage.get<string>('tableOpsTarget') ?? fallback;
}

// ── Set Dimensions ──────────────────────────────────────────────────────
@Component
export struct MatrixDimensionsDialog {
  @Link isVisible: boolean;
  @Prop matrixId: string = '';
  @State rowsText: string = '32';
  @State colsText: string = '32';

  onApply(): void {
    let rows: number = parseInt(this.rowsText);
    let cols: number = parseInt(this.colsText);
    if (isNaN(rows) || rows < 1) { rows = 1; }
    if (isNaN(cols) || cols < 1) { cols = 1; }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('matrixSetDimensions',
        JSON.stringify({
          matrixId: opsTarget(this.matrixId), rows: rows, cols: cols
        } as SetDimensionsArgs));
      hilog.info(DOMAIN, TAG, 'matrixSetDimensions(%{public}dx%{public}d) queued: %{public}s',
        rows, cols, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'matrixSetDimensions failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_matrix_dims') + ' — ' + this.matrixId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Row() {
            Text($r('app.string.dlg_rows'))
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            TextInput({ text: this.rowsText })
              .type(InputType.Number)
              .fontSize(13)
              .width(90)
              .height(34)
              .onChange((val: string) => { this.rowsText = val; })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

          Row() {
            Text($r('app.string.dlg_cols'))
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            TextInput({ text: this.colsText })
              .type(InputType.Number)
              .fontSize(13)
              .width(90)
              .height(34)
              .onChange((val: string) => { this.colsText = val; })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 12 })

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
        .width(340)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}

// ── Set Values (muParser formula over all cells) ────────────────────────
@Component
export struct MatrixValuesDialog {
  @Link isVisible: boolean;
  @Prop matrixId: string = '';
  @State formula: string = '';
  @State statusMsg: string = '';

  onApply(): void {
    if (this.formula.trim() === '') {
      this.statusMsg = getAppString('msg_enter_formula');
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('matrixSetFormula',
        JSON.stringify({
          matrixId: opsTarget(this.matrixId), formula: this.formula
        } as MatrixFormulaArgs));
      hilog.info(DOMAIN, TAG, 'matrixSetFormula(%{public}s) queued: %{public}s',
        this.formula, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'matrixSetFormula failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_set_matrix_values') + ' — ' + this.matrixId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Column() {
            // Matrix muParser variables: i/row (1-based row), j/col
            // (1-based column), x/y (coordinate system values).
            Text($r('app.string.dlg_formula_muparser'))
              .fontSize(13)
              .fontColor('#555555')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 4 })
            TextInput({ text: this.formula, placeholder: $r('app.string.dlg_example_matrix') })
              .fontSize(13)
              .height(36)
              .width('100%')
              .onChange((val: string) => { this.formula = val; })
            Text($r('app.string.dlg_matrix_vars_hint'))
              .fontSize(10)
              .fontColor('#999999')
              .alignSelf(ItemAlign.Start)
              .margin({ top: 4 })

            if (this.statusMsg) {
              Text(this.statusMsg)
                .fontSize(11)
                .fontColor('#CC3333')
                .margin({ top: 8 })
            }
          }
          .padding({ left: 16, right: 16 })
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
          .padding({ left: 16, right: 16, bottom: 16, top: 12 })
          .justifyContent(FlexAlign.End)
        }
        .width(400)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
