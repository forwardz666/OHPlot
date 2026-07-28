# L2 T3-A: add getProjectTree command to the C++ command registry (GLM-5.1).
# cwd = repo root so the agent can read both ohos/ and scidavis/ trees.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：在 Qt C++ 文件 ohos/tools/qt_src_staging/main.cpp 中新增一个只读命令 getProjectTree。这是 OHPlot（SciDAVis 的 OpenHarmony 移植）的命令注册表文件。只改这一个文件，不要读或改仓库其他目录。

背景与现有模式（务必遵循）：
1. 命令注册表是 commandRegistry() 返回的 static const std::map<std::string, CommandHandler>，CommandHandler = std::function<std::string(const QJsonObject &)>。新增命令 = 在 map 里加一个条目，lambda 返回 JSON 字符串：成功 "{\"success\":true,\"data\":...}"，失败用已有的 jsonError("...")。
2. 只读命令必须同时加入 queryCommands() 里的 static const std::set<std::string>（当前含 ping/getTableList/getTableData/getPlotList/getPlotData/getUiState/getClipboardText/getGraphCurves），把 "getProjectTree" 追加进去。
3. 全局主窗口指针是 g_mainWindow（ApplicationWindow*），使用前判空。
4. 序列化用 QJsonObject/QJsonArray/QJsonDocument(...).toJson(QJsonDocument::Compact).toStdString()，参考文件里已有的 uiStateJson() 函数写法。

要实现的契约：
- 命令名 "getProjectTree"，无参数。
- 返回 {"success":true,"data":<root>}，其中每个节点为 {"name":string,"type":string,"children":[...]}：
  - 文件夹节点 type 固定 "Folder"，name 用 Folder::name()；
  - 窗口节点 type 用 w->metaObject()->className()（即 Table/Matrix/MultiLayer/Note），name 用 w->name()，children 恒为空数组；
- 根节点是 g_mainWindow->projectFolder()（ApplicationWindow.h 已声明 Folder *projectFolder()）。
- Folder 类 API（无需读头文件，直接按此签名用；文件顶部 #include 区追加 #include "Folder.h"）：
  QString name();                       // 文件夹名
  QList<MyWidget *> windowsList();      // 本文件夹直属窗口
  QList<Folder *> folders() const;      // 子文件夹列表
- MyWidget API：w->name() 返回 QString；w->metaObject()->className() 返回类名。
- 实现方式：在 uiStateJson() 附近新增一个 static 递归辅助函数（如 static QJsonObject projectTreeJson(Folder *f)），先输出该文件夹下每个窗口节点、再递归每个子文件夹，追加到 children。
- g_mainWindow 为空时返回 jsonError("no mw")。

风格要求：与文件现有代码一致（4空格缩进、注释风格、命令条目放在 getUiState 条目附近或 activateWindow 附近均可，注意 map 内条目之间空行分隔的现有格式）。不要动其他命令。完成后回复 done 并简述改动位置。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
