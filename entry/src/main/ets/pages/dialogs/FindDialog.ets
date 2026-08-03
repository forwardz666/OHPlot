// FindDialog — "Edit > Find" dialog (batch 3).
// Search box + scope options (window name/label/folder checkboxes) +
// find options (case sensitive, partial match, subfolders) +
// Find / Update Start Path / Close buttons.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface FindArgs {
  text: string;
  searchWindowNames: boolean;
  searchWindowLabels: boolean;
  searchFolderNames: boolean;
  caseSensitive: boolean;
  partialMatch: boolean;
  includeSubfolders: boolean;
}

interface StartPathResponse {
  success: boolean;
  path?: string;
  error?: string;
}

@Component
export struct FindDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State findText: string = '';
  @State startPath: string = '/';
  @State searchWindowNames: boolean = true;
  @State searchWindowLabels: boolean = false;
  @State searchFolderNames: boolean = false;
  @State caseSensitive: boolean = false;
  @State partialMatch: boolean = true;
  @State includeSubfolders: boolean = true;
  @State recentSearches: string[] = [];
  @State statusMsg: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadStartPath();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadStartPath();
    }
  }

  private loadStartPath(): void {
    this.findText = '';
    this.statusMsg = '';
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getStartPath', '{}');
      const parsed = JSON.parse(result) as StartPathResponse;
      if (parsed.success && parsed.path) {
        this.startPath = parsed.path;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'FindDialog getStartPath failed: %{public}s',
        (e as Error).message);
    }
  }

  private onFind(): void {
    if (this.findText.length === 0) {
      this.statusMsg = getAppString('msg_enter_search_text');
      return;
    }
    const args: FindArgs = {
      text: this.findText,
      searchWindowNames: this.searchWindowNames,
      searchWindowLabels: this.searchWindowLabels,
      searchFolderNames: this.searchFolderNames,
      caseSensitive: this.caseSensitive,
      partialMatch: this.partialMatch,
      includeSubfolders: this.includeSubfolders
    };
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('find', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'find queued: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'find failed: %{public}s', (e as Error).message);
    }
    // Add to recent searches (deduplicated, max 10)
    const updated: string[] = [];
    updated.push(this.findText);
    for (let i = 0; i < this.recentSearches.length && updated.length < 10; i++) {
      if (this.recentSearches[i] !== this.findText) {
        updated.push(this.recentSearches[i]);
      }
    }
    this.recentSearches = updated;
  }

  private onUpdateStartPath(): void {
    this.loadStartPath();
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
          Text(getAppString('dlg_find_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          Column() {
            // Start from
            Row() {
              Text(getAppString('dlg_start_from'))
                .fontSize(13)
                .fontColor('#555555')
                .width(80)
              Text(this.startPath)
                .fontSize(13)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
                .padding({ left: 6, top: 4, bottom: 4 })
                .backgroundColor('#F0F0F0')
                .borderRadius(4)
            }
            .width('100%')
            .margin({ bottom: 8 })

            // Find input
            Row() {
              Text(getAppString('dlg_find'))
                .fontSize(13)
                .fontColor('#555555')
                .width(80)
              TextInput({ text: this.findText, placeholder: getAppString('dlg_find_ph') })
                .layoutWeight(1)
                .fontSize(14)
                .fontColor(Theme.TEXT)
                .onChange((value: string) => { this.findText = value; })
            }
            .width('100%')
            .margin({ bottom: 12 })

            // Search in group
            Column() {
              Text(getAppString('dlg_search_in'))
                .fontSize(14)
                .fontColor('#333333')
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 6 })
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.searchWindowNames })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.searchWindowNames = val; })
                Text(getAppString('dlg_search_window_names'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.searchWindowLabels })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.searchWindowLabels = val; })
                Text(getAppString('dlg_search_window_labels'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ top: 4 })
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.searchFolderNames })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.searchFolderNames = val; })
                Text(getAppString('dlg_search_folder_names'))
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

            // Find options
            Column() {
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.caseSensitive })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.caseSensitive = val; })
                Text(getAppString('dlg_case_sensitive'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.partialMatch })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.partialMatch = val; })
                Text(getAppString('dlg_partial_match'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ top: 4 })
              Row() {
                Toggle({ type: ToggleType.Checkbox, isOn: this.includeSubfolders })
                  .width(20).height(20)
                  .onChange((val: boolean) => { this.includeSubfolders = val; })
                Text(getAppString('dlg_include_subfolders'))
                  .fontSize(13)
                  .fontColor('#555555')
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .width('100%')
            .margin({ top: 12 })
            .padding(8)
            .backgroundColor('#F8F8F8')
            .borderRadius(4)

            // Recent searches
            if (this.recentSearches.length > 0) {
              Text(getAppString('dlg_recent_searches'))
                .fontSize(13)
                .fontColor('#555555')
                .margin({ top: 8, bottom: 4 })
                .alignSelf(ItemAlign.Start)
              Scroll() {
                Column() {
                  ForEach(this.recentSearches, (s: string, idx: number) => {
                    Text(s)
                      .fontSize(12)
                      .fontColor('#0078D7')
                      .padding({ top: 2, bottom: 2, left: 6 })
                      .width('100%')
                      .onClick(() => { this.findText = s; })
                  }, (s: string, idx: number) => s + ':' + idx)
                }
              }
              .width('100%')
              .height(60)
              .border({ width: 1, color: '#D0D0D0' })
            }

            if (this.statusMsg) {
              Text(this.statusMsg)
                .fontSize(11)
                .fontColor('#CC3333')
                .margin({ top: 8 })
            }
          }
          .padding({ left: 16, right: 16 })

          Row() {
            Button(getAppString('dlg_find_action'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .onClick(() => { this.onFind(); })
            Button(getAppString('dlg_update_start_path'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onUpdateStartPath(); })
            Button(getAppString('common_close'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.isVisible = false; })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: 8 })
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
