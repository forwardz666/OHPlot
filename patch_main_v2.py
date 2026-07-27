import re

with open('C:/Users/Forwardz/scidavis-ohos/scidavis/scidavis/src/main.cpp', 'r', encoding='utf-8') as f:
    content = f.read()

# Step 1: Add includes
old1 = '#include <QJsonObject>\n\n#include <typeinfo>'
new1 = '#include <QJsonObject>\n#include "MultiLayer.h"\n#include "Graph.h"\n#include "PlotCurve.h"\n#include <qwt_data.h>\n\n#include <typeinfo>'
assert old1 in content, "Step 1: old string not found"
content = content.replace(old1, new1, 1)
print("Step 1 OK")

# Step 2: Add plot helper functions after g_mainWindow declaration
old2 = 'static ApplicationWindow *g_mainWindow = nullptr;\n\nstatic std::string tableListJson()'
new2_lines = []
new2_lines.append('static ApplicationWindow *g_mainWindow = nullptr;')
new2_lines.append('')
new2_lines.append('// --- Plot helper functions ------------------------------------------------')
new2_lines.append('static std::string plotListJson()')
new2_lines.append('{')
new2_lines.append('    if (!g_mainWindow) return "[]";')
new2_lines.append('    QJsonArray plots;')
new2_lines.append('    QList<MyWidget *> windows = g_mainWindow->windowsList();')
new2_lines.append('    for (MyWidget *w : windows) {')
new2_lines.append('        if (!w->inherits("MultiLayer")) continue;')
new2_lines.append('        MultiLayer *ml = static_cast<MultiLayer *>(w);')
new2_lines.append('        QJsonObject plotObj;')
new2_lines.append('        plotObj["name"] = ml->name();')
new2_lines.append('        plotObj["label"] = ml->windowLabel();')
new2_lines.append('        plotObj["layers"] = ml->layers();')
new2_lines.append('        QJsonArray graphs;')
new2_lines.append('        QWidgetList gList = ml->graphPtrs();')
new2_lines.append('        for (QWidget *gw : gList) {')
new2_lines.append('            Graph *g = qobject_cast<Graph *>(gw);')
new2_lines.append('            if (!g) continue;')
new2_lines.append('            QJsonObject gObj;')
new2_lines.append('            gObj["curves"] = g->curves();')
new2_lines.append('            QJsonArray curveNames;')
new2_lines.append('            for (int i = 0; i < g->curves(); i++) {')
new2_lines.append('                QwtPlotCurve *pc = g->curve(i);')
new2_lines.append('                if (pc) curveNames.append(pc->title().text());')
new2_lines.append('            }')
new2_lines.append('            gObj["curveNames"] = curveNames;')
new2_lines.append('            graphs.append(gObj);')
new2_lines.append('        }')
new2_lines.append('        plotObj["graphs"] = graphs;')
new2_lines.append('        plots.append(plotObj);')
new2_lines.append('    }')
new2_lines.append('    return QJsonDocument(plots).toJson(QJsonDocument::Compact).toStdString();')
new2_lines.append('}')
new2_lines.append('')
new2_lines.append('static std::string plotDataJson(const QString &plotName, int graphIdx, int curveIdx)')
new2_lines.append('{')
new2_lines.append('    if (!g_mainWindow) return "[]";')
new2_lines.append('    QList<MyWidget *> windows = g_mainWindow->windowsList();')
new2_lines.append('    for (MyWidget *w : windows) {')
new2_lines.append('        if (!w->inherits("MultiLayer")) continue;')
new2_lines.append('        MultiLayer *ml = static_cast<MultiLayer *>(w);')
new2_lines.append('        if (ml->name() != plotName) continue;')
new2_lines.append('        QWidgetList gList = ml->graphPtrs();')
new2_lines.append('        if (graphIdx < 0 || graphIdx >= gList.size()) return "[]";')
new2_lines.append('        Graph *g = qobject_cast<Graph *>(gList[graphIdx]);')
new2_lines.append('        if (!g || curveIdx < 0 || curveIdx >= g->curves()) return "[]";')
new2_lines.append('        QwtPlotCurve *pc = g->curve(curveIdx);')
new2_lines.append('        if (!pc) return "[]";')
new2_lines.append('        const QwtData &d = pc->data();')
new2_lines.append('        size_t n = d.size();')
new2_lines.append('        QJsonObject root;')
new2_lines.append('        root["title"] = pc->title().text();')
new2_lines.append('        root["points"] = static_cast<int>(n);')
new2_lines.append('        QJsonArray xArr, yArr;')
new2_lines.append('        for (size_t i = 0; i < n; i++) {')
new2_lines.append('            xArr.append(d.x(i));')
new2_lines.append('            yArr.append(d.y(i));')
new2_lines.append('        }')
new2_lines.append('        root["x"] = xArr;')
new2_lines.append('        root["y"] = yArr;')
new2_lines.append('        DataCurve *dc = dynamic_cast<DataCurve *>(pc);')
new2_lines.append('        if (dc) {')
new2_lines.append('            root["xColumn"] = dc->xColumnName();')
new2_lines.append('            root["yColumn"] = dc->yColumnName();')
new2_lines.append('        }')
new2_lines.append('        return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();')
new2_lines.append('    }')
new2_lines.append('    return "[]";')
new2_lines.append('}')
new2_lines.append('')
new2_lines.append(old2)

new2 = '\n'.join(new2_lines)
assert old2 in content, "Step 2: old string not found"
content = content.replace(old2, new2, 1)
print("Step 2 OK")

# Step 3: Add new command branches in scidavis_call
old3 = '''        } else {
            s_result = "{\\"success\\":false,\\"error\\":\\"unknown cmd: ";
            s_result += cmdStr;
            s_result += "\\"}";'''

new3_cmds = '''
        } else if (cmdStr == "getPlotList") {
            std::string plots = plotListJson();
            s_result = "{\\"success\\":true,\\"data\\":" + plots + "}";
        } else if (cmdStr == "getPlotData") {
            QString plotName = argsObj["plotId"].toString();
            int graphIdx = argsObj["graphIdx"].toInt();
            int curveIdx = argsObj["curveIdx"].toInt();
            std::string data = plotDataJson(plotName, graphIdx, curveIdx);
            s_result = "{\\"success\\":true,\\"data\\":" + data + "}";
        } else if (cmdStr == "setCellValue") {
            QString tableName = argsObj["tableId"].toString();
            int row = argsObj["row"].toInt();
            int col = argsObj["col"].toInt();
            QString value = argsObj["value"].toString();
            if (g_mainWindow) {
                Table *t = g_mainWindow->table(tableName);
                if (t && row >= 0 && row < t->rowCount() && col >= 0 && col < t->columnCount()) {
                    t->setText(row, col, value);
                    s_result = "{\\"success\\":true}";
                } else {
                    s_result = "{\\"success\\":false,\\"error\\":\\"invalid cell\\"}";
                }
            } else {
                s_result = "{\\"success\\":false,\\"error\\":\\"no mw\\"}";
            }
        } else {
            s_result = "{\\"success\\":false,\\"error\\":\\"unknown cmd: ";
            s_result += cmdStr;
            s_result += "\\"}";'''

assert old3 in content, "Step 3: old string not found"
content = content.replace(old3, new3_cmds, 1)
print("Step 3 OK")

with open('C:/Users/Forwardz/scidavis-ohos/scidavis/scidavis/src/main.cpp', 'w', encoding='utf-8') as f:
    f.write(content)
print('All done, new length:', len(content))
