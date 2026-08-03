// AxesDialog — Format▸Axes "General Plot Options" dialog.
// 4 tabs: Scale, Axis, Grid, Frame — matching Qt AxesDialog's QTabWidget.
// On OK/Apply, dispatches setAxisScale and setAxisTitle commands via
// callQtCommand (same bridge pattern as GraphPropsDialog).
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';

const DOMAIN: number = 0x0000;
const TAG: string = 'AxesDialog';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface SetAxisScaleArgs {
  axis: number;
  scale: string;
  from: number;
  to: number;
}

interface SetAxisTitleArgs {
  axis: number;
  text: string;
}

interface SetAxisGridArgs {
  axis: number;
  majorGrid: boolean;
  minorGrid: boolean;
}

interface SetAxisFrameArgs {
  showAxis: boolean;
  backbones: boolean;
  lineWidth: number;
}

// Axis position enum: Bottom=2, Left=0, Top=3, Right=1 (Qwt axis IDs)
interface AxisDef {
  id: number;
  label: string;
}

const AXES: AxisDef[] = [
  { id: 2, label: 'Bottom' },
  { id: 0, label: 'Left' },
  { id: 3, label: 'Top' },
  { id: 1, label: 'Right' },
];

const SCALE_TYPES: string[] = ['linear', 'logarithmic'];

@Component
export struct AxesDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  // Tab index: 0=Scale, 1=Axis, 2=Grid, 3=Frame
  @State tabIdx: number = 0;
  // Axis selector
  @State selAxisIdx: number = 0;

  // Scale tab state
  @State scaleFrom: string = '0';
  @State scaleTo: string = '1';
  @State scaleTypeIdx: number = 0;
  @State scaleInverted: boolean = false;
  @State scaleStep: string = '0.1';
  @State scaleMajorTicks: number = 5;
  @State scaleMinorTicksIdx: number = 0;

  // Axis tab state
  @State axisTitle: string = '';
  @State axisShow: boolean = true;

  // Grid tab state
  @State gridMajor: boolean = false;
  @State gridMinor: boolean = false;

  // Frame tab state
  @State frameShowAxis: boolean = true;
  @State frameBackbones: boolean = true;
  @State frameLineWidth: number = 1;

  @State statusMsg: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.loadData();
    }
  }

  private loadData(): void {
    // Fetch current axis settings from backend
    this.tabIdx = 0;
    this.selAxisIdx = 0;
    this.statusMsg = '';
    this.loadAxisSettings();
  }

  private loadAxisSettings(): void {
    // Request current axis config for the selected axis
    const axisId: number = AXES[this.selAxisIdx].id;
    try {
      const injector = qohos as QohosInjector;
      const result: string = injector.callQtCommand('getAxisConfig',
        JSON.stringify({ axis: axisId }));
      if (result.length > 0) {
        const parsed = JSON.parse(result) as AxisConfigResponse;
        if (parsed.success && parsed.data) {
          const cfg: AxisConfigData = parsed.data;
          this.scaleFrom = cfg.from.toString();
          this.scaleTo = cfg.to.toString();
          this.scaleTypeIdx = cfg.scaleType === 'log' ? 1 : 0;
          this.scaleInverted = cfg.inverted;
          this.axisTitle = cfg.title;
          this.axisShow = cfg.visible;
          this.gridMajor = cfg.majorGrid;
          this.gridMinor = cfg.minorGrid;
          this.frameBackbones = cfg.backbones;
          this.frameLineWidth = cfg.lineWidth;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getAxisConfig failed: %{public}s', (e as Error).message);
    }
  }

  private currentAxisId(): number {
    return AXES[this.selAxisIdx].id;
  }

  private callQt(cmd: string, argsJson: string): void {
    try {
      const injector = qohos as QohosInjector;
      injector.callQtCommand(cmd, argsJson);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', cmd, (e as Error).message);
    }
  }

  onAxisPick(idx: number): void {
    this.selAxisIdx = idx;
    this.loadAxisSettings();
  }

  onApply(): void {
    const axisId: number = this.currentAxisId();
    // Dispatch scale
    const fromVal: number = parseFloat(this.scaleFrom);
    const toVal: number = parseFloat(this.scaleTo);
    if (isNaN(fromVal) || isNaN(toVal)) {
      this.statusMsg = getAppString('dlg_axes_invalid_range');
      return;
    }
    this.callQt('setAxisScale',
      JSON.stringify({
        axis: axisId,
        scale: SCALE_TYPES[this.scaleTypeIdx],
        from: fromVal,
        to: toVal,
      } as SetAxisScaleArgs));

    // Dispatch title
    this.callQt('setAxisTitle',
      JSON.stringify({ axis: axisId, text: this.axisTitle } as SetAxisTitleArgs));

    // Dispatch grid
    this.callQt('setAxisGrid',
      JSON.stringify({
        axis: axisId,
        majorGrid: this.gridMajor,
        minorGrid: this.gridMinor,
      } as SetAxisGridArgs));

    // Dispatch frame
    this.callQt('setAxisFrame',
      JSON.stringify({
        showAxis: this.axisShow,
        backbones: this.frameBackbones,
        lineWidth: this.frameLineWidth,
      } as SetAxisFrameArgs));

    this.statusMsg = '';
    hilog.info(DOMAIN, TAG, 'AxesDialog applied for axis %{public}d', axisId);
  }

  onOk(): void {
    this.onApply();
    this.isVisible = false;
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('dlg_axes_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 16, bottom: 12 })

          // Axis selector row
          Row() {
            ForEach(AXES, (a: AxisDef, idx: number) => {
              Text(a.label)
                .fontSize(12)
                .fontColor(idx === this.selAxisIdx ? '#0078D7' : '#666666')
                .fontWeight(idx === this.selAxisIdx ? FontWeight.Bold : FontWeight.Normal)
                .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                .border({
                  width: 1,
                  color: idx === this.selAxisIdx ? '#0078D7' : '#D0D0D0'
                })
                .borderRadius(4)
                .backgroundColor(idx === this.selAxisIdx ? '#E8F0FE' : '#F8F8F8')
                .onClick(() => { this.onAxisPick(idx); })
            }, (a: AxisDef, idx: number) => a.label + ':' + idx)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

          // Tabs
          Tabs({ index: this.tabIdx }) {
            // Tab 0: Scale
            TabContent() {
              Scroll() {
                Column({ space: 8 }) {
                  Row() {
                    Text(getAppString('dlg_axes_from'))
                      .fontSize(13).fontColor('#555555').width(80)
                    TextInput({ text: this.scaleFrom })
                      .layoutWeight(1).fontSize(13)
                      .onChange((v: string) => { this.scaleFrom = v; })
                  }.width('100%')
                  Row() {
                    Text(getAppString('dlg_axes_to'))
                      .fontSize(13).fontColor('#555555').width(80)
                    TextInput({ text: this.scaleTo })
                      .layoutWeight(1).fontSize(13)
                      .onChange((v: string) => { this.scaleTo = v; })
                  }.width('100%')
                  Row() {
                    Text(getAppString('dlg_axes_type'))
                      .fontSize(13).fontColor('#555555').width(80)
                    Column() {
                      ForEach(SCALE_TYPES, (st: string, idx: number) => {
                        Row() {
                          Radio({ value: st, group: 'scaleType' })
                            .checked(idx === this.scaleTypeIdx)
                            .onChange((isChecked: boolean) => {
                              if (isChecked) { this.scaleTypeIdx = idx; }
                            })
                          Text(st)
                            .fontSize(12).fontColor('#555555')
                            .margin({ left: 6 })
                        }
                      }, (st: string, idx: number) => st + ':' + idx)
                    }
                  }.width('100%')
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.scaleInverted })
                      .onChange((v: boolean) => { this.scaleInverted = v; })
                    Text(getAppString('dlg_axes_inverted'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                  Row() {
                    Text(getAppString('dlg_axes_step'))
                      .fontSize(13).fontColor('#555555').width(80)
                    TextInput({ text: this.scaleStep })
                      .layoutWeight(1).fontSize(13)
                      .onChange((v: string) => { this.scaleStep = v; })
                  }.width('100%')
                }
                .padding({ left: 16, right: 16 })
              }
            }.tabBar(getAppString('dlg_axes_tab_scale'))

            // Tab 1: Axis
            TabContent() {
              Scroll() {
                Column({ space: 8 }) {
                  Row() {
                    Text(getAppString('dlg_axes_title_label'))
                      .fontSize(13).fontColor('#555555').width(80)
                    TextInput({ placeholder: getAppString('dlg_axes_title_ph'), text: this.axisTitle })
                      .layoutWeight(1).fontSize(13)
                      .onChange((v: string) => { this.axisTitle = v; })
                  }.width('100%')
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.axisShow })
                      .onChange((v: boolean) => { this.axisShow = v; })
                    Text(getAppString('dlg_axes_show'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                }
                .padding({ left: 16, right: 16 })
              }
            }.tabBar(getAppString('dlg_axes_tab_axis'))

            // Tab 2: Grid
            TabContent() {
              Scroll() {
                Column({ space: 8 }) {
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.gridMajor })
                      .onChange((v: boolean) => { this.gridMajor = v; })
                    Text(getAppString('dlg_axes_major_grid'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.gridMinor })
                      .onChange((v: boolean) => { this.gridMinor = v; })
                    Text(getAppString('dlg_axes_minor_grid'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                }
                .padding({ left: 16, right: 16 })
              }
            }.tabBar(getAppString('dlg_axes_tab_grid'))

            // Tab 3: Frame
            TabContent() {
              Scroll() {
                Column({ space: 8 }) {
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.frameShowAxis })
                      .onChange((v: boolean) => { this.frameShowAxis = v; })
                    Text(getAppString('dlg_axes_show'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                  Row() {
                    Toggle({ type: ToggleType.Checkbox, isOn: this.frameBackbones })
                      .onChange((v: boolean) => { this.frameBackbones = v; })
                    Text(getAppString('dlg_axes_backbones'))
                      .fontSize(13).fontColor('#555555').margin({ left: 8 })
                  }.width('100%')
                  Row() {
                    Text(getAppString('dlg_axes_line_width'))
                      .fontSize(13).fontColor('#555555').width(80)
                    Slider({
                      value: this.frameLineWidth,
                      min: 1,
                      max: 10,
                      step: 1,
                    })
                      .layoutWeight(1)
                      .onChange((v: number) => { this.frameLineWidth = v; })
                    Text(this.frameLineWidth.toString())
                      .fontSize(12).fontColor('#555555').width(24)
                  }.width('100%')
                }
                .padding({ left: 16, right: 16 })
              }
            }.tabBar(getAppString('dlg_axes_tab_frame'))
          }
          .layoutWeight(1)
          .width('100%')
          .barMode(BarMode.Scrollable)

          if (this.statusMsg) {
            Text(this.statusMsg)
              .fontSize(11)
              .fontColor('#CC3333')
              .margin({ top: 4 })
              .padding({ left: 16, right: 16 })
          }

          // Bottom buttons: Apply / OK / Cancel
          Row() {
            Button(getAppString('common_cancel'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('common_apply'))
              .fontSize(14).height(32)
              .backgroundColor('#F8F8F8').fontColor('#333333').borderRadius(4)
              .border({ width: 1, color: '#E0E0E0' })
              .margin({ left: 8 })
              .onClick(() => { this.onApply(); })
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 8 })
              .onClick(() => { this.onOk(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: 8 })
          .justifyContent(FlexAlign.End)
        }
        .width(420)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}

// Response types for getAxisConfig
interface AxisConfigData {
  from: number;
  to: number;
  scaleType: string;
  inverted: boolean;
  title: string;
  visible: boolean;
  majorGrid: boolean;
  minorGrid: boolean;
  backbones: boolean;
  lineWidth: number;
}

interface AxisConfigResponse {
  success: boolean;
  data?: AxisConfigData;
  error?: string;
}
