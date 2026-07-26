import { i18n } from '@kit.LocalizationKit';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsLocale';

/**
 * JS bridge object that provides system locale information to Qt Core.
 * Qt's QSystemLocale::query() calls getJsFunction("JsLocale") to obtain
 * an instance of this class, then invokes getSystemLocale() etc.
 *
 * Without this class registered via initJsObjectLoader, Qt Core's
 * QOpenHarmonyJsObject is NULL → SIGSEGV during QApplication init.
 */
export class JsLocale {
  constructor() {
  }

  getSystemLanguages(): Array<string> {
    try {
      return i18n.System.getSystemLanguages();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'getSystemLanguages failed: %{public}s', JSON.stringify(error));
      return ['zh-Hans-CN'];
    }
  }

  getSystemLanguage(): string {
    try {
      return i18n.System.getSystemLanguage();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'getSystemLanguage failed: %{public}s', JSON.stringify(error));
      return 'zh';
    }
  }

  getSystemRegion(): string {
    try {
      return i18n.System.getSystemRegion();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'getSystemRegion failed: %{public}s', JSON.stringify(error));
      return 'CN';
    }
  }

  getSystemLocale(): string {
    try {
      return i18n.System.getSystemLocale();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'getSystemLocale failed: %{public}s', JSON.stringify(error));
      return 'zh-Hans-CN';
    }
  }

  getFirstPreferredLanguage(): string {
    try {
      return i18n.System.getFirstPreferredLanguage();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'getFirstPreferredLanguage failed: %{public}s', JSON.stringify(error));
      return 'zh-Hans-CN';
    }
  }
}
