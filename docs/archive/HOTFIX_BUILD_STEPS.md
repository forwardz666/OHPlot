> **Archived**: This document is a historical diagnostic record from 2026-07-25. The fixes described have been integrated into the main codebase. Retained for reference only.

# SciDAVis QPA 插件加载失败修复 - 构建与验证步骤

## 已完成的代码修改

已修改文件：`entry/src/main/ets/abilitystage/MyAbilityStage.ets`

### 修改内容概览

1. **导入方式改变**：
   - 从 ES6 `import` 改为 `require()` 动态导入
   - 添加备选导入方案（`plugins_platforms_qopenharmony`）
   - 导入时添加错误捕获和日志记录

2. **运行时检查**：
   - 检查 QPA 对象是否加载成功
   - 检查方法是否存在和可调用
   - 所有 QPA API 调用包含 try-catch
   - 添加详细的错误日志

3. **容错增强**：
   - `onAcceptWant` 中的 QPA 调用也添加了检查和异常处理

---

## 构建与验证流程

### 第 1 步：在 DevEco Studio 中清理构建

```
1. 打开 DevEco Studio
2. 导航到项目根目录
3. Build > Clean Build Folder
4. 或直接删除 entry/build 目录（通过文件管理器或终端）
```

**命令行方式**：
```bash
cd c:\Users\Forwardz\scidavis-ohos\ohos
rm -r entry/build  # 或 Remove-Item entry/build -Recurse -Force (PowerShell)
```

### 第 2 步：重新构建 HAP

```
1. DevEco Studio > Build > Build HAP(s)
   或使用快捷键 Ctrl+F9

2. 等待构建完成，观察构建日志输出
   预期看到：
   - ✓ Successfully compiled MyAbilityStage.ets
   - ✓ Packaging HAP file...
   - ✓ Build completed successfully
```

**构建日志检查要点**：
- 无关于 so 文件的错误（ERROR）
- 无关于 native 库加载的警告（WARN）
- TypeScript 编译成功（0 errors）

### 第 3 步：侧载到设备

**方式 A：通过 DevEco Studio（推荐）**
```
1. 确保设备已连接并处于可调试状态
2. DevEco Studio > Run > Run 'entry'
   或点击工具栏的 Run 按钮
3. 等待应用安装和启动

预期：应用启动，无立即闪退
```

**方式 B：通过 hdc 命令**
```bash
# 先卸载旧版本
hdc shell pm uninstall org.scidavis.ohos

# 找到 HAP 文件
# 通常在 entry/build/default/outputs/default/entry-default-signed.hap
# 或 entry/build/default/outputs/default/entry-default-unsigned.hap

# 安装新版本
hdc install entry/build/default/outputs/default/entry-default-signed.hap

# 启动应用
hdc shell am start -n org.scidavis.ohos/.SciDAVisAbility
```

---

## 验证与故障排查

### 第 4 步：监控实时日志

打开 2 个终端窗口，分别监控：

**终端 1：监控 QtForOpenHarmony 标签**
```bash
hdc shell hilog -T QtForOpenHarmony
```

**终端 2：监控 org.scidavis.ohos 标签**
```bash
hdc shell hilog -T org.scidavis.ohos
```

### 第 5 步：检查预期日志输出

应用启动后，预期在 30 秒内看到以下日志：

✓ **成功场景**（应看到）：
```
[APP]07-25 20:43:05.364 42108 42108 I C03F00/org.scidavis.ohos/ArkCompiler: 
  start to execute module buffer with secure memory: /data/storage/el1/bundle/entry/ets/abilitystage/MyAbilityStage.abc

[APP]07-25 20:43:05.376 42108 42108 I QtForOpenHarmony: Calling qpa.attachAbilityStage

[APP]07-25 20:43:05.380 42108 42108 I QtForOpenHarmony: attachAbilityStage succeeded
  (或相似的 QPA 初始化成功日志)
```

✗ **失败场景**（应避免）：
```
[APP]TypeError: undefined is not callable
[APP]at onCreate entry (entry/src/main/ets/abilitystage/MyAbilityStage.ets:12:9)
```

---

## 成功指标

修复成功的标志：

1. **启动成功**：
   - 应用启动，无立即崩溃
   - 进程 pid 保持稳定 > 10s

2. **日志正确**：
   - hilog 中出现 `Calling qpa.attachAbilityStage`
   - 无 `TypeError: undefined is not callable` 错误

3. **功能运行**：
   - SciDAVis 图形界面正常显示
   - 界面元素可交互（按钮、菜单等）

4. **进程稳定**：
   - 运行 1 分钟以上无崩溃
   - 进程内存占用稳定（< 200MB）

---

## 如果仍然闪退

### 调试步骤

1. **获取完整故障日志**：
```bash
# 获取设备上的最新 faultlog
hdc shell ls /data/log/faultlog/faultlogger/
hdc shell cat /data/log/faultlog/faultlogger/<latest_file>
```

2. **检查插件库**：
```bash
hdc shell find /data/app/el1/bundle/entry -name '*qopenharmony*' -exec ls -lh {} \;
```

3. **检查 .abc 文件**：
```bash
hdc shell ls -lh /data/storage/el1/bundle/entry/ets/abilitystage/MyAbilityStage.abc
```

4. **查看进程内存映射**：
```bash
# 先获取应用 pid
hdc shell ps | grep org.scidavis.ohos

# 查看内存映射（替换 <pid>）
hdc shell cat /proc/<pid>/maps | grep -i qopenharmony
```

### 可能的后续问题

如果修复后仍闪退，可能的原因：

1. **QPA 插件库损坏**
   - 解决：重新从 Qt SDK 中复制 libplugins_platforms_qopenharmony.so
   - 确保文件大小 > 1.2MB，文件完整

2. **构建缓存问题**
   - 解决：`Build > Clean Build Folder` 后重新构建
   - 删除 `entry/.buildInfo` 目录

3. **Android NDK/交叉编译工具链问题**
   - 解决：检查 CMakeLists.txt 中的外部编译配置
   - 确保 NDK API 级别与目标设备兼容

4. **其他 NAPI 模块冲突**
   - 解决：检查是否有其他 .so 试图导出相同的符号
   - 查看构建日志中的链接警告

---

## 日志参考

### 关键日志标记

| 日志内容 | 含义 | 状态 |
|---------|------|------|
| `Calling qpa.attachAbilityStage` | 代码正确执行到 QPA API 调用 | ✓ 正常 |
| `QPA module is not loaded` | QPA 模块导入失败 | ✗ 需要调查 |
| `undefined is not callable` | 变量为 undefined（原始错误） | ✗ 修复的问题 |
| `plugins_platforms_qopenharmony` 被加载 | 插件库被系统加载 | ✓ 正常 |

---

## 支持命令参考

```bash
# 查看应用日志
hdc shell hilog -T org.scidavis.ohos

# 查看 Qt 日志
hdc shell hilog -T QtForOpenHarmony

# 卸载应用
hdc shell pm uninstall org.scidavis.ohos

# 查看应用进程
hdc shell ps | grep org.scidavis.ohos

# 终止进程
hdc shell kill -9 <pid>

# 获取设备信息
hdc shell cat /proc/version
hdc shell getprop ro.system.build.version.release
```

---

## 修复总结

**根本原因**：ES6 `import` 导入 NAPI 模块在运行时时序不当，导致 `qpa` 对象为 `undefined`

**解决方案**：
- 改用 `require()` 动态导入，添加错误处理和备选方案
- 所有 QPA API 调用前进行类型检查和异常捕获
- 添加详细的诊断日志便于后续故障排查

**预期效果**：
- 应用能够正确初始化 QPA 插件
- 启动时无闪退
- 正常显示 SciDAVis 图形界面
