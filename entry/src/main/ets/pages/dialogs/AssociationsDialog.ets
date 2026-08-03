// AssociationsDialog — "Plot Associations" dialog.
// Mirrors Qt AssociationsDialog: a QTableWidget mapping columns to
// responsibilities (X/Y/xErr/yErr), plus an associations list below.
// Uses getTableData/getColumnInfo to populate columns; on Apply/OK
// dispatches updatePlotAssociation commands.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'AssociationsDialog';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
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

interface PlotAssociationEntry {
  curveName: string;
  tableName: string;
  xCol: string;
  yCol: string;
  xErrCol: string;
  yErrCol: string;
}

interface UpdatePlotAssociationArgs {
  curveIdx: number;
  association: string;
}

// Column role assignment for the grid
interface ColRoleAssignment {
  colName: string;
  xChecked: boolean;
  yChecked: boolean;
  xErrChecked: boolean;
  yErrChecked: boolean;
}

@Component
export struct AssociationsDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State selTableIdx: number = 0;
  @State tables: TableInfo[] = [];
  @State colRoles: ColRoleAssignment[] = [];
  @State associations: PlotAssociationEntry[] = [];
  @State selAssocIdx: number = -1;
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
    this.selAssocIdx = -1;
    this.fetchTables();
    this.fetchAssociations();
  }

  private fetchTables(): void {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getTableList', '{}');
      const parsed = JSON.parse(result) as TableListResponse;
      if (parsed.success && parsed.data) {
        this.tables = parsed.data;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'fetchTables failed: %{public}s', (e as Error).message);
    }
    if (this.tables.length > 0) {
      this.selTableIdx = 0;
      this.loadColumnRoles();
    }
  }

  private loadColumnRoles(): void {
    if (this.selTableIdx < 0 || this.selTableIdx >= this.tables.length) {
      this.colRoles = [];
      return;
    }
    const tName: string = this.tables[this.selTableIdx].name;
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getColumnInfo',
        JSON.stringify({ tableId: tName }));
      const parsed = JSON.parse(result) as ColumnInfoResponse;
      if (parsed.success && parsed.data) {
        const roles: ColRoleAssignment[] = [];
        for (let i = 0; i < parsed.data.length; i++) {
          const ci: ColumnInfo = parsed.data[i];
          const designation: string = ci.plotDesignation;
          roles.push({
            colName: ci.name,
            xChecked: designation === 'X',
            yChecked: designation === 'Y',
            xErrChecked: designation === 'xErr',
            yErrChecked: designation === 'yErr',
          });
        }
        this.colRoles = roles;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadColumnRoles failed: %{public}s', (e as Error).message);
    }
  }

  private fetchAssociations(): void {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getPlotAssociations', '{}');
      if (result.length > 0) {
        const parsed = JSON.parse(result) as AssociationsResponse;
        if (parsed.success && parsed.data) {
          this.associations = parsed.data;
          if (this.associations.length > 0) {
            this.selAssocIdx = 0;
          }
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'fetchAssociations failed: %{public}s', (e as Error).message);
    }
  }

  onTablePick(idx: number): void {
    this.selTableIdx = idx;
    this.loadColumnRoles();
  }

  onAssocPick(idx: number): void {
    this.selAssocIdx = idx;
  }

  onToggleRole(colIdx: number, role: string): void {
    if (colIdx < 0 || colIdx >= this.colRoles.length) {
      return;
    }
    const next: ColRoleAssignment[] = this.colRoles.slice();
    const entry: ColRoleAssignment = next[colIdx];
    if (role === 'X') {
      entry.xChecked = !entry.xChecked;
    } else if (role === 'Y') {
      entry.yChecked = !entry.yChecked;
    } else if (role === 'xErr') {
      entry.xErrChecked = !entry.xErrChecked;
    } else {
      entry.yErrChecked = !entry.yErrChecked;
    }
    next[colIdx] = entry;
    this.colRoles = next;
  }

  private buildAssociationString(entry: PlotAssociationEntry): string {
    let text: string = entry.tableName + ': ';
    if (entry.xCol.length > 0) {
      text += entry.xCol + '(X)';
    }
    if (entry.yCol.length > 0) {
      text += ', ' + entry.yCol + '(Y)';
    }
    if (entry.xErrCol.length > 0) {
      text += ', ' + entry.xErrCol + '(xErr)';
    }
    if (entry.yErrCol.length > 0) {
      text += ', ' + entry.yErrCol + '(yErr)';
    }
    return text;
  }

  onUpdateCurves(): void {
    // Dispatch the updated column role assignments
    for (let i = 0; i < this.associations.length; i++) {
      const entry: PlotAssociationEntry = this.associations[i];
      const assocStr: string = this.buildAssociationString(entry);
      try {
        const injector = qohos as QohosInjector;
        injector.callQtCommand('updatePlotAssociation',
          JSON.stringify({ curveIdx: i, association: assocStr } as UpdatePlotAssociationArgs));
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'updatePlotAssociation failed: %{public}s', (e as Error).message);
      }
    }
    hilog.info(DOMAIN, TAG, 'AssociationsDialog: curves updated');
  }

  onOk(): void {
    this.onUpdateCurves();
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
          Text(getAppString('dlg_assoc_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          // Spreadsheet label
          Row() {
            Text(getAppString('dlg_assoc_spreadsheet'))
              .fontSize(13).fontColor('#555555')
            if (this.selTableIdx >= 0 && this.selTableIdx < this.tables.length) {
              Text(this.tables[this.selTableIdx].name)
                .fontSize(13).fontColor('#333333').fontWeight(FontWeight.Bold)
                .margin({ left: 6 })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

          Scroll() {
            Column() {
              // Table selector (tabs-like row)
              Row() {
                ForEach(this.tables, (t: TableInfo, idx: number) => {
                  Text(t.label.length > 0 ? t.label : t.name)
                    .fontSize(11)
                    .fontColor(idx === this.selTableIdx ? '#0078D7' : '#666666')
                    .fontWeight(idx === this.selTableIdx ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ top: 3, bottom: 3, left: 6, right: 6 })
                    .border({
                      width: 1,
                      color: idx === this.selTableIdx ? '#0078D7' : '#D0D0D0'
                    })
                    .borderRadius(4)
                    .backgroundColor(idx === this.selTableIdx ? '#E8F0FE' : '#F8F8F8')
                    .margin({ right: 4 })
                    .onClick(() => { this.onTablePick(idx); })
                }, (t: TableInfo, idx: number) => t.name + ':' + idx)
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Column-role grid (Column | X | Y | xErr | yErr)
              // Header
              Row() {
                Text(getAppString('dlg_assoc_column'))
                  .fontSize(12).fontColor('#555555')
                  .layoutWeight(1)
                Text('X')
                  .fontSize(12).fontColor('#555555').width(36).textAlign(TextAlign.Center)
                Text('Y')
                  .fontSize(12).fontColor('#555555').width(36).textAlign(TextAlign.Center)
                Text('xErr')
                  .fontSize(12).fontColor('#555555').width(36).textAlign(TextAlign.Center)
                Text('yErr')
                  .fontSize(12).fontColor('#555555').width(36).textAlign(TextAlign.Center)
              }
              .width('100%')
              .padding({ left: 4, right: 4 })

              // Rows
              Scroll() {
                Column() {
                  ForEach(this.colRoles, (cr: ColRoleAssignment, idx: number) => {
                    Row() {
                      Text(cr.colName)
                        .fontSize(12).fontColor('#555555')
                        .layoutWeight(1)
                      Checkbox()
                        .select(cr.xChecked)
                        .width(24).height(24)
                        .onChange((v: boolean) => { this.onToggleRole(idx, 'X'); })
                      Checkbox()
                        .select(cr.yChecked)
                        .width(24).height(24)
                        .onChange((v: boolean) => { this.onToggleRole(idx, 'Y'); })
                      Checkbox()
                        .select(cr.xErrChecked)
                        .width(24).height(24)
                        .onChange((v: boolean) => { this.onToggleRole(idx, 'xErr'); })
                      Checkbox()
                        .select(cr.yErrChecked)
                        .width(24).height(24)
                        .onChange((v: boolean) => { this.onToggleRole(idx, 'yErr'); })
                    }
                    .width('100%')
                    .padding({ top: 2, bottom: 2, left: 4, right: 4 })
                    .border({ width: { bottom: 1 }, color: '#E0E0E0' })
                  }, (cr: ColRoleAssignment, idx: number) => idx + ':' + cr.colName)
                }
              }
              .width('100%')
              .height(120)
              .border({ width: 1, color: '#D0D0D0' })
              .margin({ bottom: 12 })

              // Associations list
              Text(getAppString('dlg_assoc_list'))
                .fontSize(13).fontColor('#555555')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 4 })

              if (this.associations.length > 0) {
                Scroll() {
                  Column() {
                    ForEach(this.associations, (entry: PlotAssociationEntry, idx: number) => {
                      Text(this.buildAssociationString(entry))
                        .fontSize(12)
                        .fontColor(idx === this.selAssocIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.selAssocIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 3, bottom: 3, left: 6 })
                        .width('100%')
                        .onClick(() => { this.onAssocPick(idx); })
                    }, (entry: PlotAssociationEntry, idx: number) => idx + ':' + entry.curveName)
                  }
                }
                .width('100%')
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })
              } else {
                Text(getAppString('common_no_curves'))
                  .fontSize(12).fontColor('#999999')
              }
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Bottom buttons: Update curves / OK / Cancel
          Row() {
            Button(getAppString('common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('dlg_assoc_update'))
              .fontSize(14).height(32)
              .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
              .border({ width: 1, color: '#E0E0E0' })
              .margin({ left: 8 })
              .onClick(() => { this.onUpdateCurves(); })
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 8 })
              .onClick(() => { this.onOk(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: 8 })
          .justifyContent(FlexAlign.End)
        }
        .width(440)
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

interface AssociationsResponse {
  success: boolean;
  data?: PlotAssociationEntry[];
  error?: string;
}
