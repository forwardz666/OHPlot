// ArkSciDAVis Note Editor Component
// Connected to Qt backend via getNoteData / setNoteData commands.
// Loads active Note content on open; saves back with 500ms debounce on edit.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'SciDAVisChain';

interface NoteData {
  success: boolean;
  text?: string;
  name?: string;
  label?: string;
  error?: string;
}

interface SetNoteArgs {
  text: string;
}

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct NoteEditor {
  currentLocale?: string = '';
  @State noteText: string = '';
  @State noteName: string = '';
  @State noteLabel: string = '';
  private saveTimer: number = -1;
  // Guard: only flush on exit if load succeeded and content was actually edited
  private loaded: boolean = false;
  private dirty: boolean = false;

  aboutToAppear(): void {
    this.loadNoteData();
  }

  aboutToDisappear(): void {
    if (this.saveTimer >= 0) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
    }
    // Only flush if load succeeded AND content was actually edited
    // (prevents erasing Note content when load failed and noteText stayed '')
    if (this.loaded && this.dirty) {
      this.saveNoteData();
    }
  }

  loadNoteData(): void {
    try {
      let injector: QohosInjector = qohos as QohosInjector;
      let result: string = injector.callQtCommand('getNoteData', '{}');
      hilog.info(DOMAIN, TAG, 'NoteEditor getNoteData: %{public}s', result);
      let parsed: NoteData = JSON.parse(result) as NoteData;
      if (parsed.success) {
        if (parsed.text !== undefined) {
          this.noteText = parsed.text;
        }
        if (parsed.name !== undefined) {
          this.noteName = parsed.name;
        }
        if (parsed.label !== undefined) {
          this.noteLabel = parsed.label;
        }
        this.loaded = true; // load succeeded, safe to flush on exit
      } else {
        hilog.warn(DOMAIN, TAG, 'NoteEditor getNoteData failed: %{public}s',
          parsed.error ?? 'unknown error');
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'NoteEditor load error: %{public}s', (e as Error).message);
    }
  }

  private saveNoteData(): void {
    try {
      let injector: QohosInjector = qohos as QohosInjector;
      let argsObj: SetNoteArgs = { text: this.noteText };
      let args: string = JSON.stringify(argsObj);
      let result: string = injector.callQtCommand('setNoteData', args);
      hilog.info(DOMAIN, TAG, 'NoteEditor setNoteData result: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'NoteEditor save error: %{public}s', (e as Error).message);
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.noteLabel || $r('app.string.notes_title'))
          .fontSize(14)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 8, top: 4, bottom: 4 })
      }
      .width('100%')
      .backgroundColor('#F5F5F5')
      .border({ width: { bottom: 1 }, color: '#CCCCCC' })

      TextArea({ text: this.noteText, placeholder: '...' })
        .width('100%')
        .layoutWeight(1)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.noteText = value;
          this.dirty = true; // content was edited
          if (this.saveTimer >= 0) {
            clearTimeout(this.saveTimer);
          }
          this.saveTimer = setTimeout(() => {
            this.saveNoteData();
            this.saveTimer = -1;
          }, 500);
        })
    }
    .width('100%')
    .height('100%')
  }
}
