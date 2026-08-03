// PlotWizardDialog — "Select Columns to Plot" dialog.
// Mirrors the Qt PlotWizard: worksheet selector, column-to-axis assignment
// (X/Y/Z/xErr/yErr), curve management, curve list, Plot/Close buttons.
// On confirm, dispatches the plotWizard backend command which emits the
// plot() signal on the Qt side (same as PlotWizard::accept).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'PlotWizardDialog';

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

interface CurveEntry {
  tableId: string;
  xCol: string;
  yCol: string;
  zCol: string;
  xErrCol: string;
  yErrCol: string;
}

interface PlotWizardArgs {
  curves: CurveEntry[];
}

// Axis assignment role identifiers
type AxisRole = 'X' | 'Y' | 'Z' | 'xErr' | 'yErr';

@Component
export struct PlotWizardDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State tables: TableInfo[] = [];
  @State selTableIdx: number = -1;
  @State colNames: string[] = [];
  @State selColIdx: number = -1;
  // Curve list — each entry stores assigned column names per role
  @State curves: CurveEntry[] = [];
  @State selCurveIdx: number = -1;
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

  private reload(): void {
    this.tables = this.fetchTables();
    this.selTableIdx = this.tables.length > 0 ? 0 : -1;
    this.curves = [];
    this.selCurveIdx = -1;
    this.selColIdx = -1;
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
      hilog.error(DOMAIN, TAG, 'fetchTables failed: %{public}s', (e as Error).message);
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
    this.selColIdx = -1;
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
        this.colNames = names;
        if (names.length > 0) {
          this.selColIdx = 0;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadColumns failed: %{public}s', (e as Error).message);
    }
  }

  private curveDisplayText(entry: CurveEntry): string {
    let text: string = entry.tableId + ': ';
    if (entry.xCol.length > 0) {
      text += entry.xCol + '(X)';
    }
    if (entry.yCol.length > 0) {
      text += ', ' + entry.yCol + '(Y)';
    }
    if (entry.zCol.length > 0) {
      text += ', ' + entry.zCol + '(Z)';
    }
    if (entry.xErrCol.length > 0) {
      text += ', ' + entry.xErrCol + '(xErr)';
    }
    if (entry.yErrCol.length > 0) {
      text += ', ' + entry.yErrCol + '(yErr)';
    }
    return text;
  }

  onTablePick(idx: number): void {
    this.selTableIdx = idx;
    this.loadColumns();
  }

  onColumnPick(idx: number): void {
    this.selColIdx = idx;
  }

  onCurvePick(idx: number): void {
    this.selCurveIdx = idx;
  }

  onNewCurve(): void {
    const t = this.currentTable();
    if (!t) {
      this.statusMsg = getAppString('msg_select_table');
      return;
    }
    const entry: CurveEntry = {
      tableId: t.name,
      xCol: '',
      yCol: '',
      zCol: '',
      xErrCol: '',
      yErrCol: '',
    };
    const next: CurveEntry[] = this.curves.slice();
    next.push(entry);
    this.curves = next;
    this.selCurveIdx = next.length - 1;
    this.statusMsg = '';
  }

  onDeleteCurve(): void {
    if (this.selCurveIdx < 0 || this.selCurveIdx >= this.curves.length) {
      return;
    }
    const next: CurveEntry[] = this.curves.slice();
    next.splice(this.selCurveIdx, 1);
    this.curves = next;
    if (next.length > 0) {
      this.selCurveIdx = Math.min(this.selCurveIdx, next.length - 1);
    } else {
      this.selCurveIdx = -1;
    }
  }

  onAssignAxis(role: AxisRole): void {
    if (this.selCurveIdx < 0 || this.selCurveIdx >= this.curves.length) {
      this.statusMsg = getAppString('dlg_pw_add_curve_first');
      return;
    }
    if (this.selColIdx < 0 || this.selColIdx >= this.colNames.length) {
      this.statusMsg = getAppString('msg_select_column');
      return;
    }
    const colName: string = this.colNames[this.selColIdx];
    const next: CurveEntry[] = this.curves.slice();
    const entry: CurveEntry = next[this.selCurveIdx];

    // Validate role assignment order
    if (role === 'Y' && entry.xCol.length === 0) {
      this.statusMsg = getAppString('dlg_pw_define_x_first');
      return;
    }
    if (role === 'Z') {
      if (entry.xCol.length === 0 || entry.yCol.length === 0) {
        this.statusMsg = getAppString('dlg_pw_define_xy_first');
        return;
      }
    }
    if (role === 'xErr' || role === 'yErr') {
      if (entry.xCol.length === 0 || entry.yCol.length === 0) {
        this.statusMsg = getAppString('dlg_pw_define_xy_first');
        return;
      }
      // Error bars not compatible with Z curves
      if (entry.zCol.length > 0) {
        this.statusMsg = getAppString('dlg_pw_err_no_z');
        return;
      }
    }
    // Check already assigned
    if (role === 'X' && entry.xCol.length > 0) {
      this.statusMsg = getAppString('dlg_pw_x_already');
      return;
    }
    if (role === 'Y' && entry.yCol.length > 0) {
      this.statusMsg = getAppString('dlg_pw_y_already');
      return;
    }
    if (role === 'Z' && entry.zCol.length > 0) {
      this.statusMsg = getAppString('dlg_pw_z_already');
      return;
    }
    if ((role === 'xErr' || role === 'yErr') &&
      (entry.xErrCol.length > 0 || entry.yErrCol.length > 0)) {
      this.statusMsg = getAppString('dlg_pw_err_already');
      return;
    }

    // Assign
    if (role === 'X') {
      entry.xCol = colName;
    } else if (role === 'Y') {
      entry.yCol = colName;
    } else if (role === 'Z') {
      entry.zCol = colName;
    } else if (role === 'xErr') {
      entry.xErrCol = colName;
    } else {
      entry.yErrCol = colName;
    }
    next[this.selCurveIdx] = entry;
    this.curves = next;
    this.statusMsg = '';
  }

  onPlot(): void {
    if (this.curves.length === 0) {
      this.statusMsg = getAppString('dlg_pw_add_curve_first');
      return;
    }
    // Validate all curves have at least X and Y
    for (let i = 0; i < this.curves.length; i++) {
      const entry: CurveEntry = this.curves[i];
      if (entry.xCol.length === 0) {
        this.statusMsg = getAppString('dlg_pw_define_x_first');
        return;
      }
      if (entry.yCol.length === 0) {
        this.statusMsg = getAppString('dlg_pw_need_y');
        return;
      }
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('plotWizard',
        JSON.stringify({ curves: this.curves } as PlotWizardArgs));
      hilog.info(DOMAIN, TAG, 'plotWizard dispatched: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'plotWizard failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_pw_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Row 1: Worksheet selector
              Row() {
                Text(getAppString('dlg_pw_worksheet'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
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
                .layoutWeight(1)
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ bottom: 12 })

              // Row 2: Columns list + assignment buttons side by side
              Row() {
                // Left: Available columns list
                Column() {
                  Text(getAppString('dlg_pw_columns'))
                    .fontSize(12)
                    .fontColor('#555555')
                    .margin({ bottom: 4 })
                  if (this.colNames.length > 0) {
                    Scroll() {
                      Column() {
                        ForEach(this.colNames, (name: string, idx: number) => {
                          Text(name)
                            .fontSize(12)
                            .fontColor(idx === this.selColIdx ? '#0078D7' : '#666666')
                            .fontWeight(idx === this.selColIdx ? FontWeight.Bold : FontWeight.Normal)
                            .padding({ top: 2, bottom: 2, left: 6 })
                            .width('100%')
                            .onClick(() => { this.onColumnPick(idx); })
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
                }
                .layoutWeight(1)

                // Right: Assignment buttons (2x3 grid)
                Column({ space: 6 }) {
                  Row({ space: 6 }) {
                    Button('<->X')
                      .fontSize(12).height(32)
                      .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
                      .border({ width: 1, color: '#E0E0E0' })
                      .onClick(() => { this.onAssignAxis('X'); })
                    Button('<->xErr')
                      .fontSize(12).height(32)
                      .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
                      .border({ width: 1, color: '#E0E0E0' })
                      .onClick(() => { this.onAssignAxis('xErr'); })
                  }
                  Row({ space: 6 }) {
                    Button('<->Y')
                      .fontSize(12).height(32)
                      .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
                      .border({ width: 1, color: '#E0E0E0' })
                      .onClick(() => { this.onAssignAxis('Y'); })
                    Button('<->yErr')
                      .fontSize(12).height(32)
                      .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
                      .border({ width: 1, color: '#E0E0E0' })
                      .onClick(() => { this.onAssignAxis('yErr'); })
                  }
                  Row({ space: 6 }) {
                    Button('<->Z')
                      .fontSize(12).height(32)
                      .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
                      .border({ width: 1, color: '#E0E0E0' })
                      .onClick(() => { this.onAssignAxis('Z'); })
                  }

                  // New curve / Delete curve
                  Row({ space: 6 }) {
                    Button(getAppString('dlg_pw_new_curve'))
                      .fontSize(12).height(32)
                      .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
                      .onClick(() => { this.onNewCurve(); })
                    Button(getAppString('dlg_pw_delete_curve'))
                      .fontSize(12).height(32)
                      .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
                      .onClick(() => { this.onDeleteCurve(); })
                  }
                  .margin({ top: 8 })
                }
                .width(200)
              }
              .width('100%')
              .margin({ bottom: 12 })

              // Curve list
              Text(getAppString('dlg_pw_curve_list'))
                .fontSize(13)
                .fontColor('#555555')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 4 })

              if (this.curves.length > 0) {
                Scroll() {
                  Column() {
                    ForEach(this.curves, (entry: CurveEntry, idx: number) => {
                      Text(this.curveDisplayText(entry))
                        .fontSize(12)
                        .fontColor(idx === this.selCurveIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.selCurveIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.onCurvePick(idx); })
                    }, (entry: CurveEntry, idx: number) => idx + ':' + entry.tableId)
                  }
                }
                .width('100%')
                .height(100)
                .border({ width: 1, color: '#D0D0D0' })
              } else {
                Text(getAppString('common_no_curves'))
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

          // Bottom buttons: Plot / Close
          Row() {
            Button(getAppString('common_close'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('dlg_plot_action'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onPlot(); })
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
