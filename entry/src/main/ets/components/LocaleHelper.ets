// ArkSciDAVis Language Helper
import deviceInfo from '@ohos.deviceInfo';

export function getAppString(name: string): string {
  try {
    return getContext().resourceManager.getStringByNameSync(name);
  } catch (e) {
    return name;
  }
}

export function getSystemLanguage(): string {
  try {
    return deviceInfo.deviceType;
  } catch (e) {
    return 'en';
  }
}
