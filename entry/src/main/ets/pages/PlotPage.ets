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

interface GraphCurveData {
  graphIdx: number;
  curves: CurveData[];
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
  @State graphCurveDataList: GraphCurveData[] = [];
  @State isLoading: boolean = false;
  @State currentPlot: PlotInfo | null = null;
  @State currentGraph: GraphInfo | null = null;
  @StorageProp('pendingPlotListRefresh') @Watch('onPendingPlotListRefreshChange') pendingPlotListRefresh: string = '';
  @State showAllGraphs: boolean = false;
  private lastRefreshTime: number = 0;

  aboutToAppear(): void {
    this.loadPlotList();
  }

  onPendingPlotListRefreshChange(): void {
    if (this.pendingPlotListRefresh === '') return;
    this.debouncedRefreshPlotList();
  }

  private debouncedRefreshPlotList(): void {
    const now: number = Date.now();
    if (now - this.lastRefreshTime < 500) return;
    this.lastRefreshTime = now;
    hilog.info(DOMAIN, TAG, 'Auto-refresh plot list');
    this.loadPlotList();
  }

  loadPlotList(): void {
    try {
      let injector = qohos as QohosInjector;
      let result = injector.callQtCommand('getPlotList', '{}');
      hilog.info(DOMAIN, TAG, 'PlotPage getPlotList: %{public}s', result);
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
      hilog.error(DOMAIN, TAG, 'PlotPage parse error: %{public}s', (e as Error).message);
    }
  }

  onPlotSelected(): void {
    // Find the selected plot
    let plot = this.plotList.find(p => p.name === this.selectedPlotName);
    if (!plot || plot.graphs.length === 0) {
      this.curveDataList = [];
      this.graphCurveDataList = [];
      this.currentPlot = null;
      this.currentGraph = null;
      return;
    }
    this.currentPlot = plot;
    this.selectedGraphIdx = 0;
    this.showAllGraphs = false;
    
    // Initialize curve selection for current graph
    this.selectedCurveIdxs = [];
    if (plot.graphs.length > 0) {
      this.selectedCurveIdxs = plot.graphs[0].curveNames.map((_, idx) => idx);
    }
    
    // Reset and prepare to load ALL graphs' curves
    this.graphCurveDataList = [];
    
    // Load curves for each graph in the plot
    hilog.info(DOMAIN, TAG, 'onPlotSelected: loading %{public}d graphs', plot.graphs.length);
    for (let gi = 0; gi < plot.graphs.length; gi++) {
      let graph = plot.graphs[gi];
      let graphCurves: CurveData[] = [];
      
      // Load all curves for this graph
      try {
        let injector = qohos as QohosInjector;
        let args = JSON.stringify({
          plotId: this.selectedPlotName,
          graphIdx: gi,
          curveIdx: 0
        });
        // First call to get number of curves
        let result = injector.callQtCommand('getPlotData', args);
        let parsed = JSON.parse(result) as PlotDataResponse;
        if (parsed.success && parsed.data) {
          let numCurves = graph.curves;
          for (let ci = 0; ci < numCurves; ci++) {
            let curveArgs = JSON.stringify({
              plotId: this.selectedPlotName,
              graphIdx: gi,
              curveIdx: ci
            });
            let curveResult = injector.callQtCommand('getPlotData', curveArgs);
            let curveParsed = JSON.parse(curveResult) as PlotDataResponse;
            if (curveParsed.success && curveParsed.data) {
              graphCurves.push(curveParsed.data);
            }
          }
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to load curves for graph %{public}s: %{public}s', 
          (e as Error).message);
      }
      
      this.graphCurveDataList.push({
        graphIdx: gi,
        curves: graphCurves
      });
    }
    
    // Initialize curveDataList with only the first graph's curves for single-graph view
    if (this.graphCurveDataList.length > 0) {
      this.curveDataList = this.graphCurveDataList[0].curves.slice();
    } else {
      this.curveDataList = [];
    }
    
    this.currentGraph = plot.graphs[this.selectedGraphIdx];
  }

  loadCurveData(): void {
    if (!this.selectedPlotName) return;
    this.isLoading = true;

    // For now, use pre-loadded data during onPlotSelected
    // This maintains full backward compatibility while supporting multi-graph
    this.isLoading = false;
  }

  onGraphSwitch(graphIdx: number): void {
    this.selectedGraphIdx = graphIdx;
    this.showAllGraphs = false;
    let plot = this.plotList.find(p => p.name === this.selectedPlotName);
    if (plot && plot.graphs[graphIdx]) {
      let graph = plot.graphs[graphIdx];
      this.selectedCurveIdxs = graph.curveNames.map((_, idx) => idx);
      this.currentGraph = graph;
      
      // Get only curves for the selected graph
      let targetGraphData = this.graphCurveDataList.find(gcd => gcd.graphIdx === graphIdx);
      if (targetGraphData) {
        this.curveDataList = targetGraphData.curves;
      }
    }
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
    
    // Get only visible curves for the current graph
    let targetGraphData = this.graphCurveDataList.find(gcd => gcd.graphIdx === this.selectedGraphIdx);
    if (!targetGraphData) return;
    
    // Filter curve data based on selection
    this.curveDataList = [];
    for (let ci of this.selectedCurveIdxs) {
      let curve = targetGraphData.curves[ci];
      if (curve) {
        this.curveDataList.push(curve);
      }
    }
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

      // --- Graph layer selector (only when multiple layers exist) ---
      if (this.currentPlot && this.currentPlot.graphs.length > 1) {
        Row() {
          Text('All')
            .fontSize(11)
            .fontColor(this.showAllGraphs ? '#FFFFFF' : '#666666')
            .fontWeight(this.showAllGraphs ? FontWeight.Bold : FontWeight.Normal)
            .backgroundColor(this.showAllGraphs ? '#0078D7' : '#F0F0F0')
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 2, bottom: 2 })
            .onClick(() => {
              this.showAllGraphs = true;
            })

          Scroll() {
            Row() {
              ForEach(this.currentPlot.graphs, (graph: GraphInfo) => {
                Text('Layer ' + (graph.graphIdx + 1))
                  .fontSize(11)
                  .fontColor((!this.showAllGraphs && graph.graphIdx === this.selectedGraphIdx) ? '#FFFFFF' : '#666666')
                  .fontWeight((!this.showAllGraphs && graph.graphIdx === this.selectedGraphIdx) ? FontWeight.Bold : FontWeight.Normal)
                  .backgroundColor((!this.showAllGraphs && graph.graphIdx === this.selectedGraphIdx) ? '#0078D7' : '#F0F0F0')
                  .borderRadius(10)
                  .padding({ left: 10, right: 10, top: 2, bottom: 2 })
                  .margin({ left: 4 })
                  .onClick(() => {
                    this.showAllGraphs = false;
                    this.onGraphSwitch(graph.graphIdx);
                  })
              }, (graph: GraphInfo) => graph.graphIdx.toString())
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height(30)
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor('#FAFAFA')
        .alignItems(VerticalAlign.Center)
        .border({ width: { bottom: 1 }, color: '#E8E8E8' })
      }

      // --- Canvas area (fills remaining space) ---
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
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.isLoading) {
        Column() {
          Text($r('app.string.common_loading'))
            .fontSize(16)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.showAllGraphs && this.currentPlot && this.currentPlot.graphs.length > 1) {
        // Stacked multi-layer view —independent canvas per graph
        Scroll() {
          Column() {
            ForEach(this.graphCurveDataList, (gcd: GraphCurveData) => {
              PlotCanvas({
                plotTitle: this.selectedPlotName + ' - Layer ' + (gcd.graphIdx + 1),
                curves: gcd.curves,
                graphIdx: gcd.graphIdx
              })
              .width('100%')
              .height(320)
            }, (gcd: GraphCurveData) => gcd.graphIdx.toString())
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        // Single graph view
        PlotCanvas({
          plotTitle: this.selectedPlotName + ' - Layer ' + (this.selectedGraphIdx + 1),
          curves: this.curveDataList,
          graphIdx: this.selectedGraphIdx
        })
        .layoutWeight(1)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}