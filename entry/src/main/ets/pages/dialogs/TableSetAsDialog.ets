// TableSetAsDialog — "Table" menu Set Column(s) As dialog (batch 4).
// Column designation selection: X/Y/Z/X-error/Y-error roles.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface ColumnInfoResponse {
  success: boolean;
  data?: ColumnInfo[];
  error?: string;
}

interface ColumnInfo {
  col: number;
  name: string;
  type: string;
}

interface SetColPlotDesignationArgs {
  designation: string;
}

type DesignationType = 'x' | 'y' | 'z' | 'x_error' | 'y_error';

@Component
export struct TableSetAsDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;

  @State columns: string[] = [];
  @State selectedDesignation: DesignationType = 'x';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadColumns();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadColumns();
    }
  }

  private loadColumns(): void {
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getColumnInfo', '{}');
      const parsed = JSON.parse(result) as ColumnInfoResponse;
      if (parsed.success && parsed.data) {
        const names: string[] = [];
        for (let i = 0; i < parsed.data.length; i++) {
          names.push(parsed.data[i].name);
        }
        this.columns = names;
      } else if (parsed.error) {
        hilog.error(DOMAIN, TAG, 'TableSetAsDialog getColumnInfo failed: %{public}s', parsed.error);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'TableSetAsDialog getColumnInfo exception: %{public}s', (e as Error).message);
      // Fallback to empty list - B1 will wire actual command
      this.columns = [];
    }
  }

  private onCancel(): void {
    this.isVisible = false;
  }

  private onApply(): void {
    try {
      const injector = qohos as QohosInjector;
      const args: SetColPlotDesignationArgs = {
        designation: this.selectedDesignation
      };
      const result: string = injector.callQtCommand('setColPlotDesignation', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'setColPlotDesignation applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setColPlotDesignation failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.BACKDROP_COLOR)
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('table_set_as_title') || 'Set Column(s) As')
            .fontSize(Theme.FS_DIALOG_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: Theme.SPACING_12 })

          Scroll() {
            Column() {
              // Column list header
              Text(getAppString('table_columns') || 'Columns')
                .fontSize(Theme.FS_DIALOG_LABEL)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .margin({ bottom: Theme.SPACING_8 })

              // Column list (read-only display)
              if (this.columns.length > 0) {
                List({ space: 4 }) {
                  ForEach(this.columns, (colName: string, idx: number) => {
                    ListItem() {
                      Row() {
                        Text(colName)
                          .fontSize(Theme.FS_DIALOG_BODY)
                          .fontColor(Theme.TEXT_LIST)
                        Text(` (${idx})`)
                          .fontSize(Theme.FS_DIALOG_SMALL)
                          .fontColor(Theme.TEXT_EMPTY)
                      }
                      .width('100%')
                      .padding({ left: 12, right: 12 })
                    }
                  }, (colName: string, idx: number) => idx + ':' + colName)
                }
                .width('100%')
                .layoutWeight(1)
                .border({ width: 1, color: Theme.PANEL_BORDER })
                .margin({ bottom: Theme.SPACING_12 })
              } else {
                // Empty state placeholder - B1 will wire actual data
                Text(getAppString('msg_no_data') || 'No columns available.')
                  .fontSize(Theme.FS_DIALOG_HINT)
                  .fontColor(Theme.TEXT_EMPTY)
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding(16)
                  .backgroundColor('#F8F8F8')
                  .borderRadius(Theme.RADIUS_4)
                  .margin({ bottom: Theme.SPACING_12 })
              }

              // Designation selection header
              Text(getAppString('table_set_as_designation') || 'Set As')
                .fontSize(Theme.FS_DIALOG_LABEL)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .margin({ bottom: Theme.SPACING_8 })

              // Role radio buttons
              Column() {
                this.buildRadioItem('x', getAppString('table_set_as_x') || 'X', 'X');
                this.buildRadioItem('y', getAppString('table_set_as_y') || 'Y', 'Y');
                this.buildRadioItem('z', getAppString('table_set_as_z') || 'Z', 'Z');
                this.buildRadioItem('x_error', getAppString('table_set_as_x_error') || 'X error', 'X error');
                this.buildRadioItem('y_error', getAppString('table_set_as_y_error') || 'Y error', 'Y error');
              }
              .width('100%')
              .margin({ bottom: Theme.SPACING_16 })
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Bottom buttons
          Row() {
            Button(getAppString('common_cancel'))
              .fontSize(14).height(Theme.BTN_HEIGHT)
              .backgroundColor(Theme.BTN_BG).fontColor(Theme.BTN_TEXT).borderRadius(Theme.RADIUS_4)
              .onClick(() => { this.onCancel(); })
            Button(getAppString('common_apply'))
              .fontSize(14).height(Theme.BTN_HEIGHT)
              .backgroundColor(Theme.BTN_BG_ACCENT).fontColor(Theme.BTN_TEXT_ACCENT).borderRadius(Theme.RADIUS_4)
              .margin({ left: Theme.BTN_GAP })
              .onClick(() => { this.onApply(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(360)
        .constraintSize({ maxHeight: '75%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(Theme.RADIUS_8)
        .shadow({ radius: Theme.SHADOW_RADIUS, color: Theme.SHADOW_COLOR, offsetX: Theme.SHADOW_OFFSET_X, offsetY: Theme.SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildRadioItem(value: DesignationType, label: string, keyLabel: string): void {
    Row() {
      Radio({ value: value, group: 'designation' })
        .checked(this.selectedDesignation === value)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.selectedDesignation = value;
          }
        })
      Text(label)
        .fontSize(Theme.FS_DIALOG_BODY)
        .fontColor(Theme.TEXT)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }
}
