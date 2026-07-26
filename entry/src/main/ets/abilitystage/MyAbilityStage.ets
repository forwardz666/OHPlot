import { AbilityStage } from '@kit.AbilityKit';
import Want from '@ohos.app.ability.Want';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'QtForOpenHarmony';

// NOTE: This QPA plugin (libplugins_platforms_qopenharmony.so) does NOT export
// attachAbilityStage or getJsAbilityInstanceKey. The Qt bootstrap is performed
// entirely by SciDAVisAbility.onWindowStageCreate via QPA.startQtApplication.
// Do NOT import the QPA .so here — importing it in the AbilityStage context
// can cause the NAPI module to register with the wrong napi_env, leading to
// a NULL QOpenHarmonyJsObject and SIGSEGV during Qt locale initialization.
export default class MyAbilityStage extends AbilityStage {
  private static isFirstLaunch: boolean = true;

  onCreate(): void {
    hilog.info(DOMAIN, TAG, 'MyAbilityStage::onCreate');
  }

  onAcceptWant(want: Want): string {
    hilog.info(DOMAIN, TAG, 'onAcceptWant want: %{public}s',
      JSON.stringify(want.parameters));

    if (want.parameters?.instanceKey == undefined) {
      if (MyAbilityStage.isFirstLaunch) {
        MyAbilityStage.isFirstLaunch = false;
        return 'qt_entry_window';
      }
      return 'qt_entry_window';
    }
    return `${want.parameters?.instanceKey}`;
  }
}
