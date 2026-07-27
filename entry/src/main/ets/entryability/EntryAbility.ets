import AbilityStage from '@ohos.app.ability.AbilityStage';
import hilog from '@ohos.hilog';

// Module-level AbilityStage. The Qt bootstrap is performed entirely by the
// official QPA plugin from OHPlotAbility.onWindowStageCreate
// (QPA.startQtApplication). This stage is intentionally minimal: the previous
// version called non-existent QPA methods (setupQtApplication /
// handleAbilityStageOnCreate) which were Stubs in our own wrapper and silently
// did nothing — the root cause of the black screen.
export default class QAbilityStage extends AbilityStage {
  onCreate(): void {
    hilog.info(0x0000, 'OHPlot', 'Stage::onCreate');
  }

  onDestroy() {
    hilog.info(0x0000, 'OHPlot', 'Stage::onDestroy');
  }
}
