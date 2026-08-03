// LineDialog — "Graph > Draw Line / Draw Arrow" dialog (batch 2).
// Line options: pen (color/width/style), arrow start/end toggles,
// head length/angle/filled, geometry (start/end coords).
// On OK dispatches drawLine or drawArrow.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface DrawLineArgs {
  color: string;
  width: number;
  style: number;
  arrowStart: boolean;
  arrowEnd: boolean;
  headLength: number;
  headAngle: number;
  headFilled: boolean;
  unit: number;
  xStart: number;
  yStart: number;
  xEnd: number;
  yEnd: number;
}

const PEN_COLORS: string[] = [
  '#000000', '#FFFFFF', '#FF0000', '#00FF00', '#0000FF',
  '#FFFF00', '#FF00FF', '#00FFFF', '#FF8000', '#8000FF'
];

const PEN_WIDTHS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

const PEN_STYLES: string[] = ['Solid', 'Dash', 'Dot', 'DashDot', 'DashDotDot'];

@Component
export struct LineDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State colorIdx: number = 0;
  @State widthIdx: number = 0;
  @State styleIdx: number = 0;
  @State arrowStart: boolean = false;
  @State arrowEnd: boolean = false;
  @State headLength: number = 8;
  @State headAngle: number = 45;
  @State headFilled: boolean = true;
  @State unitIdx: number = 0;
  @State xStart: string = '0';
  @State yStart: string = '0';
  @State xEnd: string = '1';
  @State yEnd: string = '1';
  @State tabIdx: number = 0;
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
    this.colorIdx = 0;
    this.widthIdx = 0;
    this.styleIdx = 0;
    this.arrowStart = false;
    this.arrowEnd = false;
    this.headLength = 8;
    this.headAngle = 45;
    this.headFilled = true;
    this.unitIdx = 0;
    this.xStart = '0';
    this.yStart = '0';
    this.xEnd = '1';
    this.yEnd = '1';
    this.tabIdx = 0;
    this.statusMsg = '';
  }

  private onOk(): void {
    const cmd: string = (this.arrowStart || this.arrowEnd) ? 'drawArrow' : 'drawLine';
    const args: DrawLineArgs = {
      color: PEN_COLORS[this.colorIdx],
      width: PEN_WIDTHS[this.widthIdx],
      style: this.styleIdx,
      arrowStart: this.arrowStart,
      arrowEnd: this.arrowEnd,
      headLength: this.headLength,
      headAngle: this.headAngle,
      headFilled: this.headFilled,
      unit: this.unitIdx,
      xStart: parseFloat(this.xStart) || 0,
      yStart: parseFloat(this.yStart) || 0,
      xEnd: parseFloat(this.xEnd) || 1,
      yEnd: parseFloat(this.yEnd) || 1
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand(cmd, JSON.stringify(args));
      hilog.info(DOMAIN, TAG, '%{public}s queued: %{public}s', cmd, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', cmd, (e as Error).message);
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
          Text(getAppString('dlg_line_options'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          // Tab bar
          Row() {
            ForEach([getAppString('dlg_tab_options'), getAppString('dlg_tab_arrow_head'),
              getAppString('dlg_tab_geometry')], (label: string, idx: number) => {
              Text(label)
                .fontSize(13)
                .fontColor(idx === this.tabIdx ? '#0078D7' : '#666666')
                .fontWeight(idx === this.tabIdx ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .border({
                  width: idx === this.tabIdx ? 0 : 0,
                  color: '#D0D0D0'
                })
                .backgroundColor(idx === this.tabIdx ? '#FFFFFF' : '#F0F0F0')
                .borderRadius({ topLeft: 4, topRight: 4 })
                .onClick(() => { this.tabIdx = idx; })
            }, (label: string, idx: number) => label + ':' + idx)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          Scroll() {
            Column() {
              // --- Options tab ---
              if (this.tabIdx === 0) {
                // Pen color
                Row() {
                  Text(getAppString('dlg_color'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(60)
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(PEN_COLORS, (c: string, idx: number) => {
                      Row()
                        .width(24).height(24)
                        .backgroundColor(c)
                        .border({
                          width: idx === this.colorIdx ? 2 : 1,
                          color: idx === this.colorIdx ? '#0078D7' : '#D0D0D0'
                        })
                        .margin(2)
                        .onClick(() => { this.colorIdx = idx; })
                    }, (c: string, idx: number) => c + ':' + idx)
                  }
                }
                .width('100%')
                .margin({ top: 8 })
                .alignItems(VerticalAlign.Top)

                // Pen width
                Row() {
                  Text(getAppString('dlg_width'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(60)
                  Slider({
                    value: PEN_WIDTHS[this.widthIdx],
                    min: 1,
                    max: 10,
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .layoutWeight(1)
                    .onChange((value: number) => {
                      const target: number = Math.round(value);
                      for (let i = 0; i < PEN_WIDTHS.length; i++) {
                        if (PEN_WIDTHS[i] === target) {
                          this.widthIdx = i;
                          break;
                        }
                      }
                    })
                  Text(PEN_WIDTHS[this.widthIdx].toString())
                    .fontSize(12)
                    .fontColor('#555555')
                    .width(30)
                }
                .width('100%')
                .margin({ top: 10 })
                .alignItems(VerticalAlign.Center)

                // Pen style
                Row() {
                  Text(getAppString('dlg_style'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(60)
                  Column() {
                    ForEach(PEN_STYLES, (s: string, idx: number) => {
                      Text(s)
                        .fontSize(12)
                        .fontColor(idx === this.styleIdx ? '#0078D7' : '#666666')
                        .fontWeight(idx === this.styleIdx ? FontWeight.Bold : FontWeight.Normal)
                        .padding({ top: 2, bottom: 2, left: 6 })
                        .width('100%')
                        .onClick(() => { this.styleIdx = idx; })
                    }, (s: string, idx: number) => s + ':' + idx)
                  }
                  .layoutWeight(1)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .margin({ top: 10 })
                .alignItems(VerticalAlign.Top)

                // Arrow checkboxes
                Row() {
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.arrowStart })
                      .width(20).height(20)
                      .onChange((val: boolean) => { this.arrowStart = val; })
                    Text(getAppString('dlg_arrow_start'))
                      .fontSize(13)
                      .fontColor('#555555')
                      .margin({ left: 6 })
                  }
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.arrowEnd })
                      .width(20).height(20)
                      .onChange((val: boolean) => { this.arrowEnd = val; })
                    Text(getAppString('dlg_arrow_end'))
                      .fontSize(13)
                      .fontColor('#555555')
                      .margin({ left: 6 })
                  }
                  .margin({ left: 20 })
                }
                .width('100%')
                .margin({ top: 12 })
              }

              // --- Arrow Head tab ---
              if (this.tabIdx === 1) {
                Row() {
                  Text(getAppString('dlg_head_length'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  TextInput({ text: this.headLength.toString() })
                    .type(InputType.Number)
                    .width(80)
                    .fontSize(14)
                    .onChange((value: string) => {
                      const n: number = parseInt(value);
                      if (!isNaN(n)) { this.headLength = n; }
                    })
                }
                .width('100%')
                .margin({ top: 8 })

                Row() {
                  Text(getAppString('dlg_head_angle'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Slider({
                    value: this.headAngle,
                    min: 0,
                    max: 85,
                    step: 5,
                    style: SliderStyle.InSet
                  })
                    .layoutWeight(1)
                    .onChange((value: number) => { this.headAngle = Math.round(value); })
                  Text(this.headAngle.toString())
                    .fontSize(12)
                    .fontColor('#555555')
                    .width(30)
                }
                .width('100%')
                .margin({ top: 10 })
                .alignItems(VerticalAlign.Center)

                Row() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.headFilled })
                    .width(20).height(20)
                    .onChange((val: boolean) => { this.headFilled = val; })
                  Text(getAppString('dlg_head_filled'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .margin({ left: 6 })
                }
                .width('100%')
                .margin({ top: 10 })
              }

              // --- Geometry tab ---
              if (this.tabIdx === 2) {
                Row() {
                  Text(getAppString('dlg_unit'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .width(80)
                  Column() {
                    ForEach([getAppString('dlg_scale_coords'), getAppString('dlg_pixels')],
                      (label: string, idx: number) => {
                        Text(label)
                          .fontSize(12)
                          .fontColor(idx === this.unitIdx ? '#0078D7' : '#666666')
                          .fontWeight(idx === this.unitIdx ? FontWeight.Bold : FontWeight.Normal)
                          .padding({ top: 2, bottom: 2, left: 6 })
                          .width('100%')
                          .onClick(() => { this.unitIdx = idx; })
                      }, (label: string, idx: number) => label + ':' + idx)
                  }
                  .layoutWeight(1)
                  .border({ width: 1, color: '#D0D0D0' })
                }
                .width('100%')
                .margin({ top: 8 })
                .alignItems(VerticalAlign.Top)

                // Start point
                Column() {
                  Text(getAppString('dlg_start_point'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 4 })
                  Row() {
                    Text('X')
                      .fontSize(13)
                      .fontColor('#555555')
                      .width(20)
                    TextInput({ text: this.xStart })
                      .type(InputType.Number)
                      .layoutWeight(1)
                      .fontSize(14)
                      .onChange((value: string) => { this.xStart = value; })
                    Text('Y')
                      .fontSize(13)
                      .fontColor('#555555')
                      .width(20)
                      .margin({ left: 8 })
                    TextInput({ text: this.yStart })
                      .type(InputType.Number)
                      .layoutWeight(1)
                      .fontSize(14)
                      .onChange((value: string) => { this.yStart = value; })
                  }
                  .width('100%')
                }
                .width('100%')
                .margin({ top: 10 })
                .padding(8)
                .backgroundColor('#F8F8F8')
                .borderRadius(4)

                // End point
                Column() {
                  Text(getAppString('dlg_end_point'))
                    .fontSize(13)
                    .fontColor('#555555')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 4 })
                  Row() {
                    Text('X')
                      .fontSize(13)
                      .fontColor('#555555')
                      .width(20)
                    TextInput({ text: this.xEnd })
                      .type(InputType.Number)
                      .layoutWeight(1)
                      .fontSize(14)
                      .onChange((value: string) => { this.xEnd = value; })
                    Text('Y')
                      .fontSize(13)
                      .fontColor('#555555')
                      .width(20)
                      .margin({ left: 8 })
                    TextInput({ text: this.yEnd })
                      .type(InputType.Number)
                      .layoutWeight(1)
                      .fontSize(14)
                      .onChange((value: string) => { this.yEnd = value; })
                  }
                  .width('100%')
                }
                .width('100%')
                .margin({ top: 10 })
                .padding(8)
                .backgroundColor('#F8F8F8')
                .borderRadius(4)
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
        .constraintSize({ maxHeight: '85%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
