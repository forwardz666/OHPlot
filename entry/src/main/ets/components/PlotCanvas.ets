// ArkSciDAVis PlotCanvas Component
// 2D scientific plot renderer using ArkUI Canvas.
// Renders axes, grid, and curve data from the Qt backend.
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface CurveData {
  title: string;
  points: number;
  x: number[];
  y: number[];
  xColumn?: string;
  yColumn?: string;
}

interface PlotCurveStyle {
  color: string;
  width: number;
}

const CURVE_COLORS: string[] = [
  '#E6194B', '#3CB44B', '#4363D8', '#F58231', '#911EB4',
  '#42D4F4', '#F032E6', '#BFEF45', '#FABED4', '#469990'
];

interface PlotDataRange {
  xMin: number;
  xMax: number;
  yMin: number;
  yMax: number;
}

interface PlotMargin {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

@Component
export struct PlotCanvas {
  @Prop plotTitle: string = '';
  @Prop curves: CurveData[] = [];
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'PlotCanvas aboutToAppear: %{public}s, %{public}d curves',
      this.plotTitle, this.curves.length);
  }

  // Compute axis ranges from curve data
  getDataRange(): PlotDataRange {
    let xMin = Infinity, xMax = -Infinity, yMin = Infinity, yMax = -Infinity;
    for (let curve of this.curves) {
      for (let x of curve.x) {
        if (x < xMin) xMin = x;
        if (x > xMax) xMax = x;
      }
      for (let y of curve.y) {
        if (y < yMin) yMin = y;
        if (y > yMax) yMax = y;
      }
    }
    if (xMin === Infinity) { xMin = 0; xMax = 1; }
    if (yMin === Infinity) { yMin = 0; yMax = 1; }
    // Add 10% padding
    let xPad = (xMax - xMin) * 0.1 || 1.0;
    let yPad = (yMax - yMin) * 0.1 || 1.0;
    return { xMin: xMin - xPad, xMax: xMax + xPad, yMin: yMin - yPad, yMax: yMax + yPad };
  }

  // Map data coordinates to canvas pixel coordinates
  mapX(x: number, range: PlotDataRange, plotW: number, margin: number): number {
    return margin + ((x - range.xMin) / (range.xMax - range.xMin)) * plotW;
  }
  mapY(y: number, range: PlotDataRange, plotH: number, margin: number): number {
    return margin + ((range.yMax - y) / (range.yMax - range.yMin)) * plotH;
  }

  onDraw(canvasW: number, canvasH: number): void {
    let ctx = this.canvasCtx;
    let margin: PlotMargin = { top: 20, right: 20, bottom: 40, left: 55 };
    let plotW = canvasW - margin.left - margin.right;
    let plotH = canvasH - margin.top - margin.bottom;

    if (plotW < 10 || plotH < 10 || this.curves.length === 0) {
      // Not enough space or no data - draw placeholder
      ctx.clearRect(0, 0, canvasW, canvasH);
      ctx.fillStyle = '#FAFAFA';
      ctx.fillRect(0, 0, canvasW, canvasH);
      ctx.fillStyle = '#999999';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(this.curves.length === 0 ? 'No plot data' : 'Plot area too small',
        canvasW / 2, canvasH / 2);
      return;
    }

    // Compute data range
    let range = this.getDataRange();

    // Clear canvas
    ctx.clearRect(0, 0, canvasW, canvasH);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, canvasW, canvasH);

    // --- Draw grid ---
    ctx.strokeStyle = '#E8E8E8';
    ctx.lineWidth = 0.5;
    let nGridX = Math.min(10, Math.floor(plotW / 60));
    let nGridY = Math.min(8, Math.floor(plotH / 50));
    for (let i = 0; i <= nGridX; i++) {
      let x = margin.left + (i / nGridX) * plotW;
      ctx.beginPath();
      ctx.moveTo(x, margin.top);
      ctx.lineTo(x, margin.top + plotH);
      ctx.stroke();
    }
    for (let i = 0; i <= nGridY; i++) {
      let y = margin.top + (i / nGridY) * plotH;
      ctx.beginPath();
      ctx.moveTo(margin.left, y);
      ctx.lineTo(margin.left + plotW, y);
      ctx.stroke();
    }

    // --- Draw axes ---
    ctx.strokeStyle = '#333333';
    ctx.lineWidth = 1.0;
    ctx.beginPath();
    ctx.moveTo(margin.left, margin.top);
    ctx.lineTo(margin.left, margin.top + plotH);
    ctx.lineTo(margin.left + plotW, margin.top + plotH);
    ctx.stroke();

    // --- Draw axis labels ---
    ctx.fillStyle = '#666666';
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    for (let i = 0; i <= nGridX; i++) {
      let xVal = range.xMin + (i / nGridX) * (range.xMax - range.xMin);
      let x = margin.left + (i / nGridX) * plotW;
      let label = xVal.toFixed(2);
      if (Math.abs(xVal) < 1e-10) label = '0';
      else if (Math.abs(xVal) >= 100) label = xVal.toFixed(0);
      ctx.fillText(label, x, margin.top + plotH + 4);
    }
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    for (let i = 0; i <= nGridY; i++) {
      let yVal = range.yMax - (i / nGridY) * (range.yMax - range.yMin);
      let y = margin.top + (i / nGridY) * plotH;
      let label = yVal.toFixed(2);
      if (Math.abs(yVal) < 1e-10) label = '0';
      else if (Math.abs(yVal) >= 100) label = yVal.toFixed(0);
      ctx.fillText(label, margin.left - 5, y);
    }

    // --- Draw X/Y axis titles ---
    ctx.fillStyle = '#333333';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    if (this.curves[0] && this.curves[0].xColumn) {
      ctx.fillText(this.curves[0].xColumn, margin.left + plotW / 2, canvasH - 18);
    }
    ctx.save();
    ctx.translate(14, margin.top + plotH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    if (this.curves[0] && this.curves[0].yColumn) {
      ctx.fillText(this.curves[0].yColumn, 0, 0);
    }
    ctx.restore();

    // --- Draw plot title ---
    if (this.plotTitle) {
      ctx.fillStyle = '#222222';
      ctx.font = 'bold 13px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(this.plotTitle, canvasW / 2, 2);
    }

    // --- Draw curves ---
    for (let ci = 0; ci < this.curves.length; ci++) {
      let curve = this.curves[ci];
      let color = CURVE_COLORS[ci % CURVE_COLORS.length];
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let first = true;
      for (let i = 0; i < curve.x.length; i++) {
        let sx = this.mapX(curve.x[i], range, plotW, margin.left);
        let sy = this.mapY(curve.y[i], range, plotH, margin.top);
        if (first) {
          ctx.moveTo(sx, sy);
          first = false;
        } else {
          ctx.lineTo(sx, sy);
        }
      }
      ctx.stroke();

      // Draw markers for scatter-like visuals (first 50 points or all if <= 50)
      let markerCount = Math.min(curve.x.length, 50);
      if (markerCount > 0 && curve.x.length <= 200) {
        ctx.fillStyle = color;
        let step = Math.max(1, Math.floor(curve.x.length / markerCount));
        for (let i = 0; i < curve.x.length; i += step) {
          let sx = this.mapX(curve.x[i], range, plotW, margin.left);
          let sy = this.mapY(curve.y[i], range, plotH, margin.top);
          ctx.beginPath();
          ctx.arc(sx, sy, 3, 0, 2 * Math.PI);
          ctx.fill();
        }
      }
    }

    // --- Draw legend ---
    if (this.curves.length > 1) {
      let legendX = margin.left + plotW - 10;
      let legendY = margin.top + 5;
      for (let ci = 0; ci < this.curves.length; ci++) {
        let color = CURVE_COLORS[ci % CURVE_COLORS.length];
        let lh = 18;
        let lw = 120;
        let itemY = legendY + ci * lh;
        // Background
        ctx.fillStyle = 'rgba(255,255,255,0.85)';
        ctx.fillRect(legendX - lw, itemY, lw, lh - 2);
        // Line
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(legendX - lw + 4, itemY + lh / 2 - 1);
        ctx.lineTo(legendX - lw + 24, itemY + lh / 2 - 1);
        ctx.stroke();
        // Marker
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(legendX - lw + 14, itemY + lh / 2 - 1, 3, 0, 2 * Math.PI);
        ctx.fill();
        // Text
        ctx.fillStyle = '#333333';
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillText(this.curves[ci].title, legendX - lw + 28, itemY + lh / 2 - 1);
      }
    } else if (this.curves.length === 1) {
      // Single curve legend - just show the title
      ctx.fillStyle = '#666666';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'right';
      ctx.textBaseline = 'top';
      ctx.fillText(this.curves[0].title, canvasW - 10, margin.top + 4);
    }
  }

  build() {
    Canvas(this.canvasCtx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        hilog.info(DOMAIN, TAG, 'PlotCanvas onReady');
      })
      .onAreaChange((oldVal: Area, newVal: Area) => {
        let w = newVal.width as number;
        let h = newVal.height as number;
        if (w && h) {
          this.onDraw(w, h);
        }
      })
  }
}
