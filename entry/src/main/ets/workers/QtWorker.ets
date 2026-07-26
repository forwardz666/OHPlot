/**
 * Qt Worker – runs startQtApplication on a dedicated thread so the main
 * JS thread's event loop stays free to service NAPI thread-safe-function
 * callbacks (createJsObject / deleteJsObject registered via
 * initJsObjectLoader on libQt5Core.so).
 *
 * Without this Worker the synchronous startQtApplication call blocks the
 * main JS thread → TSFN callbacks cannot be dispatched → Qt's
 * QOpenHarmonyJsObjectLoader times out requesting JsLocale → crash.
 */
import worker from '@ohos.worker';
import hilog from '@ohos.hilog';
import qpaRaw from 'libplugins_platforms_qopenharmony.so';

const DOMAIN: number = 0x0000;
const TAG: string = 'QtWorker';

interface QpaModule {
  startQtApplication(dirs: Object, appBinary: string): boolean;
  quitQtApplication(): void;
}

interface MsgEvent {
  data: Object;
}

interface WorkerCmd {
  cmd: string;
  dirs: Object;
}

interface WorkerResponse {
  cmd: string;
  value: Object;
}

const qpa = qpaRaw as QpaModule;
const workerPort = worker.workerPort;

workerPort.onmessage = (e: MsgEvent) => {
  let msg: WorkerCmd = e.data as WorkerCmd;
  let cmd: string = msg.cmd;

  if (cmd == 'start') {
    let dirs: Object = msg.dirs;
    hilog.info(DOMAIN, TAG, 'Worker: calling startQtApplication...');
    try {
      let result: boolean = qpa.startQtApplication(dirs, 'libentry.so');
      hilog.info(DOMAIN, TAG, 'Worker: startQtApplication result = %{public}s', String(result));
      let resp: WorkerResponse = { cmd: 'result', value: result };
      workerPort.postMessage(resp);
    } catch (err) {
      let errMsg: string = '';
      if (err instanceof Error) {
        errMsg = err.message + ' | ' + err.stack;
      } else {
        errMsg = JSON.stringify(err);
      }
      hilog.error(DOMAIN, TAG, 'Worker: startQtApplication failed: %{public}s', errMsg);
      let resp: WorkerResponse = { cmd: 'error', value: errMsg };
      workerPort.postMessage(resp);
    }
  } else if (cmd == 'quit') {
    hilog.info(DOMAIN, TAG, 'Worker: quitQtApplication');
    try {
      qpa.quitQtApplication();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Worker: quitQtApplication failed: %{public}s', JSON.stringify(err));
    }
  }
};

hilog.info(DOMAIN, TAG, 'QtWorker ready');
