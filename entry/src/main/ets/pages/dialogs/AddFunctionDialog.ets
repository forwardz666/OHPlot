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
          .backgroundColor('#80000000')
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('graph_add_function'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              Row() {
                Text('Type:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                Row() {
                  Text('y=f(x)')
                    .fontSize(12)
                    .fontColor(this.typeIdx === 0 ? '#0078D7' : '#666666')
                    .fontWeight(this.typeIdx === 0 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.typeIdx = 0; })
                  Text('Parametric')
                    .fontSize(12)
                    .fontColor(this.typeIdx === 1 ? '#0078D7' : '#666666')
                    .fontWeight(this.typeIdx === 1 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.typeIdx = 1; })
                  Text('Polar')
                    .fontSize(12)
                    .fontColor(this.typeIdx === 2 ? '#0078D7' : '#666666')
                    .fontWeight(this.typeIdx === 2 ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 12, top: 3, bottom: 3 })
                    .onClick(() => { this.typeIdx = 2; })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .margin({ bottom: 12 })

              if (this.typeIdx === 0) {
                Text('Formula (y=f(x)):')
                  .fontSize(13)
                  .fontColor('#555555')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                TextArea({ text: this.formula1 })
                  .fontSize(13)
                  .height(64)
                  .width('100%')
                  .onChange((v: string) => { this.formula1 = v; })
                  .margin({ bottom: 12 })
              } else {
                Text(this.typeIdx === 1 ? 'Formula x(t):' : 'Formula r(t):')
                  .fontSize(13)
                  .fontColor('#555555')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                TextArea({ text: this.formula1 })
                  .fontSize(13)
                  .height(56)
                  .width('100%')
                  .onChange((v: string) => { this.formula1 = v; })
                  .margin({ bottom: 8 })
                Text(this.typeIdx === 1 ? 'Formula y(t):' : 'Formula t:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 4 })
                TextArea({ text: this.formula2 })
                  .fontSize(13)
                  .height(56)
                  .width('100%')
                  .onChange((v: string) => { this.formula2 = v; })
                  .margin({ bottom: 12 })
              }

              Row() {
                Text('Variable:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                TextInput({ text: this.varText })
                  .fontSize(13)
                  .layoutWeight(1)
                  .height(30)
                  .onChange((v: string) => { this.varText = v; })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text('From:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                TextInput({ text: this.fromText })
                  .fontSize(13)
                  .layoutWeight(1)
                  .height(30)
                  .onChange((v: string) => { this.fromText = v; })
                Text('To:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(50)
                  .margin({ left: 10 })
                TextInput({ text: this.toText })
                  .fontSize(13)
                  .layoutWeight(1)
                  .height(30)
                  .onChange((v: string) => { this.toText = v; })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Row() {
                Text(getAppString('dlg_points'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(80)
                TextInput({ text: this.pointsText })
                  .fontSize(13)
                  .type(InputType.Number)
                  .layoutWeight(1)
                  .height(30)
                  .onChange((v: string) => { this.pointsText = v; })
              }
              .width('100%')
              .margin({ bottom: 8 })

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
            Button(getAppString('graph_add_function'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onAdd(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(400)
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
