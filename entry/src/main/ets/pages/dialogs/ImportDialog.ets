// OHPlot Import Dialog
// Dialog for importing CSV/ASCII data files.
// DocumentViewPicker copies the picked file into the app sandbox (Qt cannot
// read content URIs) and triggers the queued importASCII backend command;
// completion arrives as a message event (toast).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { getAppString } from '../../components/LocaleHelper';
import {
  ACCENT, TEXT, TEXT_MUTED, TEXT_LIST, TEXT_HINT, TEXT_EMPTY,
  BTN_BG, BTN_BG_ACCENT, BTN_TEXT, BTN_TEXT_ACCENT,
  RADIUS_4, RADIUS_8, BTN_HEIGHT, BTN_GAP,
  FS_DIALOG_TITLE, FS_DIALOG_LABEL, FS_DIALOG_BODY, FS_DIALOG_SMALL, FS_DIALOG_HINT,
  SPACING_4, SPACING_6, SPACING_8, SPACING_12, SPACING_16,
  INPUT_HEIGHT, BACKDROP_COLOR, SHADOW_RADIUS, SHADOW_COLOR,
  SHADOW_OFFSET_X, SHADOW_OFFSET_Y
} from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

// importASCII command payload (mirrors scidavis/src/main.cpp).
interface ImportAsciiArgs {
  filePath: string;
  importMode: number;
  separator: string;
  ignoredLines: number;
  convertToNumeric: boolean;
  renameColumns: boolean;
  stripSpaces: boolean;
}

@Component
export struct ImportDialog {
  @Link isVisible: boolean;
  @State separator: string = '\t';
  @State importMode: number = 0; // 0=NewTables, 1=NewRows, 2=OverwriteCurrent
  @State ignoredLines: string = '0';
  @State convertToNumeric: boolean = true;
  @State renameColumns: boolean = true;
  @State stripSpaces: boolean = true;
  @State statusMsg: string = '';

  private separators: string[] = ['Tab', 'Comma', 'Semicolon', 'Space', 'Custom'];
  private separatorValues: string[] = ['\t', ',', ';', ' ', '|'];
  private selSepIdx: number = 0;

  async onImport(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const uris: string[] = await docPicker.select(opts);
      if (uris.length === 0) {
        return; // user cancelled
      }
      const uri: string = uris[0];
      let name: string = decodeURIComponent(uri.substring(uri.lastIndexOf('/') + 1));
      if (name === '') {
        name = 'import.txt';
      }
      const ctx = getContext(this) as common.UIAbilityContext;
      const dest: string = ctx.filesDir + '/' + name;
      const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.copyFileSync(src.fd, dest);
      fs.closeSync(src);
      const injector = qohos as QohosInjector;
      const args: string = JSON.stringify({
        filePath: dest,
        importMode: this.importMode,
        separator: this.separator,
        ignoredLines: parseInt(this.ignoredLines) || 0,
        convertToNumeric: this.convertToNumeric,
        renameColumns: this.renameColumns,
        stripSpaces: this.stripSpaces
      } as ImportAsciiArgs);
      const result: string = injector.callQtCommand('importASCII', args);
      hilog.info(DOMAIN, TAG, 'importASCII(%{public}s) queued: %{public}s', dest, result);
      this.isVisible = false; // toast arrives via the event channel
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'ImportDialog picker failed: %{public}s', (e as Error).message);
      this.statusMsg = getAppString('msg_import_failed') + (e as Error).message;
    }
  }

  onSepSelect(index: number): void {
    this.selSepIdx = index;
    this.separator = this.separatorValues[index];
  }

  build() {
    if (this.isVisible) {
      Stack() {
        // Modal backdrop
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(BACKDROP_COLOR)
          .onClick(() => {
            this.isVisible = false;
          })

        // Dialog box
        Column() {
          // Title
          Text($r('app.string.dlg_import_title'))
            .fontSize(FS_DIALOG_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT)
            .margin({ top: SPACING_16, bottom: SPACING_12 })

          Scroll() {
            Column() {
              // Separator selection
              Row() {
                Text($r('app.string.dlg_separator'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(100)
                ForEach(this.separators, (label: string, idx: number) => {
                  Text(label)
                    .fontSize(FS_DIALOG_SMALL)
                    .fontColor(idx === this.selSepIdx ? ACCENT : TEXT_LIST)
                    .fontWeight(idx === this.selSepIdx ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: SPACING_6, right: SPACING_6 })
                    .onClick(() => this.onSepSelect(idx))
                }, (label: string) => label)
              }
              .width('100%')
              .margin({ bottom: SPACING_8 })

              // Import mode
              Row() {
                Text($r('app.string.dlg_import_mode'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(100)
                Text($r('app.string.dlg_import_new_tables'))
                  .fontSize(FS_DIALOG_SMALL)
                  .fontColor(this.importMode === 0 ? ACCENT : TEXT_LIST)
                  .fontWeight(this.importMode === 0 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: SPACING_6, right: SPACING_6 })
                  .onClick(() => { this.importMode = 0; })
                Text($r('app.string.dlg_import_new_rows'))
                  .fontSize(FS_DIALOG_SMALL)
                  .fontColor(this.importMode === 1 ? ACCENT : TEXT_LIST)
                  .fontWeight(this.importMode === 1 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: SPACING_6, right: SPACING_6 })
                  .onClick(() => { this.importMode = 1; })
                Text($r('app.string.dlg_import_overwrite'))
                  .fontSize(FS_DIALOG_SMALL)
                  .fontColor(this.importMode === 2 ? ACCENT : TEXT_LIST)
                  .fontWeight(this.importMode === 2 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: SPACING_6, right: SPACING_6 })
                  .onClick(() => { this.importMode = 2; })
              }
              .width('100%')
              .margin({ bottom: SPACING_8 })

              // Options
              Row() {
                Text($r('app.string.dlg_import_ignored_lines'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(100)
                TextInput({ text: this.ignoredLines, placeholder: '0' })
                  .width(60)
                  .height(INPUT_HEIGHT)
                  .fontSize(FS_DIALOG_SMALL)
                  .onChange((val: string) => { this.ignoredLines = val; })
              }
              .width('100%')
              .margin({ bottom: SPACING_8 })

              Row() {
                Text($r('app.string.dlg_import_convert_numeric'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.convertToNumeric })
                  .onChange((val: boolean) => { this.convertToNumeric = val; })
              }
              .width('100%')
              .margin({ bottom: SPACING_6 })

              Row() {
                Text($r('app.string.dlg_import_rename_columns'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.renameColumns })
                  .onChange((val: boolean) => { this.renameColumns = val; })
              }
              .width('100%')
              .margin({ bottom: SPACING_6 })

              Row() {
                Text($r('app.string.dlg_import_strip_spaces'))
                  .fontSize(FS_DIALOG_BODY)
                  .fontColor(TEXT_MUTED)
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.stripSpaces })
                  .onChange((val: boolean) => { this.stripSpaces = val; })
              }
              .width('100%')
              .margin({ bottom: SPACING_6 })

              // Status message
              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(FS_DIALOG_HINT)
                  .fontColor(TEXT_HINT)
                  .margin({ top: SPACING_8, bottom: SPACING_4 })
              }
            }
            .padding({ left: SPACING_16, right: SPACING_16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Buttons
          Row() {
            Button($r('app.string.common_cancel'))
              .fontSize(FS_DIALOG_LABEL)
              .height(BTN_HEIGHT)
              .backgroundColor(BTN_BG)
              .fontColor(BTN_TEXT)
              .borderRadius(RADIUS_4)
              .onClick(() => {
                this.isVisible = false;
              })
            Button($r('app.string.dlg_import_action'))
              .fontSize(FS_DIALOG_LABEL)
              .height(BTN_HEIGHT)
              .backgroundColor(BTN_BG_ACCENT)
              .fontColor(BTN_TEXT_ACCENT)
              .borderRadius(RADIUS_4)
              .margin({ left: BTN_GAP })
              .onClick(() => {
                this.onImport();
              })
          }
          .width('100%')
          .padding({ left: SPACING_16, right: SPACING_16, bottom: SPACING_16 })
          .justifyContent(FlexAlign.End)
        }
        .width(380)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(RADIUS_8)
        .shadow({ radius: SHADOW_RADIUS, color: SHADOW_COLOR, offsetX: SHADOW_OFFSET_X, offsetY: SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }

  show(): void {
    this.isVisible = true;
  }

  close(): void {
    this.isVisible = false;
  }
}
