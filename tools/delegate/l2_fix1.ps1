# L2 fix1: T2/T3 C++ — new_project in-place reset + close-confirmation guards (GLM-5.1).
# cwd = repo root so the agent can read both ohos/ and scidavis/ trees.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：修改 Qt C++ 文件 ohos/tools/qt_src_staging/main.cpp，共 3 处改动。这是 OHPlot（SciDAVis 的 OpenHarmony 移植）的入口文件。只改这一个文件，不要读或改仓库其他目录。

背景（务必理解）：本移植使用单窗口 QPA 插件，任何第二个顶层窗口（QDialog/QMessageBox/新 ApplicationWindow）都会 SIGSEGV。全局主窗口指针是 g_mainWindow（ApplicationWindow*）。

可直接使用的 API（无需读头文件，按此签名用）：
- QList<MyWidget *> ApplicationWindow::windowsList();  // 项目中全部 MDI 子窗口
- void MyWidget::askOnCloseEvent(bool ask);            // 公有内联，false=关闭时不弹确认框
- QString ApplicationWindow::projectname;              // 公有成员
- Table * ApplicationWindow::newTable();               // 公有
- void ApplicationWindow::savedProject();              // 公有槽，清除未保存标记
- void ApplicationWindow::closeActiveWindow();         // 公有槽
- bool 公有成员：confirmCloseTable, confirmCloseMatrix, confirmClosePlot2D, confirmClosePlot3D, confirmCloseFolder, confirmCloseNotes
- void scidavisEmitEvent(const QString &type, const QJsonObject &payload);  // 本文件已有，向 ArkTS 发事件

改动 1（menuAction 的 new_project 分支）：找到 commandRegistry() 中 "menuAction" 命令里的
    else if (itemId == "new_project")
        g_mainWindow->newProject();
替换为一个花括号块：newProject() 会 new 第二个 ApplicationWindow 导致崩溃，改为就地清空——遍历 g_mainWindow->windowsList()，对每个 w 先 w->askOnCloseEvent(false) 再 w->close()；然后 g_mainWindow->projectname = "untitled"; g_mainWindow->newTable(); g_mainWindow->savedProject();；最后构造 QJsonObject p，p["title"]=QObject::tr("New Project")、p["text"]=QObject::tr("Project cleared")、p["icon"]=QStringLiteral("information")，调 scidavisEmitEvent(QStringLiteral("message"), p); 通知 ArkTS 完成。块前加简短英文注释说明为什么不能调 newProject()（second top-level window -> SIGSEGV）。

改动 2（close_window 分支兜底）：同一个 "menuAction" 命令里的
    else if (itemId == "close_window")
        g_mainWindow->closeActiveWindow();
替换为花括号块：先遍历 g_mainWindow->windowsList() 对每个 w 调 w->askOnCloseEvent(false)，再 g_mainWindow->closeActiveWindow();。加一行英文注释（never let the close path pop a QMessageBox）。

改动 3（main() 全局关闭确认开关）：main() 函数里已有这段代码：
        for (QToolBar *tb : mw->findChildren<QToolBar *>())
            tb->hide();
在这段之后、mw->newTable(); 之前，插入 6 行：把 mw->confirmCloseTable / confirmCloseMatrix / confirmClosePlot2D / confirmClosePlot3D / confirmCloseFolder / confirmCloseNotes 全部置 false，并加简短英文注释（single-window QPA cannot show the "Save changes?" QMessageBox）。注意必须在 applyUserSettings() 之后（它会从设置覆盖这些开关）。

风格要求：与文件现有代码一致（4 空格缩进、menuAction 内其他分支的写法、英文注释）。不要动其他任何分支或函数。完成后回复 done 并简述 3 处改动位置。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
