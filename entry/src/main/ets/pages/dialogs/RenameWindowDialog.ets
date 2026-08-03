// RenameWindowDialog — "Windows > Rename Window" dialog (batch 3).
// Radio group (rename by name / label / both) + name text input +
// label multi-line edit + OK/Cancel. Dispatches renameWindow.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface RenameWindowArgs {
  windowName: string;
  newName: string;
  newLabel: string;
  captionPolicy: number;
}

@Component
export struct RenameWindowDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State windowName: string = '';
  @State currentLabel: string = '';
  @State policyIdx: number = 0; // 0=Name, 1=Label, 2=Both
  @State newName: string = '';
  @State newLabel: string = '';
  @State statusMsg: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  private loadData(): void {
    this.statusMsg = '';
    // Fetch current active window info
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getActiveWindowInfo', '{}');
      const parsed = JSON.parse(result) as ActiveWindowInfoResponse;
      if (parsed.success && parsed.data) {
        this.windowName = parsed.data.name;
        this.currentLabel = parsed.data.label;
        this.policyIdx = parsed.data.captionPolicy;
        this.newName = parsed.data.name;
        this.newLabel = parsed.data.label;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'RenameWindowDialog getActiveWindowInfo failed: %{public}s',
        (e as Error).message);
      this.newName = '';
      this.newLabel = '';
    }
  }

  private onOk(): void {
    // Clean name: remove whitespace and equals
    const cleanName: string = this.newName.replace(new RegExp('\\s', 'g'), '').replace('=', '');
    if (cleanName.length === 0 && this.policyIdx !== 1) {
      this.statusMsg = getAppString('msg_enter_window_name');
      return;
    }
    const args: RenameWindowArgs = {
      windowName: this.windowName,
      newName: cleanName.replace('_', '-'),
      newLabel: this.newLabel.replace('\n', ' ').replace('\t', ' '),
      captionPolicy: this.policyIdx
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('renameWindow', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'renameWindow queued: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'renameWindow failed: %{public}s', (e as Error).message);
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

        Row() {
          // Left: Window Title group
          Column() {
            Text(getAppString('dlg_window_title'))
              .fontSize(14)
              .fontColor('#333333')
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })

            // Name radio + input
            Row() {
              Radio({ value: 'name', group: 'captionPolicy' })
                .checked(this.policyIdx === 0)
                .onChange((isChecked: boolean) => {
                  if (isChecked) { this.policyIdx = 0; }
                })
              Text(getAppString('dlg_rename_name'))
                .fontSize(13)
                .fontColor('#555555')
                .margin({ left: 6 })
            }
            .width('100%')
            .margin({ bottom: 4 })
            TextInput({ text: this.newName })
              .width('100%')
              .fontSize(14)
              .fontColor(Theme.TEXT)
              .margin({ left: 30, bottom: 8 })
              .onChange((value: string) => { this.newName = value; })

            // Label radio + edit
            Row() {
              Radio({ value: 'label', group: 'captionPolicy' })
                .checked(this.policyIdx === 1)
                .onChange((isChecked: boolean) => {
                  if (isChecked) { this.policyIdx = 1; }
                })
              Text(getAppString('dlg_rename_label'))
                .fontSize(13)
                .fontColor('#555555')
                .margin({ left: 6 })
            }
            .width('100%')
            .margin({ bottom: 4 })
            TextArea({ text: this.newLabel })
              .width('100%')
              .height(80)
              .fontSize(14)
              .fontColor(Theme.TEXT)
              .margin({ left: 30, bottom: 8 })
              .onChange((value: string) => { this.newLabel = value; })

            // Both radio
            Row() {
              Radio({ value: 'both', group: 'captionPolicy' })
                .checked(this.policyIdx === 2)
                .onChange((isChecked: boolean) => {
                  if (isChecked) { this.policyIdx = 2; }
                })
              Text(getAppString('dlg_rename_both'))
                .fontSize(13)
                .fontColor('#555555')
                .margin({ left: 6 })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .padding(12)
          .backgroundColor('#F8F8F8')
          .borderRadius(4)

          // Right: OK / Cancel
          Column() {
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .width(80)
              .onClick(() => { this.onOk(); })
            Button(getAppString('common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .width(80)
              .margin({ top: 12 })
              .onClick(() => { this.isVisible = false; })
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Center)
        }
        .width(420)
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .height('100%')
    }
  }
}

interface ActiveWindowInfo {
  name: string;
  label: string;
  captionPolicy: number;
}

interface ActiveWindowInfoResponse {
  success: boolean;
  data?: ActiveWindowInfo;
  error?: string;
}
