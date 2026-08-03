// TextDialog — "Graph > Add Text" dialog (batch 2).
// Text label options: font family/size/bold/italic, text color, background
// color + transparency, alignment, frame type. On OK dispatches addText.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface AddTextArgs {
  text: string;
  fontFamily: string;
  fontSize: number;
  bold: boolean;
  italic: boolean;
  textColor: string;
  bgFrame: number;
  bgOpacity: number;
  bgColor: string;
  alignment: number;
  angle: number;
}

const FONT_FAMILIES: string[] = [
  'HarmonyOS Sans', 'HarmonyOS Serif', 'monospace', 'sans-serif', 'serif'
];

const FONT_SIZES: number[] = [8, 10, 12, 14, 16, 18, 20, 24, 28, 36, 48];

@Component
export struct TextDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State textContent: string = '';
  @State fontFamilyIdx: number = 0;
  @State fontSizeIdx: number = 4; // 14
  @State isBold: boolean = false;
  @State isItalic: boolean = false;
  @State textColorIdx: number = 0;
  @State bgFrameIdx: number = 0;
  @State bgOpacity: number = 255;
  @State bgColorIdx: number = 7;
  @State alignmentIdx: number = 0;
  @State angleIdx: number = 0;
  @State statusMsg: string = '';

  private readonly COLORS: string[] = [
    '#000000', '#FFFFFF', '#FF0000', '#00FF00', '#0000FF',
    '#FFFF00', '#FF00FF', '#00FFFF', '#FF8000', '#8000FF',
    '#808080', '#C0C0C0'
  ];

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
    this.textContent = '';
    this.fontFamilyIdx = 0;
    this.fontSizeIdx = 4;
    this.isBold = false;
    this.isItalic = false;
    this.textColorIdx = 0;
    this.bgFrameIdx = 0;
    this.bgOpacity = 255;
    this.bgColorIdx = 7;
    this.alignmentIdx = 0;
    this.angleIdx = 0;
    this.statusMsg = '';
  }

  private onOk(): void {
    if (this.textContent.length === 0) {
      this.statusMsg = getAppString('msg_enter_text_content');
      return;
    }
    const args: AddTextArgs = {
      text: this.textContent,
      fontFamily: FONT_FAMILIES[this.fontFamilyIdx],
      fontSize: FONT_SIZES[this.fontSizeIdx],
      bold: this.isBold,
      italic: this.isItalic,
      textColor: this.COLORS[this.textColorIdx],
      bgFrame: this.bgFrameIdx,
      bgOpacity: this.bgOpacity,
      bgColor: this.COLORS[this.bgColorIdx],
      alignment: this.alignmentIdx,
      angle: this.angleIdx
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('addText', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'addText queued: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addText failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_text_options'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Text content
              Text(getAppString('dlg_text_content'))
                .fontSize(13)
                .fontColor('#555555')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 4 })
              TextArea({ text: this.textContent })
                .width('100%')
                .height(80)
                .fontSize(14)
                .fontColor(Theme.TEXT)
                .border({ width: 1, color: '#D0D0D0' })
                .onChange((value: string) => { this.textContent = value; })

              // Font row
              Row() {
                Text(getAppString('dlg_font'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Column() {
                  ForEach(FONT_FAMILIES, (fam: string, idx: number) => {
                    Text(fam)
                      .fontSize(12)
                      .fontColor(idx === this.fontFamilyIdx ? '#0078D7' : '#666666')
                      .fontWeight(idx === this.fontFamilyIdx ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 3, bottom: 3, left: 6 })
                      .width('100%')
                      .onClick(() => { this.fontFamilyIdx = idx; })
                  }, (fam: string, idx: number) => fam + ':' + idx)
                }
                .layoutWeight(1)
                .height(60)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ top: 10 })

              // Font size + bold/italic
              Row() {
                Text(getAppString('dlg_font_size'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Column() {
                  ForEach(FONT_SIZES, (sz: number, idx: number) => {
                    Text(sz.toString())
                      .fontSize(12)
                      .fontColor(idx === this.fontSizeIdx ? '#0078D7' : '#666666')
                      .fontWeight(idx === this.fontSizeIdx ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 2, bottom: 2, left: 6 })
                      .width('100%')
                      .onClick(() => { this.fontSizeIdx = idx; })
                  }, (sz: number, idx: number) => sz.toString() + ':' + idx)
                }
                .layoutWeight(1)
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })

                Column() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.isBold })
                    .width(20).height(20)
                    .onChange((val: boolean) => { this.isBold = val; })
                  Text('B')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#555555')
                    .margin({ top: 2 })
                }
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Center)

                Column() {
                  Toggle({ type: ToggleType.Checkbox, isOn: this.isItalic })
                    .width(20).height(20)
                    .onChange((val: boolean) => { this.isItalic = val; })
                  Text('I')
                    .fontSize(14)
                    .fontStyle(FontStyle.Italic)
                    .fontColor('#555555')
                    .margin({ top: 2 })
                }
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

              // Text color
              Row() {
                Text(getAppString('dlg_text_color'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.COLORS, (c: string, idx: number) => {
                    Row()
                      .width(24).height(24)
                      .backgroundColor(c)
                      .border({
                        width: idx === this.textColorIdx ? 2 : 1,
                        color: idx === this.textColorIdx ? '#0078D7' : '#D0D0D0'
                      })
                      .margin(2)
                      .onClick(() => { this.textColorIdx = idx; })
                  }, (c: string, idx: number) => c + ':' + idx)
                }
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

              // Frame / background
              Row() {
                Text(getAppString('dlg_frame'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Column() {
                  ForEach([getAppString('dlg_frame_none'), getAppString('dlg_frame_rect'),
                    getAppString('dlg_frame_shadow')], (label: string, idx: number) => {
                    Text(label)
                      .fontSize(12)
                      .fontColor(idx === this.bgFrameIdx ? '#0078D7' : '#666666')
                      .fontWeight(idx === this.bgFrameIdx ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 2, bottom: 2, left: 6 })
                      .width('100%')
                      .onClick(() => { this.bgFrameIdx = idx; })
                  }, (label: string, idx: number) => label + ':' + idx)
                }
                .layoutWeight(1)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

              // Opacity
              Row() {
                Text(getAppString('dlg_opacity'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Slider({
                  value: this.bgOpacity,
                  min: 0,
                  max: 255,
                  step: 5,
                  style: SliderStyle.InSet
                })
                  .layoutWeight(1)
                  .onChange((value: number) => { this.bgOpacity = value; })
                Text(this.bgOpacity.toString())
                  .fontSize(12)
                  .fontColor('#555555')
                  .width(40)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Center)

              // Background color
              Row() {
                Text(getAppString('dlg_bg_color'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.COLORS, (c: string, idx: number) => {
                    Row()
                      .width(24).height(24)
                      .backgroundColor(c)
                      .border({
                        width: idx === this.bgColorIdx ? 2 : 1,
                        color: idx === this.bgColorIdx ? '#0078D7' : '#D0D0D0'
                      })
                      .margin(2)
                      .onClick(() => { this.bgColorIdx = idx; })
                  }, (c: string, idx: number) => c + ':' + idx)
                }
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

              // Alignment
              Row() {
                Text(getAppString('dlg_alignment'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Column() {
                  ForEach([getAppString('dlg_align_center'), getAppString('dlg_align_left'),
                    getAppString('dlg_align_right')], (label: string, idx: number) => {
                    Text(label)
                      .fontSize(12)
                      .fontColor(idx === this.alignmentIdx ? '#0078D7' : '#666666')
                      .fontWeight(idx === this.alignmentIdx ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 2, bottom: 2, left: 6 })
                      .width('100%')
                      .onClick(() => { this.alignmentIdx = idx; })
                  }, (label: string, idx: number) => label + ':' + idx)
                }
                .layoutWeight(1)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

              // Angle
              Row() {
                Text(getAppString('dlg_angle'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                Column() {
                  ForEach([0, 45, 90, 135, 180, 225, 270, 315], (deg: number, idx: number) => {
                    Text(deg.toString())
                      .fontSize(12)
                      .fontColor(idx === this.angleIdx ? '#0078D7' : '#666666')
                      .fontWeight(idx === this.angleIdx ? FontWeight.Bold : FontWeight.Normal)
                      .padding({ top: 2, bottom: 2, left: 6 })
                      .width('100%')
                      .onClick(() => { this.angleIdx = idx; })
                  }, (deg: number, idx: number) => deg.toString() + ':' + idx)
                }
                .layoutWeight(1)
                .height(80)
                .border({ width: 1, color: '#D0D0D0' })
              }
              .width('100%')
              .margin({ top: 10 })
              .alignItems(VerticalAlign.Top)

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
        .width(400)
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
