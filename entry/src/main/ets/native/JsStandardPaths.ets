import environment from '@ohos.file.environment';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsStandardPaths';

export interface ApplicationDirs {
  tempDir: string;
  filesDir: string;
  cacheDir: string;
  databaseDir: string;
  bundleCodeDir: string;
  preferencesDir: string;
  distributedFilesDir: string;
  qmlDir: string;
}

/**
 * JS bridge object that provides standard path information to Qt Core.
 * Qt's QStandardPaths calls getJsFunction("JsStandardPaths") to obtain
 * an instance of this class, then invokes path(type) to resolve paths.
 */
export class JsStandardPaths {
  private dirs: ApplicationDirs;

  constructor(dirs: ApplicationDirs) {
    this.dirs = dirs;
  }

  path(type: string): string {
    try {
      if (type == 'DIRECTORY_DOWNLOADS') {
        return environment.getUserDownloadDir();
      } else if (type == 'DIRECTORY_DOCUMENTS') {
        return environment.getUserDocumentDir();
      } else if (type == 'DIRECTORY_DESKTOP') {
        return environment.getUserDesktopDir();
      } else if (type == 'DIRECTORY_CACHE') {
        return this.dirs.cacheDir;
      } else if (type == 'DIRECTORY_TEMP') {
        return this.dirs.tempDir;
      } else if (type == 'DIRECTORY_BUNDLE') {
        return this.dirs.bundleCodeDir;
      } else if (type == 'DIRECTORY_FILES') {
        return this.dirs.filesDir;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'path(%{public}s) failed: %{public}s', type, JSON.stringify(error));
    }
    return '';
  }
}
