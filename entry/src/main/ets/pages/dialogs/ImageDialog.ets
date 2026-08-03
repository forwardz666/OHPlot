// ImageDialog — "Graph > Add Image" dialog (batch 2).
// Image geometry: origin X/Y, width/height, keep aspect ratio.
// On OK dispatches addImage with filePath param.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface AddImageArgs {
  filePath: string;
  originX: number;
  originY: number;
  width: number;
  height: number;
  keepAspect: boolean;
}

@Component
export struct ImageDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State originX: string = '0';
  @State originY: string = '0';
  @State imgWidth: string = '200';
  @State imgHeight: string = '200';
  @State keepAspect: boolean = true;
  @State filePath: string = '';
  @State imgAspectRatio: number = 1.0;
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
    this.originX = '0';
    this.originY = '0';
    this.imgWidth = '200';
    this.imgHeight = '200';
    this.keepAspect = true;
    this.filePath = '';
    this.imgAspectRatio = 1.0;
    this.statusMsg = '';
  }

  private onOk(): void {
    if (this.filePath.length === 0) {
      this.statusMsg = getAppString('msg_select_image_file');
      return;
    }
    const args: AddImageArgs = {
      filePath: this.filePath,
      originX: parseInt(this.originX) || 0,
      originY: parseInt(this.originY) || 0,
      width: parseInt(this.imgWidth) || 200,
      height: parseInt(this.imgHeight) || 200,
      keepAspect: this.keepAspect
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('addImage', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'addImage queued: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addImage failed: %{public}s', (e as Error).message);
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
          Text(getAppString('dlg_image_geometry'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          Column() {
            // File path
            Text(getAppString('dlg_image_file'))
              .fontSize(13)
              .fontColor('#555555')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 4 })
            Row() {
              TextInput({ text: this.filePath, placeholder: getAppString('dlg_image_path_ph') })
                .layoutWeight(1)
                .fontSize(14)
                .fontColor(Theme.TEXT)
                .onChange((value: string) => { this.filePath = value; })
            }
            .width('100%')

            // Origin group
            Column() {
              Text(getAppString('dlg_origin'))
                .fontSize(13)
                .fontColor('#555555')
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 6 })
              Row() {
                Text('X=')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(30)
                TextInput({ text: this.originX })
                  .type(InputType.Number)
                  .layoutWeight(1)
                  .fontSize(14)
                  .onChange((value: string) => { this.originX = value; })
                Text(' pixels')
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .margin({ top: 4 })
              Row() {
                Text('Y=')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(30)
                TextInput({ text: this.originY })
                  .type(InputType.Number)
                  .layoutWeight(1)
                  .fontSize(14)
                  .onChange((value: string) => { this.originY = value; })
                Text(' pixels')
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .width('100%')
            .margin({ top: 12 })
            .padding(8)
            .backgroundColor('#F8F8F8')
            .borderRadius(4)

            // Size group
            Column() {
              Text(getAppString('dlg_size'))
                .fontSize(13)
                .fontColor('#555555')
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 6 })
              Row() {
                Text(getAppString('dlg_img_width'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                TextInput({ text: this.imgWidth })
                  .type(InputType.Number)
                  .layoutWeight(1)
                  .fontSize(14)
                  .onChange((value: string) => {
                    this.imgWidth = value;
                    if (this.keepAspect) {
                      const w: number = parseInt(value) || 0;
                      if (w > 0 && this.imgAspectRatio > 0) {
                        this.imgHeight = Math.round(w / this.imgAspectRatio).toString();
                      }
                    }
                  })
                Text(' pixels')
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .margin({ top: 4 })
              Row() {
                Text(getAppString('dlg_img_height'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(60)
                TextInput({ text: this.imgHeight })
                  .type(InputType.Number)
                  .layoutWeight(1)
                  .fontSize(14)
                  .onChange((value: string) => {
                    this.imgHeight = value;
                    if (this.keepAspect) {
                      const h: number = parseInt(value) || 0;
                      if (h > 0 && this.imgAspectRatio > 0) {
                        this.imgWidth = Math.round(h * this.imgAspectRatio).toString();
                      }
                    }
                  })
                Text(' pixels')
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .margin({ top: 4 })

              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.keepAspect })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.keepAspect = val; })
                Text(getAppString('dlg_keep_aspect'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ top: 6 })
            }
            .width('100%')
            .margin({ top: 12 })
            .padding(8)
            .backgroundColor('#F8F8F8')
            .borderRadius(4)
          }
          .padding({ left: 16, right: 16 })

          if (this.statusMsg) {
            Text(this.statusMsg)
              .fontSize(11)
              .fontColor('#CC3333')
              .margin({ top: 8 })
          }

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
          .padding({ left: 16, right: 16, bottom: 16, top: 8 })
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
