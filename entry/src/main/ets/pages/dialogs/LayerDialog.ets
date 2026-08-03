// LayerDialog — "Graph > Arrange Layers" dialog (batch 2).
// Layer arrangement: layers count + auto layout, alignment (H/V),
// grid (cols/rows), canvas size, spacing (col/row gap, margins).
// On OK dispatches arrangeLayers.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface ArrangeLayersArgs {
  layers: number;
  autoLayout: boolean;
  alignH: number;
  alignV: number;
  gridCols: number;
  gridRows: number;
  customCanvas: boolean;
  canvasWidth: number;
  canvasHeight: number;
  colsGap: number;
  rowsGap: number;
  marginLeft: number;
  marginRight: number;
  marginTop: number;
  marginBottom: number;
}

@Component
export struct LayerDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State layerCount: string = '1';
  @State autoLayout: boolean = false;
  @State alignHIdx: number = 0;
  @State alignVIdx: number = 0;
  @State gridCols: string = '1';
  @State gridRows: string = '1';
  @State customCanvas: boolean = false;
  @State canvasWidth: string = '600';
  @State canvasHeight: string = '400';
  @State colsGap: string = '5';
  @State rowsGap: string = '5';
  @State marginLeft: string = '0';
  @State marginRight: string = '0';
  @State marginTop: string = '0';
  @State marginBottom: string = '0';
  @State statusMsg: string = '';

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
    this.layerCount = '1';
    this.autoLayout = false;
    this.alignHIdx = 0;
    this.alignVIdx = 0;
    this.gridCols = '1';
    this.gridRows = '1';
    this.customCanvas = false;
    this.canvasWidth = '600';
    this.canvasHeight = '400';
    this.colsGap = '5';
    this.rowsGap = '5';
    this.marginLeft = '0';
    this.marginRight = '0';
    this.marginTop = '0';
    this.marginBottom = '0';
    this.statusMsg = '';
  }

  private onOk(): void {
    const args: ArrangeLayersArgs = {
      layers: parseInt(this.layerCount) || 1,
      autoLayout: this.autoLayout,
      alignH: this.alignHIdx,
      alignV: this.alignVIdx,
      gridCols: parseInt(this.gridCols) || 1,
      gridRows: parseInt(this.gridRows) || 1,
      customCanvas: this.customCanvas,
      canvasWidth: parseInt(this.canvasWidth) || 600,
      canvasHeight: parseInt(this.canvasHeight) || 400,
      colsGap: parseInt(this.colsGap) || 0,
      rowsGap: parseInt(this.rowsGap) || 0,
      marginLeft: parseInt(this.marginLeft) || 0,
      marginRight: parseInt(this.marginRight) || 0,
      marginTop: parseInt(this.marginTop) || 0,
      marginBottom: parseInt(this.marginBottom) || 0
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('arrangeLayers', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'arrangeLayers queued: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'arrangeLayers failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_arrange_layers'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Layers group
              Column() {
                Text(getAppString('dlg_layers'))
                  .fontSize(14)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 6 })
                Row() {
                  Text(getAppString('dlg_number'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.layerCount })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((value: string) => { this.layerCount = value; })
                }
                .width('100%')
                Row() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.autoLayout })
                    .width(20).height(20)
                    .onChange((val: boolean) => { this.autoLayout = val; })
                  Text(getAppString('dlg_auto_layout'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .margin({ left: 6 })
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(4)

              // Alignment group
              Column() {
                Text(getAppString('dlg_alignment'))
                  .fontSize(14)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 6 })
                Row() {
                  Text(getAppString('dlg_horizontal'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Column() {
                    ForEach([getAppString('dlg_align_center'), getAppString('dlg_align_left'),
                      getAppString('dlg_align_right')], (label: string, idx: number) => {
                      Text(label)
                        .fontSize(12)
                        .fontColor(idx === this.alignHIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.alignHIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 2, bottom: 2, left: 6 })
                        .width('100%')
                        .onClick(() => { this.alignHIdx = idx; })
                    }, (label: string, idx: number) => label + ':' + idx)
                  }
                  .layoutWeight(1)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)

                Row() {
                  Text(getAppString('dlg_vertical'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Column() {
                    ForEach([getAppString('dlg_align_center'), getAppString('dlg_align_top'),
                      getAppString('dlg_align_bottom')], (label: string, idx: number) => {
                      Text(label)
                        .fontSize(12)
                        .fontColor(idx === this.alignVIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.alignVIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 2, bottom: 2, left: 6 })
                        .width('100%')
                        .onClick(() => { this.alignVIdx = idx; })
                    }, (label: string, idx: number) => label + ':' + idx)
                  }
                  .layoutWeight(1)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .margin({ top: 6 })
                .alignItems(VerticalAlign.Top)
              }
              .width('100%')
              .margin({ top: 10 })
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(4)

              // Grid group
              Column() {
                Text(getAppString('dlg_grid'))
                  .fontSize(14)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 6 })
                Row() {
                  Text(getAppString('dlg_cols'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.gridCols })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((value: string) => { this.gridCols = value; })
                }
                .width('100%')
                Row() {
                  Text(getAppString('dlg_rows'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.gridRows })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((value: string) => { this.gridRows = value; })
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .margin({ top: 10 })
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(4)
              .opacity(this.autoLayout ? 0.5 : 1.0)

              // Canvas size group
              Column() {
                Row() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.customCanvas })
                    .width(20).height(20)
                    .onChange((val: boolean) => { this.customCanvas = val; })
                  Text(getAppString('dlg_layer_canvas_size'))
                    .fontSize(14)
                    .fontColor('#333333')
                    .fontWeight(FontWeight.Bold)
                    .margin({ left: 6 })
                }
                .margin({ bottom: 6 })
                Row() {
                  Text(getAppString('dlg_img_width'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.canvasWidth })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((value: string) => { this.canvasWidth = value; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(20)
                }
                .width('100%')
                Row() {
                  Text(getAppString('dlg_img_height'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.canvasHeight })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((value: string) => { this.canvasHeight = value; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(20)
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .margin({ top: 10 })
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(4)
              .opacity(this.autoLayout ? 0.5 : 1.0)

              // Spacing group
              Column() {
                Text(getAppString('dlg_spacing'))
                  .fontSize(14)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 6 })
                Row() {
                  Text(getAppString('dlg_cols_gap'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.colsGap })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.colsGap = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
                Row() {
                  Text(getAppString('dlg_rows_gap'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.rowsGap })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.rowsGap = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
                Row() {
                  Text(getAppString('dlg_margin_left'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.marginLeft })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.marginLeft = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
                Row() {
                  Text(getAppString('dlg_margin_right'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.marginRight })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.marginRight = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
                Row() {
                  Text(getAppString('dlg_margin_top'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.marginTop })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.marginTop = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
                Row() {
                  Text(getAppString('dlg_margin_bottom'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(100)
                  TextInput({ text: this.marginBottom })
                    .type(InputType.Number)
                    .layoutWeight(1)
                    .fontSize(14)
                    .onChange((v: string) => { this.marginBottom = v; })
                  Text('px')
                    .fontSize(12)
                    .fontColor('#999999')
                    .width(40)
                }
                .width('100%')
                .margin({ top: 4 })
              }
              .width('100%')
              .margin({ top: 10 })
              .padding(8)
              .backgroundColor('#F8F8F8')
              .borderRadius(4)

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
            Button(getAppString('common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('common_apply'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onOk(); })
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onOk(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(420)
        .constraintSize({ maxHeight: '90%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
