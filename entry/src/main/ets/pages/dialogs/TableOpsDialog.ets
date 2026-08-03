// OHPlot table-operation dialogs (Phase 2).
// The desktop parameter dialogs (add columns / SetColValuesDialog /
// SortDialog) cannot be shown on the single-window QPA, so these ArkTS
// dialogs collect the parameters and dispatch the queued backend
// commands (addTableColumns / setColumnValues / sortTable); results
// arrive as message events toasted by QtEventHost.
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

interface AddColumnsArgs {
  tableId: string;
  count: number;
}

interface SetColumnValuesArgs {
  tableId: string;
  col: number;
  formula: string;
}

interface SortTableArgs {
  tableId: string;
  leading: number;
  ascending: boolean;
}

interface TableSizeCommandArgs {
  tableId: string;
  rows: number;
  cols: number;
}

function fetchColNames(tableId: string): string[] {
  try {
    const injector = qohos as QohosInjector;
    const result: string = injector.callQtCommand('getTableData',
      JSON.stringify({ tableId: tableId } as GetTableDataArgs));
    const parsed = JSON.parse(result) as TableDataResponse;
    if (parsed.success && parsed.data && parsed.data.colNames) {
      return parsed.data.colNames;
    }
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'fetchColNames failed: %{public}s', (e as Error).message);
  }
  return [];
}

// ── Add Columns ─────────────────────────────────────────────────────────
@Component
export struct AddColumnsDialog {
  @Link isVisible: boolean;
  @Prop tableId: string = '';
  @State countText: string = '1';

  onAdd(): void {
    let count: number = parseInt(this.countText);
    if (isNaN(count) || count < 1) { count = 1; }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('addTableColumns',
        JSON.stringify({ tableId: this.tableId, count: count } as AddColumnsArgs));
      hilog.info(DOMAIN, TAG, 'addTableColumns(%{public}d) queued: %{public}s', count, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addTableColumns failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_add_columns') + ' — ' + this.tableId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Row() {
            Text($r('app.string.dlg_num_columns'))
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            TextInput({ text: this.countText })
              .type(InputType.Number)
              .fontSize(13)
              .width(80)
              .height(34)
              .onChange((val: string) => { this.countText = val; })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 12 })

          Row() {
            Button($r('app.string.common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button($r('app.string.common_add'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onAdd(); })
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

// ── Set Column Values (muParser formula) ────────────────────────────────
@Component
export struct SetColumnValuesDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop tableId: string = '';
  @State colNames: string[] = [];
  @State selectedCol: number = 0;
  @State formula: string = '';
  @State statusMsg: string = '';

  onVisibleChanged(): void {
    if (this.isVisible) {
      // @Prop tableId may not have propagated yet in this frame; the
      // dispatcher stores the target in AppStorage synchronously.
      const target: string = AppStorage.get<string>('tableOpsTarget') ?? this.tableId;
      this.colNames = fetchColNames(target);
      if (this.selectedCol >= this.colNames.length) { this.selectedCol = 0; }
      this.statusMsg = '';
    }
  }

  onApply(): void {
    if (this.formula.trim() === '') {
      this.statusMsg = getAppString('msg_enter_formula');
      return;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('setColumnValues',
        JSON.stringify({
          tableId: this.tableId,
          col: this.selectedCol,
          formula: this.formula
        } as SetColumnValuesArgs));
      hilog.info(DOMAIN, TAG, 'setColumnValues(col=%{public}d, %{public}s) queued: %{public}s',
        this.selectedCol, this.formula, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setColumnValues failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_set_col_values') + ' — ' + this.tableId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text($r('app.string.dlg_column'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                if (this.colNames.length > 0) {
                  Scroll() {
                    Column() {
                      ForEach(this.colNames, (name: string, idx: number) => {
                        Text(name)
                          .fontSize(12)
                          .fontColor(idx === this.selectedCol ? '#0078D7' : '#666666')
                          .fontWeight(idx === this.selectedCol ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 3, bottom: 3, left: 6 })
                          .width('100%')
                          .onClick(() => { this.selectedCol = idx; })
                      }, (name: string, idx: number) => idx + ':' + name)
                    }
                  }
                  .layoutWeight(1)
                  .height(90)
                  .border({ width: 1, color: '#D0D0D0' })
                } else {
                  Text($r('app.string.common_no_columns'))
                    .fontSize(12)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .margin({ bottom: 12 })

              // muParser column formula: "i" is the (1-based) row index,
              // col("name") reads another column at the current row.
              Text($r('app.string.dlg_formula_muparser'))
                .fontSize(13)
                .fontColor('#555555')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 4 })
              TextInput({ text: this.formula, placeholder: $r('app.string.dlg_example_col') })
                .fontSize(13)
                .height(36)
                .width('100%')
                .onChange((val: string) => { this.formula = val; })
              Text($r('app.string.dlg_examples_hint'))
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

// ── Sort Table ──────────────────────────────────────────────────────────
@Component
export struct SortTableDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop tableId: string = '';
  @State colNames: string[] = [];
  // -1 = sort each column separately (no leading column)
  @State leadingCol: number = -1;
  @State ascending: boolean = true;

  onVisibleChanged(): void {
    if (this.isVisible) {
      const target: string = AppStorage.get<string>('tableOpsTarget') ?? this.tableId;
      this.colNames = fetchColNames(target);
      if (this.leadingCol >= this.colNames.length) { this.leadingCol = -1; }
    }
  }

  onSort(): void {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('sortTable',
        JSON.stringify({
          tableId: this.tableId,
          leading: this.leadingCol,
          ascending: this.ascending
        } as SortTableArgs));
      hilog.info(DOMAIN, TAG, 'sortTable(leading=%{public}d, asc=%{public}d) queued: %{public}s',
        this.leadingCol, this.ascending ? 1 : 0, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'sortTable failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_sort_table') + ' — ' + this.tableId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text($r('app.string.dlg_sort_by'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Scroll() {
                  Column() {
                    Text($r('app.string.dlg_each_col_separately'))
                      .fontSize(12)
                      .fontColor(this.leadingCol === -1 ? '#0078D7' : '#666666')
                      .fontWeight(this.leadingCol === -1 ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 3, bottom: 3, left: 6 })
                      .width('100%')
                      .onClick(() => { this.leadingCol = -1; })
                    ForEach(this.colNames, (name: string, idx: number) => {
                      Text(name)
                        .fontSize(12)
                        .fontColor(idx === this.leadingCol ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.leadingCol ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.leadingCol = idx; })
                    }, (name: string, idx: number) => idx + ':' + name)
                  }
                }
                .layoutWeight(1)
                .height(100)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text($r('app.string.dlg_order'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Text($r('app.string.dlg_ascending'))
                  .fontSize(12)
                  .fontColor(this.ascending ? '#0078D7' : '#666666')
                  .fontWeight(this.ascending ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 6, right: 12 })
                  .onClick(() => { this.ascending = true; })
                Text($r('app.string.dlg_descending'))
                  .fontSize(12)
                  .fontColor(!this.ascending ? '#0078D7' : '#666666')
                  .fontWeight(!this.ascending ? FontWeight.Bold : FontWeight.Normal)
                  .onClick(() => { this.ascending = false; })
              }
              .width('100%')
              .margin({ bottom: 8 })
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
            Button($r('app.string.dlg_sort_action'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onSort(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(380)
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

// ── Table Size ──────────────────────────────────────────────────────────
@Component
export struct TableSizeDialog {
  @Link isVisible: boolean;
  @Prop tableId: string = '';
  @State rowsText: string = '';
  @State colsText: string = '';

  onResize(): void {
    let rows: number = parseInt(this.rowsText);
    let cols: number = parseInt(this.colsText);
    if (isNaN(rows) || rows < 1) { rows = 1; }
    if (isNaN(cols) || cols < 1) { cols = 1; }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('tableSize',
        JSON.stringify({ tableId: this.tableId, rows: rows, cols: cols } as TableSizeCommandArgs));
      hilog.info(DOMAIN, TAG, 'tableSize(%{public}d × %{public}d) queued: %{public}s', rows, cols, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'tableSize failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_table_size') + ' — ' + this.tableId)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Row() {
            Text($r('app.string.dlg_num_rows'))
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            TextInput({ text: this.rowsText, placeholder: '30' })
              .type(InputType.Number)
              .fontSize(13)
              .width(80)
              .height(34)
              .onChange((val: string) => { this.rowsText = val; })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

          Row() {
            Text($r('app.string.dlg_num_cols'))
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            TextInput({ text: this.colsText, placeholder: '2' })
              .type(InputType.Number)
              .fontSize(13)
              .width(80)
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
            Button($r('app.string.common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onResize(); })
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
