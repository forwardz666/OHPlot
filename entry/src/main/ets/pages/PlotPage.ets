// ArkSciDAVis Plot Page
// Displays 2D plots loaded from the Qt backend.
// Uses PlotCanvas for rendering and callQtCommand for data access.
import { PlotCanvas } from '../components/PlotCanvas';
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface CurveInfo {
  curveIdx: number;
  title: string;
}

interface GraphInfo {
  graphIdx: number;
  curves: number;
  curveNames: string[];
}

interface PlotInfo {
  name: string;
  label: string;
  layers: number;
  graphs: GraphInfo[];
}

interface CurveData {
  title: string;
  points: number;
  x: number[];
  y: number[];
  xColumn?: string;
  yColumn?: string;
}

interface PlotListResponse {
  success: boolean;
  data?: PlotInfo[];
  error?: string;
}

interface PlotDataResponse {
  success: boolean;
  data?: CurveData;
  error?: string;
}

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

@Component
export struct PlotPage {
  @State plotList: PlotInfo[] = [];
  @State selectedPlotName: string = '';
  @State selectedGraphIdx: number = 0;
  @State selectedCurveIdxs: number[] = [];
  @State curveDataList: CurveData[] = [];
  @State isLoading: boolean = false;
  @State currentPlot: PlotInfo | null = null;
  @State currentGraph: GraphInfo | null = null;

  aboutToAppear(): void {
    this.loadPlotList();
  }

  loadPlotList(): void {
    let injector = qohos as QohosInjector;
    let result = injector.callQtCommand('getPlotList', '{}');
    hilog.info(DOMAIN, TAG, 'PlotPage getPlotList: %{public}s', result);
    try {
      let parsed = JSON.parse(result) as PlotListResponse;
      if (parsed.success && parsed.data && parsed.data.length > 0) {
        this.plotList = parsed.data;
        if (!this.selectedPlotName) {
          this.selectedPlotName = parsed.data[0].name;
          this.onPlotSelected();
        }
      } else {
        this.plotList = [];
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'PlotPage parse error: %{public}s', JSON.stringify(e));
    }
  }

  onPlotSelected(): void {
    // Find the selected plot
    let plot = this.plotList.find(p => p.name === this.selectedPlotName);
    if (!plot || plot.graphs.length === 0) {
      this.curveDataList = [];
      this.currentPlot = null;
      this.currentGraph = null;
      return;
    }
    this.currentPlot = plot;
    this.currentGraph = plot.graphs[0];
    this.selectedGraphIdx = 0;
    this.selectedCurveIdxs = [];

    // Load all curves from the first graph
    this.selectedCurveIdxs = plot.graphs[0].curveNames.map((_, idx) => idx);
    this.loadCurveData();
  }

  loadCurveData(): void {
    if (!this.selectedPlotName) return;
    this.isLoading = true;
    this.curveDataList = [];
    let injector = qohos as QohosInjector;

    let plot = this.plotList.find(p => p.name === this.selectedPlotName);
    if (!plot || !plot.graphs[this.selectedGraphIdx]) {
      this.isLoading = false;
      return;
    }

    let graph = plot.graphs[this.selectedGraphIdx];
    for (let ci of this.selectedCurveIdxs) {
      if (ci < 0 || ci >= graph.curves) continue;
      let args = JSON.stringify({
        plotId: this.selectedPlotName,
        graphIdx: this.selectedGraphIdx,
        curveIdx: ci
      });
      let result = injector.callQtCommand('getPlotData', args);
      try {
        let parsed = JSON.parse(result) as PlotDataResponse;
        if (parsed.success && parsed.data) {
          this.curveDataList.push(parsed.data);
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'PlotData parse error: %{public}s', JSON.stringify(e));
      }
    }
    this.isLoading = false;
  }

  onCurveToggle(curveIdx: number): void {
    let idx = this.selectedCurveIdxs.indexOf(curveIdx);
    if (idx >= 0) {
      this.selectedCurveIdxs.splice(idx, 1);
    } else {
      this.selectedCurveIdxs.push(curveIdx);
    }
    // Re-sort
    this.selectedCurveIdxs.sort((a, b) => a - b);
    this.loadCurveData();
  }

  build() {
    Column() {
      // --- Toolbar ---
      Row() {
        Text($r('app.string.panel_plots'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        if (this.plotList.length > 0) {
          // Plot selector
          Scroll() {
            Row() {
              ForEach(this.plotList, (plot: PlotInfo) => {
                Text(plot.name)
                  .fontSize(12)
                  .fontColor(plot.name === this.selectedPlotName ? '#0078D7' : '#666666')
                  .fontWeight(plot.name === this.selectedPlotName ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 8, right: 8 })
                  .onClick(() => {
                    this.selectedPlotName = plot.name;
                    this.onPlotSelected();
                  })
              }, (plot: PlotInfo) => plot.name)
            }
          }
          .layoutWeight(1)
          .height(28)
        }
        Button($r('app.string.common_refresh'))
          .fontSize(12)
          .height(28)
          .onClick(() => {
            this.loadPlotList();
          })
      }
      .width('100%')
      .height(36)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#F8F8F8')
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 1 }, color: '#E0E0E0' })

      if (this.plotList.length === 0 && !this.isLoading) {
        // Empty state
        Column() {
          Text($r('app.string.common_no_plots'))
            .fontSize(16)
            .fontColor('#999999')
          Text($r('app.string.page_create_plot_hint'))
            .fontSize(12)
            .fontColor('#BBBBBB')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.isLoading) {
        Column() {
          Text($r('app.string.common_loading'))
            .fontSize(16)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // Plot canvas area
        Row() {
          // Main plot area
          PlotCanvas({
            plotTitle: this.selectedPlotName + ' - Graph ' + (this.selectedGraphIdx + 1),
            curves: this.curveDataList
          })
          .layoutWeight(1)
          .height('100%')

          // Curve list sidebar
          if (this.currentGraph) {
            Column() {
              Text($r('app.string.panel_curves'))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .padding({ top: 4, bottom: 4 })
              ForEach(this.currentGraph.curveNames, (name: string, idx: number) => {
                  Row() {
                    Text(this.selectedCurveIdxs.indexOf(idx) >= 0 ? '☑' : '☐')
                      .fontSize(14)
                      .width(20)
                    Text(name)
                      .fontSize(12)
                      .fontColor('#333333')
                  }
                  .width('100%')
                  .padding({ top: 2, bottom: 2, left: 4 })
                  .onClick(() => this.onCurveToggle(idx))
                }, (name: string, idx: number) => 'c' + idx.toString())
              }
              .width(100)
              .height('100%')
              .padding({ left: 4, right: 4 })
              .backgroundColor('#FAFAFA')
              .border({ width: { left: 1 }, color: '#E0E0E0' })
            }
          }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
