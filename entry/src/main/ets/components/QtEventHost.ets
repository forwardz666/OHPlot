// ArkSciDAVis Qt Event Host
// Receives JSON events pushed from the Qt backend through the
// qohos.onQtEvent channel (libentry.so: scidavis_emit → NAPI TSFN) and
// renders native ArkUI replacements for the popups the single-window QPA
// cannot create:
//   - kind=message      → Toast (information/about) or modal box (warning/
//                         critical/question; the backend already picked a
//                         safe default answer, we just inform the user)
//   - kind=dialogBlocked→ Toast "not yet adapted"
//   - kind=fileDialog   → Toast (Phase 2 wires @ohos.file.picker + commands)
//   - kind=inputDialog / colorDialog / fontDialog → Toast
//   - kind=contextMenu  → ArkUI menu panel; taps go back via triggerMenu
//   - kind=comboRequest → ArkUI picker list; taps go back via selectCombo
//   - kind=projectSaved → queued saveProject completed; if a save-as target
//                         URI is pending (AppStorage 'pendingSaveAsUri'),
//                         copy the sandbox file out to it
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import fs from '@ohos.file.fs';

const DOMAIN: number = 0x0000;
const TAG: string = 'QtEventHost';

interface QohosEventApi {
  onQtEvent(callback: (json: string) => void): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}

const qtApi = qohos as QohosEventApi;

// ── Event payloads (mirror ohos_bridge.cpp) ──────────────────────────────
interface QtEvent {
  kind: string;
  // message
  severity?: string;
  title?: string;
  text?: string;
  chosen?: number;
  // dialogBlocked
  className?: string;
  objectName?: string;
  // fileDialog
  mode?: string;
  caption?: string;
  // contextMenu
  menuId?: number;
  items?: QtMenuItem[];
  // comboRequest
  comboId?: number;
  current?: number;
  // projectSaved
  ok?: boolean;
  path?: string;
}

interface QtMenuItem {
  text?: string;
  enabled?: boolean;
  checkable?: boolean;
  checked?: boolean;
  separator?: boolean;
  children?: QtMenuItem[];
}

interface TriggerMenuArgs {
  menuId: number;
  path: string;
}

interface SelectComboArgs {
  comboId: number;
  index: number;
}

function stripMnemonic(s: string | undefined): string {
  return s ? s.replace('&', '') : '';
}

@Component
export struct QtEventHost {
  // Modal message box (warning/critical/question)
  @State msgVisible: boolean = false;
  @State msgSeverity: string = '';
  @State msgTitle: string = '';
  @State msgText: string = '';
  // Context menu overlay
  @State ctxVisible: boolean = false;
  @State ctxItems: QtMenuItem[] = [];
  @State ctxPathPrefix: string = '';
  private ctxMenuId: number = -1;
  // Combo picker overlay
  @State comboVisible: boolean = false;
  @State comboItems: string[] = [];
  @State comboCurrent: number = -1;
  private comboId: number = -1;

  aboutToAppear(): void {
    // Subscribe once; events arriving before Qt started are buffered in
    // libentry.so and flushed on registration (see ohos_bridge.cpp).
    try {
      const ok: boolean = qtApi.onQtEvent((json: string) => this.handleEvent(json));
      hilog.info(DOMAIN, TAG, 'onQtEvent subscribed: %{public}s', String(ok));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'onQtEvent subscribe failed: %{public}s', (e as Error).message);
    }
  }

  private handleEvent(json: string): void {
    hilog.info(DOMAIN, TAG, 'qt event: %{public}s', json);
    let ev: QtEvent;
    try {
      ev = JSON.parse(json) as QtEvent;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'bad event json: %{public}s', (e as Error).message);
      return;
    }
    try {
      this.dispatchEvent(ev);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'event dispatch failed: %{public}s', (e as Error).message);
    }
  }

  private dispatchEvent(ev: QtEvent): void {
    switch (ev.kind) {
      case 'message': {
        const sev: string = ev.severity ?? 'information';
        if (sev === 'warning' || sev === 'critical' || sev === 'question') {
          this.msgSeverity = sev;
          this.msgTitle = stripMnemonic(ev.title);
          this.msgText = ev.text ?? '';
          this.msgVisible = true;
        } else {
          // information / about — transient toast is enough
          this.toast((ev.title ? ev.title + ': ' : '') + (ev.text ?? ''));
        }
        break;
      }
      case 'dialogBlocked':
        this.toast('Dialog not yet available on tablet: ' + (ev.className ?? 'unknown'));
        break;
      case 'fileDialog':
        // Phase 2: open @ohos.file.picker here and route the chosen path
        // back through a dedicated command (openProject/saveProject/...).
        this.toast('File dialog "' + stripMnemonic(ev.caption) + '" not yet wired (' +
          (ev.mode ?? '?') + ')');
        break;
      case 'inputDialog':
        this.toast('Input dialog not yet available: ' + stripMnemonic(ev.title));
        break;
      case 'colorDialog':
        this.toast('Color picker not yet available');
        break;
      case 'fontDialog':
        this.toast('Font picker not yet available');
        break;
      case 'contextMenu': {
        const items: QtMenuItem[] = ev.items ?? [];
        if (items.length === 0 || ev.menuId === undefined) {
          hilog.info(DOMAIN, TAG, 'contextMenu without id/items — ignored');
          break;
        }
        this.ctxMenuId = ev.menuId;
        this.ctxItems = items;
        this.ctxPathPrefix = '';
        this.ctxVisible = true;
        break;
      }
      case 'comboRequest': {
        this.comboId = ev.comboId ?? -1;
        this.comboItems = (ev.items ?? []).map((it: QtMenuItem): string => {
          // combo items are plain strings in the payload; JSON.parse maps
          // them onto QtMenuItem-typed slots, so re-read via String().
          return String(it as Object);
        });
        this.comboCurrent = ev.current ?? -1;
        this.comboVisible = this.comboId >= 0 && this.comboItems.length > 0;
        break;
      }
      case 'projectSaved':
        this.onProjectSaved(ev.ok === true, ev.path ?? '');
        break;
      default:
        hilog.info(DOMAIN, TAG, 'unhandled event kind: %{public}s', ev.kind);
        break;
    }
  }

  // Queued saveProject finished in Qt.  If save-as stashed a picker URI,
  // export the sandbox file to it now (the copy is safe here: the save is
  // complete and the JS thread is not blocking Qt).
  private onProjectSaved(ok: boolean, path: string): void {
    const pending: string | undefined = AppStorage.get<string>('pendingSaveAsUri');
    if (pending === undefined || pending === '') {
      return; // plain Save — the backend message toast already covers it
    }
    AppStorage.setOrCreate<string>('pendingSaveAsUri', '');
    if (!ok || path === '') {
      this.toast('Save As failed: project could not be saved');
      return;
    }
    try {
      const dst = fs.openSync(pending,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.copyFileSync(path, dst.fd);
      fs.closeSync(dst);
      hilog.info(DOMAIN, TAG, 'save_as exported %{public}s -> %{public}s', path, pending);
      this.toast('Project exported');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save_as export failed: %{public}s', (e as Error).message);
      this.toast('Save As export failed: ' + (e as Error).message);
    }
  }

  private toast(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2500 });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'showToast failed: %{public}s', (e as Error).message);
    }
  }

  private callCommand(cmd: string, args: string): void {
    try {
      const result: string = qtApi.callQtCommand(cmd, args);
      hilog.info(DOMAIN, TAG, '%{public}s → %{public}s', cmd, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', cmd, (e as Error).message);
    }
  }

  private onCtxItemTap(index: number, item: QtMenuItem): void {
    const fullPath: string = this.ctxPathPrefix + String(index);
    if (item.children !== undefined && item.children.length > 0) {
      // descend into submenu
      this.ctxPathPrefix = fullPath + '/';
      this.ctxItems = item.children;
      return;
    }
    this.ctxVisible = false;
    this.callCommand('triggerMenu',
      JSON.stringify({ menuId: this.ctxMenuId, path: fullPath } as TriggerMenuArgs));
  }

  private severityColor(): ResourceColor {
    if (this.msgSeverity === 'critical') return '#d32f2f';
    if (this.msgSeverity === 'warning') return '#f57c00';
    return '#1976d2';
  }

  build() {
    Stack() {
      // ── Modal message box ────────────────────────────────────────────
      if (this.msgVisible) {
        Column() {
          Column() {
            Text(this.msgTitle !== '' ? this.msgTitle : this.msgSeverity.toUpperCase())
              .fontSize(17).fontWeight(FontWeight.Bold)
              .fontColor(this.severityColor())
              .margin({ bottom: 8 })
            Scroll() {
              Text(this.msgText).fontSize(14).fontColor('#333333')
            }
            .constraintSize({ maxHeight: 260 })
            Button('OK')
              .margin({ top: 12 })
              .height(36)
              .onClick(() => { this.msgVisible = false; })
          }
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(10)
          .shadow({ radius: 16, color: '#40000000' })
          .constraintSize({ maxWidth: 480, minWidth: 300 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#30000000')
        .onClick(() => { /* modal — require OK tap */ })
      }

      // ── Context menu panel ───────────────────────────────────────────
      if (this.ctxVisible) {
        Column() {
          Column() {
            Scroll() {
              Column() {
                ForEach(this.ctxItems, (item: QtMenuItem, index: number) => {
                  if (item.separator === true) {
                    Divider().margin({ top: 4, bottom: 4 })
                  } else {
                    Row() {
                      if (item.checkable === true) {
                        Text(item.checked === true ? '✓ ' : '   ').fontSize(14)
                      }
                      Text(stripMnemonic(item.text))
                        .fontSize(14)
                        .fontColor(item.enabled === false ? '#a0a0a0' : '#222222')
                      Blank()
                      if (item.children !== undefined && item.children.length > 0) {
                        Text('▸').fontSize(14).fontColor('#888888')
                      }
                    }
                    .width('100%')
                    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
                    .onClick(() => {
                      if (item.enabled !== false) {
                        this.onCtxItemTap(index, item);
                      }
                    })
                  }
                }, (item: QtMenuItem, index: number) => String(index) + (item.text ?? 'sep'))
              }
            }
            .constraintSize({ maxHeight: 420 })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)
          .shadow({ radius: 12, color: '#40000000' })
          .constraintSize({ maxWidth: 340, minWidth: 220 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#20000000')
        .onClick(() => { this.ctxVisible = false; }) // outside tap dismisses
      }

      // ── Combo picker panel ───────────────────────────────────────────
      if (this.comboVisible) {
        Column() {
          Column() {
            Scroll() {
              Column() {
                ForEach(this.comboItems, (label: string, index: number) => {
                  Row() {
                    Text(label)
                      .fontSize(14)
                      .fontColor(index === this.comboCurrent ? '#1976d2' : '#222222')
                      .fontWeight(index === this.comboCurrent ? FontWeight.Bold : FontWeight.Normal)
                  }
                  .width('100%')
                  .padding({ left: 14, right: 14, top: 9, bottom: 9 })
                  .onClick(() => {
                    this.comboVisible = false;
                    this.callCommand('selectCombo',
                      JSON.stringify({ comboId: this.comboId, index: index } as SelectComboArgs));
                  })
                }, (label: string, index: number) => String(index) + label)
              }
            }
            .constraintSize({ maxHeight: 420 })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)
          .shadow({ radius: 12, color: '#40000000' })
          .constraintSize({ maxWidth: 340, minWidth: 220 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#20000000')
        .onClick(() => { this.comboVisible = false; })
      }
    }
    .width('100%').height('100%')
    // Idle: fully transparent to touches so Qt keeps receiving input.
    .hitTestBehavior((this.msgVisible || this.ctxVisible || this.comboVisible)
      ? HitTestMode.Default : HitTestMode.None)
  }
}
