// FormatDialog — "Format" menu Plot/Scales/Axes/Grid/Title dialog (batch 4).
// Four-in-one dialog: section prop switches content area via @Builder methods.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface AxisScaleArgs {
  axis: string;
  from: number;
  to: number;
  log: boolean;
}

interface AxisTitleArgs {
  axis: string;
  title: string;
}

interface AxisGridArgs {
  axis: string;
  visible: boolean;
}

interface GraphTitleArgs {
  title: string;
  fontSize: number;
}

type SectionType = 'plot' | 'scales' | 'axes' | 'grid' | 'title';

const LINE_COLORS: string[] = ['#FF0000', '#00FF00', '#0000FF', '#000000', '#800080', '#FFA500'];
const LINE_STYLES: string[] = ['solid', 'dashed', 'dotted', 'dash_dot'];
const LINE_WIDTHS: number[] = [1, 2, 3, 4, 5];
const TITLE_FONT_SIZES: number[] = [10, 11, 12, 14, 16, 18, 20, 24];

@Component
export struct FormatDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @Prop section: SectionType = 'plot';

  @State currentSection: SectionType = 'plot';

  // Plot page state
  @State lineColor: string = '#000000';
  @State lineStyle: string = 'solid';
  @State lineWidth: number = 1;

  // Scales page state
  @State xFrom: string = '';
  @State xTo: string = '';
  @State xLog: boolean = false;
  @State yFrom: string = '';
  @State yTo: string = '';
  @State yLog: boolean = false;

  // Axes page state
  @State xAxisTitle: string = '';
  @State yAxisTitle: string = '';

  // Grid page state
  @State xGridVisible: boolean = true;
  @State yGridVisible: boolean = true;

  // Title page state
  @State graphTitle: string = '';
  @State titleFontSize: number = 12;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  private resetDefaults(): void {
    this.currentSection = this.section;
    this.lineColor = '#000000';
    this.lineStyle = 'solid';
    this.lineWidth = 1;
    this.xFrom = '';
    this.xTo = '';
    this.xLog = false;
    this.yFrom = '';
    this.yTo = '';
    this.yLog = false;
    this.xAxisTitle = '';
    this.yAxisTitle = '';
    this.xGridVisible = true;
    this.yGridVisible = true;
    this.graphTitle = '';
    this.titleFontSize = 12;
  }

  private onSectionChange(sec: SectionType): void {
    this.currentSection = sec;
  }

  private onCancel(): void {
    this.isVisible = false;
  }

  private onApply(): void {
    try {
      const injector = qohos as QohosInjector;
      switch (this.currentSection) {
        case 'plot':
          // Plot style prototype - B1 will wire actual command
          hilog.info(DOMAIN, TAG, 'FormatDialog plot apply: color=%{public}s, style=%{public}s, width=%{public}s',
            this.lineColor, this.lineStyle, this.lineWidth.toString());
          break;
        case 'scales':
          this.applyScales(injector);
          break;
        case 'axes':
          this.applyAxes(injector);
          break;
        case 'grid':
          this.applyGrid(injector);
          break;
        case 'title':
          this.applyTitle(injector);
          break;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'FormatDialog apply failed: %{public}s', (e as Error).message);
    }
    this.isVisible = false;
  }

  private applyScales(injector: QohosInjector): void {
    // X axis scale
    if (this.xFrom && this.xTo) {
      try {
        const xArgs: AxisScaleArgs = {
          axis: 'x',
          from: parseFloat(this.xFrom),
          to: parseFloat(this.xTo),
          log: this.xLog
        };
        const result: string = injector.callQtCommand('setAxisScale', JSON.stringify(xArgs));
        hilog.info(DOMAIN, TAG, 'setAxisScale x applied: %{public}s', result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'setAxisScale x failed: %{public}s', (e as Error).message);
      }
    }
    // Y axis scale
    if (this.yFrom && this.yTo) {
      try {
        const yArgs: AxisScaleArgs = {
          axis: 'y',
          from: parseFloat(this.yFrom),
          to: parseFloat(this.yTo),
          log: this.yLog
        };
        const result: string = injector.callQtCommand('setAxisScale', JSON.stringify(yArgs));
        hilog.info(DOMAIN, TAG, 'setAxisScale y applied: %{public}s', result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'setAxisScale y failed: %{public}s', (e as Error).message);
      }
    }
    // TODO: B1 wire actual Qt command names and argument structure
  }

  private applyAxes(injector: QohosInjector): void {
    // X axis title
    if (this.xAxisTitle) {
      try {
        const xArgs: AxisTitleArgs = {
          axis: 'x',
          title: this.xAxisTitle
        };
        const result: string = injector.callQtCommand('setAxisTitle', JSON.stringify(xArgs));
        hilog.info(DOMAIN, TAG, 'setAxisTitle x applied: %{public}s', result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'setAxisTitle x failed: %{public}s', (e as Error).message);
      }
    }
    // Y axis title
    if (this.yAxisTitle) {
      try {
        const yArgs: AxisTitleArgs = {
          axis: 'y',
          title: this.yAxisTitle
        };
        const result: string = injector.callQtCommand('setAxisTitle', JSON.stringify(yArgs));
        hilog.info(DOMAIN, TAG, 'setAxisTitle y applied: %{public}s', result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'setAxisTitle y failed: %{public}s', (e as Error).message);
      }
    }
    // TODO: B1 wire actual Qt command names and argument structure
  }

  private applyGrid(injector: QohosInjector): void {
    // X grid
    try {
      const xArgs: AxisGridArgs = {
        axis: 'x',
        visible: this.xGridVisible
      };
      const result: string = injector.callQtCommand('setAxisGrid', JSON.stringify(xArgs));
      hilog.info(DOMAIN, TAG, 'setAxisGrid x applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setAxisGrid x failed: %{public}s', (e as Error).message);
    }
    // Y grid
    try {
      const yArgs: AxisGridArgs = {
        axis: 'y',
        visible: this.yGridVisible
      };
      const result: string = injector.callQtCommand('setAxisGrid', JSON.stringify(yArgs));
      hilog.info(DOMAIN, TAG, 'setAxisGrid y applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setAxisGrid y failed: %{public}s', (e as Error).message);
    }
    // TODO: B1 wire actual Qt command names and argument structure
  }

  private applyTitle(injector: QohosInjector): void {
    try {
      const args: GraphTitleArgs = {
        title: this.graphTitle,
        fontSize: this.titleFontSize
      };
      const result: string = injector.callQtCommand('setGraphTitle', JSON.stringify(args));
      hilog.info(DOMAIN, TAG, 'setGraphTitle applied: %{public}s', result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setGraphTitle failed: %{public}s', (e as Error).message);
    }
    // TODO: B1 wire actual Qt command names and argument structure
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.BACKDROP_COLOR)
          .onClick(() => { this.isVisible = false; })

        Column() {
          // Section tabs
          Row() {
            this.buildSectionTab('plot', getAppString('format_plot'));
            this.buildSectionTab('scales', getAppString('format_scales'));
            this.buildSectionTab('axes', getAppString('format_axes'));
            this.buildSectionTab('grid', getAppString('format_grid'));
            this.buildSectionTab('title', getAppString('format_title'));
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

          // Content area
          Scroll() {
            if (this.currentSection === 'plot') {
              this.buildPlotPage();
            } else if (this.currentSection === 'scales') {
              this.buildScalesPage();
            } else if (this.currentSection === 'axes') {
              this.buildAxesPage();
            } else if (this.currentSection === 'grid') {
              this.buildGridPage();
            } else {
              this.buildTitlePage();
            }
          }
          .layoutWeight(1)
          .width('100%')

          // Bottom buttons
          Row() {
            Button(getAppString('common_cancel'))
              .fontSize(14).height(Theme.BTN_HEIGHT)
              .backgroundColor(Theme.BTN_BG).fontColor(Theme.BTN_TEXT).borderRadius(Theme.RADIUS_4)
              .onClick(() => { this.onCancel(); })
            Button(getAppString('common_apply'))
              .fontSize(14).height(Theme.BTN_HEIGHT)
              .backgroundColor(Theme.BTN_BG_ACCENT).fontColor(Theme.BTN_TEXT_ACCENT).borderRadius(Theme.RADIUS_4)
              .margin({ left: Theme.BTN_GAP })
              .onClick(() => { this.onApply(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .justifyContent(FlexAlign.End)
        }
        .width(420)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(Theme.RADIUS_8)
        .shadow({ radius: Theme.SHADOW_RADIUS, color: Theme.SHADOW_COLOR, offsetX: Theme.SHADOW_OFFSET_X, offsetY: Theme.SHADOW_OFFSET_Y })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildSectionTab(section: SectionType, label: string): void {
    Text(label)
      .fontSize(12)
      .fontColor(this.currentSection === section ? Theme.ACCENT : Theme.TEXT_MUTED)
      .fontWeight(this.currentSection === section ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.currentSection === section ? '#E0E8F0' : '#F0F0F0')
      .borderRadius(Theme.RADIUS_4)
      .margin({ right: 6 })
      .onClick(() => { this.onSectionChange(section); });
  }

  @Builder
  buildPlotPage(): void {
    Column() {
      Text(getAppString('format_plot'))
        .fontSize(Theme.FS_DIALOG_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: Theme.SPACING_12 })

      // Line color
      Row() {
        Text(getAppString('format_line_color'))
          .fontSize(Theme.FS_DIALOG_LABEL)
          .fontColor(Theme.TEXT_MUTED)
          .width(80)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(LINE_COLORS, (c: string, idx: number) => {
            Row()
              .width(24)
              .height(24)
              .backgroundColor(c)
              .border({
                width: c === this.lineColor ? 2 : 1,
                color: c === this.lineColor ? '#0078D7' : '#D0D0D0'
              })
              .margin(2)
              .onClick(() => { this.lineColor = c; })
          }, (c: string, idx: number) => c + ':' + idx)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_8 })
      .alignItems(VerticalAlign.Top)

      // Line style
      Row() {
        Text(getAppString('format_line_style'))
          .fontSize(Theme.FS_DIALOG_LABEL)
          .fontColor(Theme.TEXT_MUTED)
          .width(80)
        Column() {
          ForEach(LINE_STYLES, (s: string, idx: number) => {
            Text(s)
              .fontSize(Theme.FS_DIALOG_SMALL)
              .fontColor(s === this.lineStyle ? Theme.ACCENT : Theme.TEXT_LIST)
              .fontWeight(s === this.lineStyle ? FontWeight.Bold : FontWeight.Normal)
              .padding({ top: 2, bottom: 2, left: 6 })
              .width('100%')
              .onClick(() => { this.lineStyle = s; })
          }, (s: string, idx: number) => s + ':' + idx)
        }
        .layoutWeight(1)
        .border({ width: 1, color: Theme.PANEL_BORDER })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_8 })
      .alignItems(VerticalAlign.Top)

      // Line width
      Row() {
        Text(getAppString('format_line_width'))
          .fontSize(Theme.FS_DIALOG_LABEL)
          .fontColor(Theme.TEXT_MUTED)
          .width(80)
        Slider({
          value: this.lineWidth,
          min: LINE_WIDTHS[0],
          max: LINE_WIDTHS[LINE_WIDTHS.length - 1],
          step: 1,
          style: SliderStyle.InSet
        })
          .layoutWeight(1)
          .onChange((value: number) => {
            const target: number = Math.round(value);
            for (let i = 0; i < LINE_WIDTHS.length; i++) {
              if (LINE_WIDTHS[i] === target) {
                this.lineWidth = target;
                break;
              }
            }
          })
        Text(this.lineWidth.toString())
          .fontSize(Theme.FS_DIALOG_SMALL)
          .fontColor(Theme.TEXT_MUTED)
          .width(30)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })
      .alignItems(VerticalAlign.Center)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildScalesPage(): void {
    Column() {
      Text(getAppString('format_scales'))
        .fontSize(Theme.FS_DIALOG_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: Theme.SPACING_12 })

      // X axis scale
      Text(getAppString('axis_x')).fontSize(Theme.FS_DIALOG_LABEL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).margin({ bottom: Theme.SPACING_6 })
      
      Row() {
        Text(getAppString('from')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).width(40)
        TextInput({ text: this.xFrom })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width(80)
          .onChange((value: string) => { this.xFrom = value; })
        Text(getAppString('to')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).width(40)
        TextInput({ text: this.xTo })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width(80)
          .onChange((value: string) => { this.xTo = value; })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_4 })

      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.xLog })
          .width(20).height(20)
          .onChange((val: boolean) => { this.xLog = val; })
        Text(getAppString('log_scale')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })

      // Y axis scale
      Text(getAppString('axis_y')).fontSize(Theme.FS_DIALOG_LABEL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).margin({ bottom: Theme.SPACING_6 })

      Row() {
        Text(getAppString('from')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).width(40)
        TextInput({ text: this.yFrom })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width(80)
          .onChange((value: string) => { this.yFrom = value; })
        Text(getAppString('to')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).width(40)
        TextInput({ text: this.yTo })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width(80)
          .onChange((value: string) => { this.yTo = value; })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_4 })

      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.yLog })
          .width(20).height(20)
          .onChange((val: boolean) => { this.yLog = val; })
        Text(getAppString('log_scale')).fontSize(Theme.FS_DIALOG_SMALL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildAxesPage(): void {
    Column() {
      Text(getAppString('format_axes'))
        .fontSize(Theme.FS_DIALOG_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: Theme.SPACING_12 })

      // X axis title
      Text(getAppString('axis_x')).fontSize(Theme.FS_DIALOG_LABEL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).margin({ bottom: Theme.SPACING_6 })
      Row() {
        TextInput({ text: this.xAxisTitle, placeholder: getAppString('dlg_axes_title_ph') })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width('100%')
          .onChange((value: string) => { this.xAxisTitle = value; })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })

      // Y axis title
      Text(getAppString('axis_y')).fontSize(Theme.FS_DIALOG_LABEL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT).margin({ bottom: Theme.SPACING_6 })
      Row() {
        TextInput({ text: this.yAxisTitle, placeholder: getAppString('enter_axis_title') })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width('100%')
          .onChange((value: string) => { this.yAxisTitle = value; })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildGridPage(): void {
    Column() {
      Text(getAppString('format_grid'))
        .fontSize(Theme.FS_DIALOG_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: Theme.SPACING_12 })

      // X grid
      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.xGridVisible })
          .width(20).height(20)
          .onChange((val: boolean) => { this.xGridVisible = val; })
        Text(getAppString('axis_x')).fontSize(Theme.FS_DIALOG_LABEL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
        Text(getAppString('grid')).fontSize(Theme.FS_DIALOG_LABEL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_8 })

      // Y grid
      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.yGridVisible })
          .width(20).height(20)
          .onChange((val: boolean) => { this.yGridVisible = val; })
        Text(getAppString('axis_y')).fontSize(Theme.FS_DIALOG_LABEL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
        Text(getAppString('grid')).fontSize(Theme.FS_DIALOG_LABEL).fontColor(Theme.TEXT_MUTED).margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  buildTitlePage(): void {
    Column() {
      Text(getAppString('format_title'))
        .fontSize(Theme.FS_DIALOG_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: Theme.SPACING_12 })

      // Graph title
      Row() {
        TextInput({ text: this.graphTitle, placeholder: getAppString('dlg_graph_title_ph') })
          .fontSize(Theme.FS_DIALOG_BODY)
          .fontColor(Theme.TEXT)
          .height(Theme.INPUT_HEIGHT)
          .width('100%')
          .onChange((value: string) => { this.graphTitle = value; })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_8 })

      // Title font size
      Row() {
        Text(getAppString('font_size')).fontSize(Theme.FS_DIALOG_LABEL).fontColor(Theme.TEXT_MUTED).width(80)
        Column() {
          ForEach(TITLE_FONT_SIZES, (sz: number, idx: number) => {
            Text(sz.toString())
              .fontSize(Theme.FS_DIALOG_SMALL)
              .fontColor(sz === this.titleFontSize ? Theme.ACCENT : Theme.TEXT_LIST)
              .fontWeight(sz === this.titleFontSize ? FontWeight.Bold : FontWeight.Normal)
              .padding({ top: 2, bottom: 2, left: 6 })
              .width('100%')
              .onClick(() => { this.titleFontSize = sz; })
          }, (sz: number, idx: number) => sz.toString() + ':' + idx)
        }
        .layoutWeight(1)
        .height(80)
        .border({ width: 1, color: Theme.PANEL_BORDER })
      }
      .width('100%')
      .margin({ bottom: Theme.SPACING_12 })
      .alignItems(VerticalAlign.Top)
    }
    .padding({ left: 16, right: 16 })
  }
}
