import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import {
  TEXT, TEXT_MUTED, BTN_BG, BTN_BG_ACCENT, BTN_TEXT, BTN_TEXT_ACCENT,
  RADIUS_4, RADIUS_8, BTN_HEIGHT, BTN_GAP,
  FS_DIALOG_TITLE, FS_DIALOG_BODY, FS_DIALOG_SMALL, FS_DIALOG_LABEL,
  SPACING_4, SPACING_8, SPACING_12, SPACING_16,
  SHADOW_RADIUS, SHADOW_COLOR, SHADOW_OFFSET_X, SHADOW_OFFSET_Y
} from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'GraphPropsDialog';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface SetGraphTitleArgs {
  title: string;
}

interface SetAxisTitleArgs {
  axis: number;
  text: string;
}

interface SetAxisScaleArgs {
  axis: number;
  scale: string;
}

@CustomDialog
export struct GraphPropsDialog {
  controller: CustomDialogController;
  @State titleText: string = '';
  @State xAxisTitle: string = '';
  @State yAxisTitle: string = '';
  @State logX: boolean = false;
  @State logY: boolean = false;

  private callQt(cmd: string, argsJson: string): void {
    try {
      const injector = qohos as QohosInjector;
      injector.callQtCommand(cmd, argsJson);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', cmd, (e as Error).message);
    }
  }

  build() {
    Column() {
       Text($r('app.string.dlg_graph_props'))
         .fontSize(FS_DIALOG_TITLE)
         .fontWeight(FontWeight.Bold)
         .fontColor(TEXT)
         .margin({ top: SPACING_16, bottom: SPACING_12 })

       Column({ space: SPACING_8 }) {
         Row({ space: SPACING_8 }) {
           TextInput({ placeholder: $r('app.string.dlg_graph_title_ph'), text: this.titleText })
             .layoutWeight(1)
             .fontSize(FS_DIALOG_BODY)
             .onChange((value: string) => { this.titleText = value; })
           Button($r('app.string.common_apply'))
             .fontSize(FS_DIALOG_SMALL).height(BTN_HEIGHT)
             .backgroundColor(BTN_BG_ACCENT).fontColor(BTN_TEXT_ACCENT).borderRadius(RADIUS_4)
            .onClick(() => {
              this.callQt('setGraphTitle',
                JSON.stringify({ title: this.titleText } as SetGraphTitleArgs));
            })
        }
        .width('100%')

         Row({ space: SPACING_8 }) {
           TextInput({ placeholder: $r('app.string.dlg_x_axis_title_ph'), text: this.xAxisTitle })
             .layoutWeight(1)
             .fontSize(FS_DIALOG_BODY)
             .onChange((value: string) => { this.xAxisTitle = value; })
           Button($r('app.string.common_apply'))
             .fontSize(FS_DIALOG_SMALL).height(BTN_HEIGHT)
             .backgroundColor(BTN_BG_ACCENT).fontColor(BTN_TEXT_ACCENT).borderRadius(RADIUS_4)
            .onClick(() => {
              this.callQt('setAxisTitle',
                JSON.stringify({ axis: 2, text: this.xAxisTitle } as SetAxisTitleArgs));
            })
        }
        .width('100%')

         Row({ space: SPACING_8 }) {
           TextInput({ placeholder: $r('app.string.dlg_y_axis_title_ph'), text: this.yAxisTitle })
             .layoutWeight(1)
             .fontSize(FS_DIALOG_BODY)
             .onChange((value: string) => { this.yAxisTitle = value; })
           Button($r('app.string.common_apply'))
             .fontSize(FS_DIALOG_SMALL).height(BTN_HEIGHT)
             .backgroundColor(BTN_BG_ACCENT).fontColor(BTN_TEXT_ACCENT).borderRadius(RADIUS_4)
            .onClick(() => {
              this.callQt('setAxisTitle',
                JSON.stringify({ axis: 0, text: this.yAxisTitle } as SetAxisTitleArgs));
            })
        }
        .width('100%')

        Row() {
          Toggle({ type: ToggleType.Switch, isOn: this.logX })
            .onChange((val: boolean) => {
              this.logX = val;
              this.callQt('setAxisScale',
                JSON.stringify({ axis: 2, scale: val ? 'log' : 'linear' } as SetAxisScaleArgs));
            })
           Text($r('app.string.dlg_log_x'))
             .fontSize(FS_DIALOG_BODY)
             .fontColor(TEXT_MUTED)
             .margin({ left: SPACING_8 })
        }
        .width('100%')
         .padding({ top: SPACING_4, bottom: SPACING_4 })

         Row() {
           Toggle({ type: ToggleType.Switch, isOn: this.logY })
             .onChange((val: boolean) => {
               this.logY = val;
               this.callQt('setAxisScale',
                 JSON.stringify({ axis: 0, scale: val ? 'log' : 'linear' } as SetAxisScaleArgs));
             })
           Text($r('app.string.dlg_log_y'))
             .fontSize(FS_DIALOG_BODY)
             .fontColor(TEXT_MUTED)
             .margin({ left: SPACING_8 })
        }
        .width('100%')
         .padding({ top: SPACING_4, bottom: SPACING_4 })

         Button($r('app.string.dlg_toggle_legend'))
           .fontSize(FS_DIALOG_BODY).height(36)
           .backgroundColor(BTN_BG_ACCENT).fontColor(BTN_TEXT_ACCENT).borderRadius(RADIUS_4)
          .width('100%')
          .onClick(() => {
            this.callQt('toggleLegend', '{}');
          })
      }
      .width('100%')
       .padding({ left: SPACING_16, right: SPACING_16 })

       Button($r('app.string.common_close'))
         .fontSize(FS_DIALOG_LABEL).height(BTN_HEIGHT)
         .backgroundColor(BTN_BG).fontColor(BTN_TEXT).borderRadius(RADIUS_4)
         .margin({ top: SPACING_12, bottom: SPACING_16 })
        .onClick(() => { this.controller.close(); })
    }
    .width(400)
    .backgroundColor('#FFFFFF')
    .borderRadius(RADIUS_8)
    .shadow({ radius: SHADOW_RADIUS, color: SHADOW_COLOR, offsetX: SHADOW_OFFSET_X, offsetY: SHADOW_OFFSET_Y })
    .alignItems(HorizontalAlign.Center)
  }
}
