// JsPasteBoard bridge object for the Qt-for-OpenHarmony QPA plugin.
// QOpenHarmonyPlatformClipboard proxies QClipboard entirely through this
// object (requested via createJsObject("JsPasteBoard")).  Method names come
// from the plugin's symbol table: clearData / setClipboard{Text,Html,Uri,
// PixelMap} / hasClipboard* / clipboard*.
// All calls arrive over the TSFN bridge and must return synchronously, so
// only the *Sync pasteboard APIs are used here.
// NOTE: reading (getDataSync) needs READ_PASTEBOARD, which the debug signing
// profile cannot grant — the PasteButton security component in the Edit menu
// provides a temporary one-shot authorization right before Qt reads.
import pasteboard from '@ohos.pasteboard';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsPasteBoard';

export class JsPasteBoard {
  clearData(): void {
    try {
      pasteboard.getSystemPasteboard().clearDataSync();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clearData failed: %{public}s', (e as Error).message);
    }
  }

  // ── writers (no permission required) ──────────────────────────────
  setClipboardText(text: string): void {
    this.setData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  }

  setClipboardHtml(html: string): void {
    this.setData(pasteboard.MIMETYPE_TEXT_HTML, html);
  }

  setClipboardUri(uri: string): void {
    this.setData(pasteboard.MIMETYPE_TEXT_URI, uri);
  }

  setClipboardPixelMap(_pixelMap: object): void {
    // Image clipboard is not needed by OHPlot; ignore silently.
    hilog.info(DOMAIN, TAG, 'setClipboardPixelMap ignored (unsupported)');
  }

  private setData(mimeType: string, value: string): void {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(mimeType, value);
      pasteboard.getSystemPasteboard().setDataSync(data);
      hilog.info(DOMAIN, TAG, 'setData %{public}s (%{public}d chars)', mimeType, value.length);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setData %{public}s failed: %{public}s', mimeType, (e as Error).message);
    }
  }

  // ── type probes (no permission required) ──────────────────────────
  hasClipboardText(): boolean {
    return this.hasType(pasteboard.MIMETYPE_TEXT_PLAIN);
  }

  hasClipboardHtml(): boolean {
    return this.hasType(pasteboard.MIMETYPE_TEXT_HTML);
  }

  hasClipboardUri(): boolean {
    return this.hasType(pasteboard.MIMETYPE_TEXT_URI);
  }

  hasClipboardPixelMap(): boolean {
    return false;
  }

  private hasType(mimeType: string): boolean {
    try {
      return pasteboard.getSystemPasteboard().hasDataType(mimeType);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'hasDataType %{public}s failed: %{public}s', mimeType, (e as Error).message);
      return false;
    }
  }

  // ── readers (need READ_PASTEBOARD / PasteButton temporary auth) ───
  clipboardText(): string {
    try {
      const text: string = pasteboard.getSystemPasteboard().getDataSync().getPrimaryText();
      return text !== null && text !== undefined ? text : '';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clipboardText failed: %{public}s', (e as Error).message);
      return '';
    }
  }

  clipboardHtml(): string {
    try {
      const html: string = pasteboard.getSystemPasteboard().getDataSync().getPrimaryHtml();
      return html !== null && html !== undefined ? html : '';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clipboardHtml failed: %{public}s', (e as Error).message);
      return '';
    }
  }

  clipboardUri(): string {
    try {
      const uri: string = pasteboard.getSystemPasteboard().getDataSync().getPrimaryUri();
      return uri !== null && uri !== undefined ? uri : '';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clipboardUri failed: %{public}s', (e as Error).message);
      return '';
    }
  }

  clipboardPixelMap(): object | null {
    return null;
  }
}
