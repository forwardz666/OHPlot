@CustomDialog
export struct PreferencesDialog {
  controller: CustomDialogController;
  @State selectedCategory: number = 0;
  @State autosave: boolean = false;
  @State autosaveInterval: string = '5';
  @State showComments: boolean = false;
  @State antialiasing: boolean = false;

  private categories: string[] = ['General', 'Tables', 'Plots'];

  build() {
    Column() {
      Row() {
        // Left category list
        Column() {
          ForEach(this.categories, (cat: string, idx: number) => {
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
          }, (cat: string) => cat)
        }
        .width(100)
        .height(200)
        .backgroundColor('#F5F5F5')

        // Right content area
        Column() {
          if (this.selectedCategory === 0) {
            // General
            Row() {
              Text('Autosave')
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
              Text('Autosave interval (min)')
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
              Text('Show comments')
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
              Text('Antialiasing')
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
        Button('Cancel')
          .fontSize(14)
          .height(32)
          .backgroundColor('#E0E0E0')
          .fontColor('#333333')
          .borderRadius(4)
          .onClick(() => {
            this.controller.close();
          })
        Button('Apply')
          .fontSize(14)
          .height(32)
          .backgroundColor('#0078D7')
          .fontColor('#FFFFFF')
          .borderRadius(4)
          .margin({ left: 12 })
          .onClick(() => {
            // TODO: call get/setPreference commands to persist settings
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
