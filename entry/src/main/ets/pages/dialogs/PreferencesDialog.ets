import { getAppLanguage, getSystemLanguage, setAppLanguage } from '../../components/LocaleHelper';
import {
  ACCENT, TEXT, BTN_BG, BTN_BG_ACCENT, BTN_TEXT, BTN_TEXT_ACCENT,
  DIALOG_SIDEBAR_BG, SELECTED_BG, RADIUS_4, RADIUS_8, BTN_HEIGHT,
  BTN_GAP, FS_DIALOG_LABEL, FS_DIALOG_BODY, FS_DIALOG_SMALL, SPACING_12, SPACING_16,
  SIDEBAR_ITEM_HEIGHT, INPUT_HEIGHT, INPUT_HEIGHT_TALL
} from '../../components/Theme';
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

const DOMAIN = 0x0001;
const TAG = 'PreferencesDialog';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface PreferenceResponse {
  success: boolean;
  value?: string;
  error?: string;
}

// Language choice index → i18n.System.setAppPreferredLanguage tag.
const LANG_TAGS: string[] = ['default', 'en-Latn-US', 'zh-Hans'];

// QSettings keys matching the preferences exposed in this dialog.
const KEY_AUTOSAVE = 'autosave';
const KEY_AUTOSAVE_INTERVAL = 'autosaveInterval';
const KEY_SHOW_COMMENTS = 'showComments';
const KEY_ANTIALIASING = 'antialiasing';
const KEY_LANGUAGE = 'language';

@CustomDialog
export struct PreferencesDialog {
  controller: CustomDialogController;
  @State selectedCategory: number = 0;
  @State autosave: boolean = false;
  @State autosaveInterval: string = '5';
  @State showComments: boolean = false;
  @State antialiasing: boolean = false;
  // Pending language selection; applied (setAppPreferredLanguage) on Apply.
  @State langIndex: number = 1;
  private langDirty: boolean = false;

  // Resource-based categories: Text($r(...)) re-renders automatically on
  // language change (no getAppString/langTick rebuild needed here).
  private categories: Resource[] = [
    $r('app.string.pref_general'), $r('app.string.pref_tables'), $r('app.string.pref_plots')
  ];
  private langLabels: Resource[] = [
    $r('app.string.pref_lang_system'), $r('app.string.pref_lang_english'), $r('app.string.pref_lang_chinese')
  ];

  aboutToAppear(): void {
    // Persisted language choice; 'default' = follow system.  getAppPreferredLanguage
    // cannot report "unset" (falls back to system language), so we persist our own.
    const saved: string = this.getPreference(KEY_LANGUAGE);
    if (saved === 'default') {
      this.langIndex = 0;
    } else if (saved === 'en-Latn-US') {
      this.langIndex = 1;
    } else if (saved === 'zh-Hans') {
      this.langIndex = 2;
    } else {
      // First run / legacy: mirror the effective language as before.
      this.langIndex = getAppLanguage().startsWith('zh') ? 2 : 1;
    }

    // Load persisted preferences from Qt QSettings.
    let v = this.getPreference(KEY_AUTOSAVE);
    if (v !== '') this.autosave = v === 'true';

    v = this.getPreference(KEY_AUTOSAVE_INTERVAL);
    if (v !== '') this.autosaveInterval = v;

    v = this.getPreference(KEY_SHOW_COMMENTS);
    if (v !== '') this.showComments = v === 'true';

    v = this.getPreference(KEY_ANTIALIASING);
    if (v !== '') this.antialiasing = v === 'true';
  }

  private getPreference(key: string): string {
    try {
      let injector = qohos as QohosInjector;
      let result = injector.callQtCommand('getPreference', JSON.stringify({ key: key }));
      let parsed = JSON.parse(result) as PreferenceResponse;
      if (parsed.success && parsed.value !== undefined) return parsed.value;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getPreference error: %{public}s', JSON.stringify(e));
    }
    return '';
  }

  private setPreference(key: string, value: string): void {
    try {
      let injector = qohos as QohosInjector;
      injector.callQtCommand('setPreference', JSON.stringify({ key: key, value: value }));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setPreference error: %{public}s', JSON.stringify(e));
    }
  }

  build() {
    Column() {
      Row() {
        // Left category list
        Column() {
          ForEach(this.categories, (cat: Resource, idx: number) => {
            Text(cat)
              .fontSize(FS_DIALOG_LABEL)
              .fontColor(idx === this.selectedCategory ? ACCENT : TEXT)
              .fontWeight(idx === this.selectedCategory ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(idx === this.selectedCategory ? SELECTED_BG : '#FFFFFF')
              .width('100%')
              .height(SIDEBAR_ITEM_HEIGHT)
              .padding({ left: SPACING_12 })
              .onClick(() => {
                this.selectedCategory = idx;
              })
          }, (cat: Resource, idx: number) => idx.toString())
        }
        .width(100)
        .height(200)
        .backgroundColor(DIALOG_SIDEBAR_BG)

        // Right content area
        Column() {
          if (this.selectedCategory === 0) {
            // General
            Row() {
              Text($r('app.string.pref_language'))
                .fontSize(FS_DIALOG_BODY)
                .fontColor(TEXT)
              Select([
                { value: this.langLabels[0] },
                { value: this.langLabels[1] },
                { value: this.langLabels[2] }
              ])
                .selected(this.langIndex)
                .value(this.langLabels[this.langIndex])
                .font({ size: FS_DIALOG_BODY })
                .height(INPUT_HEIGHT_TALL)
                .onSelect((idx: number) => {
                  this.langIndex = idx;
                  this.langDirty = true;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: SPACING_12 })
            Row() {
              Text($r('app.string.pref_autosave'))
                .fontSize(FS_DIALOG_BODY)
                .fontColor(TEXT)
              Toggle({ type: ToggleType.Switch, isOn: this.autosave })
                .onChange((val: boolean) => {
                  this.autosave = val;
                })
            }
            .width('100%')
            .margin({ bottom: SPACING_12 })
            Row() {
              Text($r('app.string.pref_autosave_interval'))
                .fontSize(FS_DIALOG_BODY)
                .fontColor(TEXT)
              TextInput({ text: this.autosaveInterval, placeholder: '5' })
                .width(60)
                .height(INPUT_HEIGHT)
                .fontSize(FS_DIALOG_SMALL)
                .onChange((val: string) => {
                  this.autosaveInterval = val;
                })
            }
            .width('100%')
          } else if (this.selectedCategory === 1) {
            // Tables
            Row() {
              Text($r('app.string.pref_show_comments'))
                .fontSize(FS_DIALOG_BODY)
                .fontColor(TEXT)
              Toggle({ type: ToggleType.Switch, isOn: this.showComments })
                .onChange((val: boolean) => {
                  this.showComments = val;
                })
            }
            .width('100%')
          } else {
            // Plots
            Row() {
              Text($r('app.string.pref_antialiasing'))
                .fontSize(FS_DIALOG_BODY)
                .fontColor(TEXT)
              Toggle({ type: ToggleType.Switch, isOn: this.antialiasing })
                .onChange((val: boolean) => {
                  this.antialiasing = val;
                })
            }
            .width('100%')
          }
        }
        .layoutWeight(1)
        .padding({ left: SPACING_16, right: SPACING_16 })
      }
      .width('100%')
      .height(200)

      // Bottom buttons
      Row() {
        Button($r('app.string.common_cancel'))
          .fontSize(FS_DIALOG_LABEL)
          .height(BTN_HEIGHT)
          .backgroundColor(BTN_BG)
          .fontColor(BTN_TEXT)
          .borderRadius(RADIUS_4)
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.common_apply'))
          .fontSize(FS_DIALOG_LABEL)
          .height(BTN_HEIGHT)
          .backgroundColor(BTN_BG_ACCENT)
          .fontColor(BTN_TEXT_ACCENT)
          .borderRadius(RADIUS_4)
          .margin({ left: BTN_GAP })
          .onClick(() => {
            // Language applies immediately: setAppPreferredLanguage refreshes
            // $r bindings and fires onConfigurationUpdate → langTick →
            // MainLayout.rebuildMenus.  Persist the raw choice so the dialog can
            // restore "Follow System" (index 0) on next open.
            if (this.langDirty) {
              if (this.langIndex === 0) {
                // 'default' only takes effect after restart (documented).  To switch the
                // UI immediately, resolve the system language to a concrete tag we ship
                // resources for (zh → zh-Hans, en → en-Latn-US).  We still persist
                // 'default' as the user's choice so the dropdown shows "Follow System".
                const sys: string = getSystemLanguage();
                if (sys.startsWith('zh')) {
                  setAppLanguage('zh-Hans');
                } else if (sys.startsWith('en')) {
                  setAppLanguage('en-Latn-US');
                } else {
                  setAppLanguage('default'); // no matching resource; follows system on restart
                }
                this.setPreference(KEY_LANGUAGE, 'default');
              } else {
                setAppLanguage(LANG_TAGS[this.langIndex]);
                this.setPreference(KEY_LANGUAGE, LANG_TAGS[this.langIndex]);
              }
            }
            // Persist all settings via QSettings.
            this.setPreference(KEY_AUTOSAVE, this.autosave.toString());
            this.setPreference(KEY_AUTOSAVE_INTERVAL, this.autosaveInterval);
            this.setPreference(KEY_SHOW_COMMENTS, this.showComments.toString());
            this.setPreference(KEY_ANTIALIASING, this.antialiasing.toString());
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: SPACING_16, right: SPACING_16, bottom: SPACING_16 })
      .justifyContent(FlexAlign.End)
    }
    .width(360)
    .backgroundColor('#FFFFFF')
    .borderRadius(RADIUS_8)
    .padding({ top: SPACING_16 })
  }
}
