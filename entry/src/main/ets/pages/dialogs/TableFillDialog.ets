// TableFillDialog — "Table" menu Fill Selection with dialog (batch 4).
// Fill mode selection: row numbers / random values / normal random.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface SetColumnValuesArgs {
  mode: string;
}

type FillModeType = 'row_numbers' | 'random' | 'normal_random';

@Component
export struct TableFillDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;

  @State selectedMode: FillModeType = 'row_numbers';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  private resetDefaults(): void {
    this.selectedMode = 'row_numbers';
  }

  private onCancel(): void {
    this.isVisible = false;
  }

  private onApply(): void {
    try {
      const injector = qohos as QohosInjector;
      const args: SetColumnValuesArgs = {
        mode: this.selectedMode
      };
      const result: string = injector.callQtCommand('setColumnValues', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'setColumnValues applied: %{public}s', result);
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
          .backgroundColor(Theme.BACKDROP_COLOR)
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('table_fill_title') || 'Fill Selection with')
            .fontSize(Theme.FS_DIALOG_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: Theme.SPACING_12 })

          Scroll() {
            Column() {
              // Description text
              Text(getAppString('table_fill_desc') || 'Choose a fill mode for the selected column(s).')
                .fontSize(Theme.FS_DIALOG_BODY)
                .fontColor(Theme.TEXT_MUTED)
                .textAlign(TextAlign.Center)
                .width('100%')
                .margin({ bottom: Theme.SPACING_16 })

              // Mode selection header
              Text(getAppString('table_fill_mode') || 'Fill Mode')
                .fontSize(Theme.FS_DIALOG_LABEL)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .margin({ bottom: Theme.SPACING_8 })

              // Mode radio buttons
              Column() {
                this.buildRadioItem('row_numbers', getAppString('table_fill_row_numbers') || 'Row Numbers', 'Row Numbers');
                this.buildRadioItem('random', getAppString('table_fill_random') || 'Random Values', 'Random Values');
                this.buildRadioItem('normal_random', getAppString('table_fill_normal_random') || 'Normal Random', 'Normal Random');
              }
              .width('100%')
              .margin({ bottom: Theme.SPACING_16 })

              // Hint text
              Text(this.getModeHint())
                .fontSize(Theme.FS_DIALOG_HINT)
                .fontColor(Theme.TEXT_HINT)
                .textAlign(TextAlign.Start)
                .width('100%')
                .padding(12)
                .backgroundColor('#F8F8F8')
                .borderRadius(Theme.RADIUS_4)
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
        .constraintSize({ maxHeight: '70%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(Theme.RADIUS_8)
        .shadow({ radius: Theme.SHADOW_RADIUS, color: Theme.SHADOW_COLOR, offsetX: Theme.SHADOW_OFFSET_X, offsetY: Theme.SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildRadioItem(value: FillModeType, label: string, keyLabel: string): void {
    Row() {
      Radio({ value: value, group: 'fillMode' })
        .checked(this.selectedMode === value)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.selectedMode = value;
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

  private getModeHint(): string {
    switch (this.selectedMode) {
      case 'row_numbers':
        return getAppString('table_fill_row_numbers_hint') || 'Fill with sequential row numbers starting from 1.';
      case 'random':
        return getAppString('table_fill_random_hint') || 'Fill with uniformly distributed random values between 0 and 1.';
      case 'normal_random':
        return getAppString('table_fill_normal_random_hint') || 'Fill with normally distributed random values (mean=0, std=1).';
      default:
        return '';
    }
  }
}
