# L2 T4-A: add four plot-customization commands to the C++ command registry (GLM-5.1).
# cwd = repo root so the agent can consult scidavis/libscidavis sources.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：在 Qt C++ 文件 ohos/tools/qt_src_staging/main.cpp 的 commandRegistry() 中新增 4 个 mutation 命令：setGraphTitle、setAxisTitle、setAxisScale、toggleLegend。只改这一个文件。

现有模式（务必遵循）：
1. 注册表是 static const std::map<std::string, CommandHandler>，CommandHandler = std::function<std::string(const QJsonObject &)>；lambda 成功返回 "{\"success\":true}"，失败返回 jsonError("...")（已有函数）。
2. 这 4 个是 mutation 命令，【不要】加入 queryCommands()。
3. 定位目标 Graph 的模式（文件里 getGraphCurves 命令已示范）：
   MultiLayer *ml = resolvePlot(args);
   Graph *g = ml ? ml->activeGraph() : nullptr;
   if (!g) return jsonError("no active graph");
4. 放置位置：activateWindow 条目附近或 getGraphCurves 条目之后，保持 map 内条目空行分隔的现有格式与 4 空格缩进。

Graph 类公开 API（scidavis/libscidavis/src/Graph.h，可自行查阅确认签名）：
- void setTitle(const QString &t);
- void setAxisTitle(int axis, const QString &text);   // axis: QwtPlot 轴号 0=yLeft 1=yRight 2=xBottom 3=xTop
- void setScale(int axis, double start, double end, double step = 0.0, int majorTicks = 5, int minorTicks = 5, int type = 0, bool inverted = false);  // type: 0=线性 1=对数
- Plot *plotWidget() const;   // QwtPlot 派生，用 axisScaleDiv(axis) 取当前上下界（Qwt5，参考 scidavis/libscidavis/src/AxesDialog.cpp 里对 axisScaleDiv 的现成用法确定 lBound/hBound 还是 lowerBound/upperBound）
- bool hasLegend(); Legend *newLegend(); void removeLegend();
- void replot();

四个命令的行为契约：
1. "setGraphTitle" 参数 {"title":string}：g->setTitle(args["title"].toString()); 返回 success。
2. "setAxisTitle" 参数 {"axis":int,"text":string}：axis 用 args["axis"].toInt(0)，范围 0..3 越界返回 jsonError("bad axis")；g->setAxisTitle(axis, text)。
3. "setAxisScale" 参数 {"axis":int,"scale":"log"|"linear"}：
   - 从 g->plotWidget()->axisScaleDiv(axis) 读当前 start/end；
   - type = (scale=="log") ? 1 : 0；对数时若 start <= 0 则把 start 钳到 1e-3（对数轴不允许非正下界）；
   - 调 g->setScale(axis, start, end, 0.0, 5, 5, type, false); 然后 g->replot()。
4. "toggleLegend" 无参数：g->hasLegend() ? g->removeLegend() : (void)g->newLegend(); 然后 g->replot(); 返回 success。

每个命令都要先判 g_mainWindow 非空（jsonError("no mw")）再走 resolvePlot 模式。完成后回复 done 并简述插入位置。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
