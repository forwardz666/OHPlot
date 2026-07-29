// ArkSciDAVis Language Helper
import i18n from '@ohos.i18n';
import hilog from '@ohos.hilog';

// Sync resource lookup for data-model strings (menu labels etc.) that
// cannot bind $r() directly.  Falls back to the raw name on failure.
export function getAppString(name: string): string {
  try {
    return getContext().resourceManager.getStringByNameSync(name);
  } catch (e) {
    return name;
  }
}

export function getSystemLanguage(): string {
  try {
    return i18n.System.getSystemLanguage();
  } catch (e) {
    return 'en';
  }
}

// App preferred language; falls back to the system language when the app
// has not set one (i18n.System.getAppPreferredLanguage semantics).
export function getAppLanguage(): string {
  try {
    return i18n.System.getAppPreferredLanguage();
  } catch (e) {
    return 'en';
  }
}

// tag: 'default' (follow system) | 'en-Latn-US' | 'zh-Hans' | …
// setAppPreferredLanguage applies immediately (triggers
// onConfigurationUpdate) and is persisted by the system.
export function setAppLanguage(tag: string): void {
  try {
    i18n.System.setAppPreferredLanguage(tag);
  } catch (e) {
    hilog.error(0x0000, 'OHPlot', 'setAppPreferredLanguage(%{public}s) failed: %{public}s',
      tag, JSON.stringify(e));
  }
}
