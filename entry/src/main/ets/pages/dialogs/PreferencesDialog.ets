import { getAppLanguage, setAppLanguage } from '../../components/LocaleHelper';

// Language choice index → i18n.System.setAppPreferredLanguage tag.
const LANG_TAGS: string[] = ['default', 'en-Latn-US', 'zh-Hans'];

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
    // getAppPreferredLanguage cannot report "unset" (it falls back to the
    // system language), so the initial selection mirrors the effective
    // language; picking "Follow System" resets via 'default'.
    this.langIndex = getAppLanguage().startsWith('zh') ? 2 : 1;
  }

  build() {
    Column() {
      Row() {
        // Left category list
        Column() {
          ForEach(this.categories, (cat: Resource, idx: number) => {
            Text(cat)
              .fontSize(14)
              .fontColor(idx === this.selectedCategory ? '#0078D7' : '#333333')
              .fontWeight(idx === this.selectedCategory ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(idx === this.selectedCategory ? '#E8F4FD' : '#FFFFFF')
              .width('100%')
              .height(36)
              .padding({ left: 12 })
              .onClick(() => {
                this.selectedCategory = idx;
              })
          }, (cat: Resource, idx: number) => idx.toString())
        }
        .width(100)
        .height(200)
        .backgroundColor('#F5F5F5')

        // Right content area
        Column() {
          if (this.selectedCategory === 0) {
            // General
            Row() {
              Text($r('app.string.pref_language'))
                .fontSize(13)
                .fontColor('#333333')
              Select([
                { value: this.langLabels[0] },
                { value: this.langLabels[1] },
                { value: this.langLabels[2] }
              ])
                .selected(this.langIndex)
                .value(this.langLabels[this.langIndex])
                .font({ size: 13 })
                .height(30)
                .onSelect((idx: number) => {
                  this.langIndex = idx;
                  this.langDirty = true;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 12 })
            Row() {
              Text($r('app.string.pref_autosave'))
                .fontSize(13)
                .fontColor('#333333')
              Toggle({ type: ToggleType.Switch, isOn: this.autosave })
                .onChange((val: boolean) => {
                  this.autosave = val;
                })
            }
            .width('100%')
            .margin({ bottom: 12 })
            Row() {
              Text($r('app.string.pref_autosave_interval'))
                .fontSize(13)
                .fontColor('#333333')
              TextInput({ text: this.autosaveInterval, placeholder: '5' })
                .width(60)
                .height(28)
                .fontSize(12)
                .onChange((val: string) => {
                  this.autosaveInterval = val;
                })
            }
            .width('100%')
          } else if (this.selectedCategory === 1) {
            // Tables
            Row() {
              Text($r('app.string.pref_show_comments'))
                .fontSize(13)
                .fontColor('#333333')
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
                .fontSize(13)
                .fontColor('#333333')
              Toggle({ type: ToggleType.Switch, isOn: this.antialiasing })
                .onChange((val: boolean) => {
                  this.antialiasing = val;
                })
            }
            .width('100%')
          }
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height(200)

      // Bottom buttons
      Row() {
        Button($r('app.string.common_cancel'))
          .fontSize(14)
          .height(32)
          .backgroundColor('#E0E0E0')
          .fontColor('#333333')
          .borderRadius(4)
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.common_apply'))
          .fontSize(14)
          .height(32)
          .backgroundColor('#0078D7')
          .fontColor('#FFFFFF')
          .borderRadius(4)
          .margin({ left: 12 })
          .onClick(() => {
            // Language applies immediately: setAppPreferredLanguage refreshes
            // $r bindings and fires onConfigurationUpdate → langTick →
            // MainLayout.rebuildMenus.  Persisted by the system.
            if (this.langDirty) {
              setAppLanguage(LANG_TAGS[this.langIndex]);
            }
            // TODO: call get/setPreference commands to persist other settings
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
      .justifyContent(FlexAlign.End)
    }
    .width(360)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .padding({ top: 16 })
  }
}
