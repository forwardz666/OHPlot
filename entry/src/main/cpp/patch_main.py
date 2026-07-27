import re

with open(r'c:\Users\Forwardz\scidavis-ohos\scidavis\scidavis\src\main.cpp', 'r', encoding='utf-8') as f:
    content = f.read()

# Step 1: Add QJson includes before <QWindow>
old = '#include <QWindow>'

new = '''#include <QWindow>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>'''

content = content.replace(old, new, 1)

# Step 2: Add OHOS_LOG macro after cstdio include
old = '#include <cstdio>'
new = '#include <cstdio>\n#include <string>\n#define OHOS_LOG(fmt, ...) do { fprintf(stderr, "[SciDAVis:%d] " fmt "\\n", __LINE__, ##__VA_ARGS__); fflush(stderr); } while(0)'
content = content.replace(old, new, 1)

# Step 3: Add scidavis_call function and g_mainWindow before main()
old = 'int main(int argc, char **argv)'
new_funcs = '''
// --- NAPI -> Qt command dispatch ------------------------------------------
static ApplicationWindow *g_mainWindow = nullptr;

static std::string tableListJson()
{
    if (!g_mainWindow) return "[]";
    QList<MyWidget *> *tables = g_mainWindow->tableList();
    if (!tables) return "[]";
    QJsonArray arr;
    for (MyWidget *w : *tables) {
        Table *t = qobject_cast<Table *>(w);
        if (!t) continue;
        QJsonObject obj;
        obj["name"] = t->name();
        obj["label"] = t->windowLabel();
        obj["rows"] = t->rowCount();
        obj["cols"] = t->columnCount();
        arr.append(obj);
    }
    return QJsonDocument(arr).toJson(QJsonDocument::Compact).toStdString();
}

static std::string tableDataJson(const QString &tableName)
{
    if (!g_mainWindow) return "[]";
    Table *t = g_mainWindow->table(tableName);
    if (!t) return "[]";
    int rows = t->rowCount();
    int cols = t->columnCount();
    QJsonObject root;
    root["name"] = t->name();
    root["rows"] = rows;
    root["cols"] = cols;
    QJsonArray colNames;
    for (int c = 0; c < cols; c++)
        colNames.append(t->colName(c));
    root["colNames"] = colNames;
    QJsonArray data;
    for (int r = 0; r < rows; r++) {
        QJsonArray row;
        for (int c = 0; c < cols; c++)
            row.append(t->text(r, c));
        data.append(row);
    }
    root["data"] = data;
    return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
}

extern "C" __attribute__((visibility("default")))
const char *scidavis_call(const char *cmd, const char *jsonArgs)
{
    static std::string s_result;

    QCoreApplication *core = QCoreApplication::instance();
    if (!core) {
        s_result = "{\\"success\\":false,\\"error\\":\\"Qt not running\\"}";
        return s_result.c_str();
    }

    QMetaObject::invokeMethod(core, [cmd, jsonArgs]() {
        std::string cmdStr(cmd);
        QJsonDocument doc = QJsonDocument::fromJson(QByteArray(jsonArgs));
        QJsonObject argsObj = doc.object();

        if (cmdStr == "ping") {
            s_result = "{\\"success\\":true,\\"pong\\":true}";
        } else if (cmdStr == "getTableList") {
            std::string tables = tableListJson();
            s_result = "{\\"success\\":true,\\"data\\":" + tables + "}";
        } else if (cmdStr == "getTableData") {
            QString tableName = argsObj["tableId"].toString();
            std::string data = tableDataJson(tableName);
            s_result = "{\\"success\\":true,\\"data\\":" + data + "}";
        } else if (cmdStr == "newTable") {
            if (g_mainWindow) {
                Table *t = g_mainWindow->newTable();
                if (t) {
                    std::string tables = tableListJson();
                    s_result = "{\\"success\\":true,\\"data\\":" + tables + "}";
                } else {
                    s_result = "{\\"success\\":false,\\"error\\":\\"failed\\"}";
                }
            } else {
                s_result = "{\\"success\\":false,\\"error\\":\\"no mw\\"}";
            }
        } else {
            s_result = "{\\"success\\":false,\\"error\\":\\"unknown cmd: ";
            s_result += cmdStr;
            s_result += "\\"}";
        }
    }, Qt::BlockingQueuedConnection);

    return s_result.c_str();
}

int main(int argc, char **argv)'''

content = content.replace(old, new_funcs, 1)

# Step 4: Add g_mainWindow assignment after mw creation
old = 'ApplicationWindow *mw = new ApplicationWindow;'
new = 'ApplicationWindow *mw = new ApplicationWindow;\n        g_mainWindow = mw;'
content = content.replace(old, new, 1)

with open(r'c:\Users\Forwardz\scidavis-ohos\scidavis\scidavis\src\main.cpp', 'w', encoding='utf-8') as f:
    f.write(content)

print('Patch complete')
print(f'New length: {len(content)}')
