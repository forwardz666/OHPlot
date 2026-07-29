# ArkTS 代码编写与 NAPI 集成规范

## 一、ArkTS 强类型编写规范

ArkTS 是静态类型语言，代码编写必须遵循以下强类型规则：

1. **禁止使用 `any` 和 `unknown` 类型**
   - 所有变量、参数、返回值必须有明确的具体类型
   - 编译报错 `10605008 (arkts-no-any-unknown)`

2. **所有模块导入必须使用 ES6 `import` 语法**
   - 禁止使用 `require()`（编译报错 `10505001: Cannot find name 'require'`）
   - 必须使用 `import xxx from 'xxx'`
   - 示例：
     ```typescript
     import qpaRaw from 'libqpa.so'
     import abilityStage from '@ohos.app.ability.AbilityStage'
     ```

3. **NAPI 模块必须配合显式接口定义 + `as` 类型断言**
   - 声明对应 `.so` 模块的接口（interface）
   - 用 `as` 进行类型断言
   - 示例：
     ```typescript
     interface QpaModule {
         startQtApplication(a: Object): void;
         // ... 其他方法声明
     }
     const qpa: QpaModule = qpaRaw as QpaModule;
     ```
   - 此模式已在 `SciDAVisAbility.ets` 中验证有效

4. **严格遵守语言子集限制**
   - 不使用 `any`/`unknown` 类型
   - 不使用 `require()` 动态导入
   - 不使用装饰器
   - 不依赖运行时类型反射

---

## 二、NAPI 插件集成防御性编程规范

在 OpenHarmony Stage 模型中集成 NAPI 插件（如 Qt 插件、数据库、图像处理库）时，必须采用防御性编程实践：

1. **使用 `require()` 动态导入替代 ES6 `import`**
   - `require()` 支持运行时错误捕获，而 ES6 `import` 在模块未就绪时直接抛出未捕获异常
   - 注意：这仅适用于 NAPI 插件防御性加载场景；普通 ArkTS 模块仍需使用 ES6 `import`

2. **调用前充分检查**
   - 检查对象是否为 `null`/`undefined`
   - 检查方法是否为 `function` 类型
   - 示例：
     ```typescript
     if (qpa && typeof qpa.startQtApplication === 'function') {
         qpa.startQtApplication(this);
     }
     ```

3. **所有 NAPI 调用必须包裹在 `try-catch` 中**
   - 捕获异常后记录详细 hilog 日志
   - 示例：
     ```typescript
     try {
         qpa.startQtApplication(this);
     } catch (e) {
         hilog.error(0x0001, 'SciDAVis', 'startQtApplication failed: %{public}s', e.message);
     }
     ```

4. **初始化时序敏感场景的处理**
   - 添加 `setTimeout` 延迟加载机制
   - 实现重试机制（如最多重试 3 次，间隔 500ms）

5. **在关键生命周期方法中优先验证模块可用性**
   - `onCreate`、`onWindowStageCreate` 等入口优先执行模块可用性验证
   - 模块未就绪时阻止后续流程并给出明确日志

---

## 三、C++ 导出符号规范

编写 NAPI/C++ 导出函数时，必须确保符号可见性：

1. **使用 `extern "C"` 防止名字改编（name mangling）**
2. **使用 `__attribute__((visibility("default")))` 确保符号导出**
3. 示例：
   ```cpp
   extern "C" __attribute__((visibility("default"))) void napi_register_foo() {
       // ...
   }
   ```

---

## 四、@Builder 响应性传参规范（2026-07-28 补充）

### 4.1 核心规则
`@Builder` 方法**按值传参时实参在首次渲染即被冻结**，其后 `@Prop`/`@State` 的更新
不会触发该 Builder 重渲染。凡 Builder 内容需随状态变化（灰显、文本、图标切换等），
**必须使用按引用传参**——即以单个对象字面量为唯一参数：

```typescript
// 错误：按值传参，enabled 变化后按钮永远保持首次渲染的状态
@Builder ToolButton(id: string, icon: Resource, enabled: boolean) { /* ... */ }
this.ToolButton('cut', $r('app.media.tb_edit_cut'), this.hasWin)

// 正确：单对象字面量按引用传参，@Prop 更新可触发重渲染
interface TbButtonOpts { id: string; icon: Resource; enabled: boolean; }
@Builder ToolButton($$: TbButtonOpts) {
  Image($$.icon).opacity($$.enabled ? 1 : 0.4)
  // ...
}
this.ToolButton({ id: 'cut', icon: $r('app.media.tb_edit_cut'), enabled: this.hasWin })
```

### 4.2 踩坑实录（ToolBar.ets，真机验证）
建表后 `getUiState` 已正确返回 `type=Table` 且 `@Prop hasWin` 已更新，但按值传参的
工具栏按钮仍保持灰显、不派发点击；改为按引用传参后 38 处调用点全部即时刷新。
排查时注意与数据链路问题区分：先用 hilog 确认状态值已到达组件，再怀疑渲染层。

### 4.3 适用边界
- 按值传参仅适用于**静态一次性内容**（构建后不再变化）。
- 按引用传参的对象字面量须配套 `interface` 显式类型（ArkTS 禁止匿名对象类型）。
