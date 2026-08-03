// ToolsDialog — "Tools" menu Move Data Points / Remove Bad Data Points dialog (batch 4).
// Two-in-one dialog: tool prop switches between 'move' and 'remove' modes.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface MoveDataPointsArgs {}

interface RemoveBadDataPointsArgs {}

type ToolType = 'move' | 'remove';

@Component
export struct ToolsDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop tool: ToolType = 'move';

  @State currentTool: ToolType = 'move';

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
    this.currentTool = this.tool;
  }

  private onCancel(): void {
    this.isVisible = false;
  }

  private onApply(): void {
    try {
      const injector = qohos as QohosInjector;
      switch (this.currentTool) {
        case 'move':
          this.applyMove(injector);
          break;
        case 'remove':
          this.applyRemove(injector);
          break;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ToolsDialog apply failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
  }

  private applyMove(injector: QohosInjector): void {
    // TODO: B1 wire actual Qt command - dispatch move_data_points with tool value
    try {
      const args: MoveDataPointsArgs = {};
      const result: string = injector.callQtCommand('move_data_points', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'move_data_points applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'move_data_points failed: %{public}s', (e as Error).message);
    }
  }

  private applyRemove(injector: QohosInjector): void {
    // TODO: B1 wire actual Qt command - dispatch remove_bad_data with tool value
    try {
      const args: RemoveBadDataPointsArgs = {};
      const result: string = injector.callQtCommand('remove_bad_data', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'remove_bad_data applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'remove_bad_data failed: %{public}s', (e as Error).message);
    }
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
          // Title based on tool
          Text(this.currentTool === 'move' ? getAppString('tools_move_points') : getAppString('tools_remove_bad'))
            .fontSize(Theme.FS_DIALOG_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: Theme.SPACING_12 })

          Scroll() {
            Column() {
              // Description text
              Text(this.currentTool === 'move' 
                ? getAppString('tools_move_points_desc') || 'Move data points by dragging them to new positions.'
                : getAppString('tools_remove_bad_desc') || 'Remove bad/outlier data points from the active table.')
                .fontSize(Theme.FS_DIALOG_BODY)
                .fontColor(Theme.TEXT_MUTED)
                .textAlign(TextAlign.Center)
                .width('100%')
                .margin({ bottom: Theme.SPACING_16 })

              // Icon/illustration placeholder
              Column()
                .width(120)
                .height(80)
                .backgroundColor('#F0F0F0')
                .borderRadius(Theme.RADIUS_4)
                .alignSelf(ItemAlign.Center)
                .margin({ bottom: Theme.SPACING_16 })
              
              Text(this.currentTool === 'move' 
                ? getAppString('tools_move_hint') || 'Click Apply to activate point-moving mode.'
                : getAppString('tools_remove_hint') || 'Click Apply to activate outlier removal mode.')
                .fontSize(Theme.FS_DIALOG_HINT)
                .fontColor(Theme.TEXT_HINT)
                .textAlign(TextAlign.Center)
                .width('100%')
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
        .width(380)
        .constraintSize({ maxHeight: '70%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(Theme.RADIUS_8)
        .shadow({ radius: Theme.SHADOW_RADIUS, color: Theme.SHADOW_COLOR, offsetX: Theme.SHADOW_OFFSET_X, offsetY: Theme.SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }
}
