// AddFunctionDialog — "Graph > Add Function..." dialog (Phase 3b).
// Lets the user define a function curve (normal y=f(x), parametric or
// polar) with variable name, range and point count, then queues the
// add_function backend command
// (schema: { type?: 0|1|2, formulas: string[], var?: "x",
//            ranges: [start, end], points?: 1000 }).
// Result toast arrives via the event channel (QtEventHost).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import {
  ACCENT, TEXT, TEXT_MUTED, TEXT_LIST, TEXT_ERROR,
  BTN_BG, BTN_BG_ACCENT, BTN_TEXT, BTN_TEXT_ACCENT,
  RADIUS_4, RADIUS_8, BTN_HEIGHT, BTN_GAP,
  FS_DIALOG_TITLE, FS_DIALOG_LABEL, FS_DIALOG_BODY, FS_DIALOG_SMALL, FS_DIALOG_HINT,
  SPACING_4, SPACING_6, SPACING_8, SPACING_12, SPACING_16,
  INPUT_HEIGHT_TALL, BACKDROP_COLOR, SHADOW_RADIUS, SHADOW_COLOR,
  SHADOW_OFFSET_X, SHADOW_OFFSET_Y
} from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface AddFunctionArgs {
  type?: number;
  formulas: string[];
  var?: string;
  ranges: number[];
  points?: number;
}

@Component
export struct AddFunctionDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  // 0 = normal y=f(x), 1 = parametric, 2 = polar.
  @State typeIdx: number = 0;
  @State formula1: string = '';
  @State formula2: string = '';
  @State varText: string = 'x';
  @State fromText: string = '0';
  @State toText: string = '10';
  @State pointsText: string = '1000';
  @State statusMsg: string = '';

  aboutToAppear(): void {
    // MainLayout mounts this dialog conditionally, so the component is
    // created with isVisible already true and @Watch never fires.
    if (this.isVisible) {
      this.resetFields();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.resetFields();
    }
  }

  private resetFields(): void {
    this.typeIdx = 0;
    this.formula1 = '';
    this.formula2 = '';
    this.varText = 'x';
    this.fromText = '0';
    this.toText = '10';
    this.pointsText = '1000';
    this.statusMsg = '';
  }

  private onAdd(): void {
    const type: number = this.typeIdx;
    const formulas: string[] = type === 0 ? [this.formula1] : [this.formula1, this.formula2];
    for (let i = 0; i < formulas.length; i++) {
      if (formulas[i].trim().length === 0) {
        this.statusMsg = getAppString('msg_select_column');
        return;
      }
    }
    const from: number = Number(this.fromText);
    const to: number = Number(this.toText);
    if (!Number.isFinite(from) || !Number.isFinite(to) || to <= from) {
      this.statusMsg = getAppString('msg_select_column');
      return;
    }
    let points: number = Number(this.pointsText);
    if (!Number.isFinite(points) || points <= 0) {
      points = 1000;
    }
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('add_function',
        JSON.stringify({
          type: type,
          formulas: formulas,
          var: this.varText.trim().length > 0 ? this.varText.trim() : 'x',
          ranges: [from, to],
          points: points
        } as AddFunctionArgs));
      hilog.info(DOMAIN, TAG, 'add_function(type=%{public}d, formulas=%{public}s) queued: %{public}s',
        type, JSON.stringify(formulas), result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'add_function failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false; // result toast arrives via the event channel
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(BACKDROP_COLOR)
          .onClick(() => { this.isVisible = false; })

        Column() {
           Text(getAppString('graph_add_function'))
             .fontSize(FS_DIALOG_TITLE)
             .fontWeight(FontWeight.Bold)
             .fontColor(TEXT)
             .margin({ top: SPACING_16, bottom: SPACING_12 })

          Scroll() {
            Column() {
              Row() {
                 Text('Type:')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .width(80)
                 Row() {
                   Text('y=f(x)')
                     .fontSize(FS_DIALOG_SMALL)
                     .fontColor(this.typeIdx === 0 ? ACCENT : TEXT_LIST)
                     .fontWeight(this.typeIdx === 0 ? FontWeight.Bold : FontWeight.Normal)
                     .padding({ left: SPACING_6, right: SPACING_12, top: SPACING_4, bottom: SPACING_4 })
                     .onClick(() => { this.typeIdx = 0; })
                   Text('Parametric')
                     .fontSize(FS_DIALOG_SMALL)
                     .fontColor(this.typeIdx === 1 ? ACCENT : TEXT_LIST)
                     .fontWeight(this.typeIdx === 1 ? FontWeight.Bold : FontWeight.Normal)
                     .padding({ left: SPACING_6, right: SPACING_12, top: SPACING_4, bottom: SPACING_4 })
                     .onClick(() => { this.typeIdx = 1; })
                   Text('Polar')
                     .fontSize(FS_DIALOG_SMALL)
                     .fontColor(this.typeIdx === 2 ? ACCENT : TEXT_LIST)
                     .fontWeight(this.typeIdx === 2 ? FontWeight.Bold : FontWeight.Normal)
                     .padding({ left: SPACING_6, right: SPACING_12, top: SPACING_4, bottom: SPACING_4 })
                    .onClick(() => { this.typeIdx = 2; })
                }
                .layoutWeight(1)
              }
              .width('100%')
               .margin({ bottom: SPACING_12 })

               if (this.typeIdx === 0) {
                 Text('Formula (y=f(x)):')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .alignSelf(ItemAlign.Start)
                   .margin({ bottom: SPACING_4 })
                 TextArea({ text: this.formula1 })
                   .fontSize(FS_DIALOG_BODY)
                   .height(64)
                   .width('100%')
                   .onChange((v: string) => { this.formula1 = v; })
                   .margin({ bottom: SPACING_12 })
               } else {
                 Text(this.typeIdx === 1 ? 'Formula x(t):' : 'Formula r(t):')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .alignSelf(ItemAlign.Start)
                   .margin({ bottom: SPACING_4 })
                 TextArea({ text: this.formula1 })
                   .fontSize(FS_DIALOG_BODY)
                   .height(56)
                   .width('100%')
                   .onChange((v: string) => { this.formula1 = v; })
                   .margin({ bottom: SPACING_8 })
                 Text(this.typeIdx === 1 ? 'Formula y(t):' : 'Formula t:')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .alignSelf(ItemAlign.Start)
                   .margin({ bottom: SPACING_4 })
                 TextArea({ text: this.formula2 })
                   .fontSize(FS_DIALOG_BODY)
                  .height(56)
                  .width('100%')
                  .onChange((v: string) => { this.formula2 = v; })
                   .margin({ bottom: SPACING_12 })
               }

               Row() {
                 Text('Variable:')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .width(80)
                 TextInput({ text: this.varText })
                   .fontSize(FS_DIALOG_BODY)
                   .layoutWeight(1)
                   .height(INPUT_HEIGHT_TALL)
                  .onChange((v: string) => { this.varText = v; })
              }
              .width('100%')
               .margin({ bottom: SPACING_12 })

               Row() {
                 Text('From:')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .width(80)
                 TextInput({ text: this.fromText })
                   .fontSize(FS_DIALOG_BODY)
                   .layoutWeight(1)
                   .height(INPUT_HEIGHT_TALL)
                   .onChange((v: string) => { this.fromText = v; })
                 Text('To:')
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .width(50)
                   .margin({ left: 10 })
                  TextInput({ text: this.toText })
                    .fontSize(FS_DIALOG_BODY)
                   .layoutWeight(1)
                   .height(INPUT_HEIGHT_TALL)
                   .onChange((v: string) => { this.toText = v; })
               }
               .width('100%')
               .margin({ bottom: SPACING_12 })

               Row() {
                 Text(getAppString('dlg_points'))
                   .fontSize(FS_DIALOG_BODY)
                   .fontColor(TEXT_MUTED)
                   .width(80)
                 TextInput({ text: this.pointsText })
                   .fontSize(FS_DIALOG_BODY)
                   .type(InputType.Number)
                   .layoutWeight(1)
                   .height(INPUT_HEIGHT_TALL)
                  .onChange((v: string) => { this.pointsText = v; })
              }
              .width('100%')
              .margin({ bottom: SPACING_8 })

              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(FS_DIALOG_HINT)
                  .fontColor(TEXT_ERROR)
                  .margin({ top: SPACING_8 })
              }
            }
            .padding({ left: SPACING_16, right: SPACING_16 })
          }
          .layoutWeight(1)
          .width('100%')

           Row() {
             Button(getAppString('common_cancel'))
               .fontSize(FS_DIALOG_LABEL).height(BTN_HEIGHT)
               .backgroundColor(BTN_BG).fontColor(BTN_TEXT).borderRadius(RADIUS_4)
               .onClick(() => { this.isVisible = false; })
             Button(getAppString('graph_add_function'))
               .fontSize(FS_DIALOG_LABEL).height(BTN_HEIGHT)
               .backgroundColor(BTN_BG_ACCENT).fontColor(BTN_TEXT_ACCENT).borderRadius(RADIUS_4)
               .margin({ left: BTN_GAP })
              .onClick(() => { this.onAdd(); })
          }
          .width('100%')
           .padding({ left: SPACING_16, right: SPACING_16, bottom: SPACING_16 })
          .justifyContent(FlexAlign.End)
        }
        .width(400)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
         .borderRadius(RADIUS_8)
         .shadow({ radius: SHADOW_RADIUS, color: SHADOW_COLOR, offsetX: SHADOW_OFFSET_X, offsetY: SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }
}
