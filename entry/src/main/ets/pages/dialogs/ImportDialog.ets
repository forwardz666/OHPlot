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
      this.statusMsg = 'Import failed: ' + (e as Error).message;
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
          .backgroundColor('#80000000')
          .onClick(() => {
            this.isVisible = false;
          })

        // Dialog box
        Column() {
          // Title
          Text('Import ASCII Data')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          Scroll() {
            Column() {
              // Separator selection
              Row() {
                Text('Separator:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(100)
                ForEach(this.separators, (label: string, idx: number) => {
                  Text(label)
                    .fontSize(12)
                    .fontColor(idx === this.selSepIdx ? '#0078D7' : '#666666')
                    .fontWeight(idx === this.selSepIdx ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 6, right: 6 })
                    .onClick(() => this.onSepSelect(idx))
                }, (label: string) => label)
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Import mode
              Row() {
                Text('Import Mode:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(100)
                Text('New Tables')
                  .fontSize(12)
                  .fontColor(this.importMode === 0 ? '#0078D7' : '#666666')
                  .fontWeight(this.importMode === 0 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 6, right: 6 })
                  .onClick(() => { this.importMode = 0; })
                Text('New Rows')
                  .fontSize(12)
                  .fontColor(this.importMode === 1 ? '#0078D7' : '#666666')
                  .fontWeight(this.importMode === 1 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 6, right: 6 })
                  .onClick(() => { this.importMode = 1; })
                Text('Overwrite')
                  .fontSize(12)
                  .fontColor(this.importMode === 2 ? '#0078D7' : '#666666')
                  .fontWeight(this.importMode === 2 ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 6, right: 6 })
                  .onClick(() => { this.importMode = 2; })
              }
              .width('100%')
              .margin({ bottom: 8 })

              // Options
              Row() {
                Text('Ignored lines:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(100)
                TextInput({ text: this.ignoredLines, placeholder: '0' })
                  .width(60)
                  .height(28)
                  .fontSize(12)
                  .onChange((val: string) => { this.ignoredLines = val; })
              }
              .width('100%')
              .margin({ bottom: 8 })

              Row() {
                Text('Convert to numeric:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.convertToNumeric })
                  .onChange((val: boolean) => { this.convertToNumeric = val; })
              }
              .width('100%')
              .margin({ bottom: 6 })

              Row() {
                Text('Rename columns:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.renameColumns })
                  .onChange((val: boolean) => { this.renameColumns = val; })
              }
              .width('100%')
              .margin({ bottom: 6 })

              Row() {
                Text('Strip spaces:')
                  .fontSize(13)
                  .fontColor('#555555')
                  .width(140)
                Toggle({ type: ToggleType.Switch, isOn: this.stripSpaces })
                  .onChange((val: boolean) => { this.stripSpaces = val; })
              }
              .width('100%')
              .margin({ bottom: 6 })

              // Status message
              if (this.statusMsg) {
                Text(this.statusMsg)
                  .fontSize(11)
                  .fontColor('#888888')
                  .margin({ top: 8, bottom: 4 })
              }
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Buttons
          Row() {
            Button('Cancel')
              .fontSize(14)
              .height(32)
              .backgroundColor('#E0E0E0')
              .fontColor('#333333')
              .borderRadius(4)
              .onClick(() => {
                this.isVisible = false;
              })
            Button('Import...')
              .fontSize(14)
              .height(32)
              .backgroundColor('#0078D7')
              .fontColor('#FFFFFF')
              .borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => {
                this.onImport();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(380)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
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
