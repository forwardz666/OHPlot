import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

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
      Text('Graph Properties')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 16, bottom: 12 })

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          TextInput({ placeholder: 'Graph title', text: this.titleText })
            .layoutWeight(1)
            .fontSize(13)
            .onChange((value: string) => { this.titleText = value; })
          Button('Apply')
            .fontSize(12).height(32)
            .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
            .onClick(() => {
              this.callQt('setGraphTitle',
                JSON.stringify({ title: this.titleText } as SetGraphTitleArgs));
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: 'X axis title', text: this.xAxisTitle })
            .layoutWeight(1)
            .fontSize(13)
            .onChange((value: string) => { this.xAxisTitle = value; })
          Button('Apply')
            .fontSize(12).height(32)
            .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
            .onClick(() => {
              this.callQt('setAxisTitle',
                JSON.stringify({ axis: 2, text: this.xAxisTitle } as SetAxisTitleArgs));
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: 'Y axis title', text: this.yAxisTitle })
            .layoutWeight(1)
            .fontSize(13)
            .onChange((value: string) => { this.yAxisTitle = value; })
          Button('Apply')
            .fontSize(12).height(32)
            .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
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
          Text('Log X axis')
            .fontSize(13)
            .fontColor('#555555')
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        Row() {
          Toggle({ type: ToggleType.Switch, isOn: this.logY })
            .onChange((val: boolean) => {
              this.logY = val;
              this.callQt('setAxisScale',
                JSON.stringify({ axis: 0, scale: val ? 'log' : 'linear' } as SetAxisScaleArgs));
            })
          Text('Log Y axis')
            .fontSize(13)
            .fontColor('#555555')
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        Button('Toggle Legend')
          .fontSize(13).height(36)
          .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
          .width('100%')
          .onClick(() => {
            this.callQt('toggleLegend', '{}');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Button('Close')
        .fontSize(14).height(32)
        .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
        .margin({ top: 12, bottom: 16 })
        .onClick(() => { this.controller.close(); })
    }
    .width(400)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
    .alignItems(HorizontalAlign.Center)
  }
}
