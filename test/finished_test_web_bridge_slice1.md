<!-- 由 AI 根据 test/template/test_template.md 生成 -->
# 测试清单：`web_bridge_slice1`

> 对应更改：新增 `WebBridge`，打通 WebView2 页面与内核的握手、`app.getState` 请求/回复；引入 vendored `JSON.ahk`。本 slice 不包含任何设置写入。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.2.0` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 10.0.26300.9711` |
| 测试日期 | `2026-10-18` |

---

## 单元测试

### 功能点：页面握手

- [x] **操作**：确认 `Settings.ini` 的 `[Main] UiEngine=web`，启动 AFA，打开设置界面
- [x] **预期**：窗口标题为 AFA；页面标题行显示 AFA 版本号，不再显示 `WebView2`
- [x] **操作**：观察页面状态文本
- [x] **预期**：先显示 `connected`，随后变为 `connected · <语言> · <主题> · web`

### 功能点：`app.getState` 往返

- [x] **操作**：在页面加载完成后打开 DevTools（`DebugEnabled=1` 时自动打开），在 Console 执行 `chrome.webview.addEventListener('message', e => console.log(e.data))`
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:99,method:'app.getState',params:{}})`
- [x] **预期**：Console 收到 `{v:1,type:'reply',id:99,ok:true,result:{version,locale,theme,engine,hotkeysEnabled}}`
- [x] **操作**：检查 `result` 的字段
- [x] **预期**：只包含以上五个字段，不包含 `GitHubToken` 或任何设置原文

### 功能点：方法白名单与协议校验

- [x] **操作**：在 Console 执行 `chrome.webview.postMessage({v:1,type:'call',id:100,method:'nope',params:{}})`
- [x] **预期**：收到 `ok:false`，`error.code` 为 `unknown_method`
- [x] **操作**：执行 `chrome.webview.postMessage({v:2,type:'call',id:101,method:'app.getState',params:{}})`
- [x] **预期**：收到 `ok:false`，`error.code` 为 `unsupported_version`
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:102,method:'app.getState',params:[]})`
- [x] **预期**：收到 `ok:false`，`error.code` 为 `bad_request`

---

## 集成测试

### 流程：web 引擎正常启动与握手

> 涉及模块：`WebHost`、`WebBridge`、`WebView2`、`index.html`

- [x] **前置**：本机已安装 WebView2 Runtime，`UiEngine=web`
- [x] **操作**：启动 AFA，等待设置窗口出现
- [x] **预期**：窗口正常显示，页面显示 AFA 版本与连接状态；日志出现 `web 引擎已启动` 与 `界面已上报 ready`
- [x] **预期**：没有回退到经典界面的托盘提示，日志没有 `WebBridge` 的来源/JSON 错误

### 流程：页面刷新后重新握手

> 涉及模块：`WebBridge`、`WebHost`

- [x] **操作**：在 DevTools Console 执行 `location.reload()`，等待页面重新加载
- [x] **操作**：再次执行 `app.getState` 的手动调用
- [x] **预期**：页面重新显示连接状态；手动调用仍能收到 `reply`，说明 `NavigationStarting` 后重新完成了握手

### 流程：切回经典界面

> 涉及模块：`TrayController`、`UiShell`、`WebHost`、`WebBridge`

- [x] **操作**：右键托盘图标，选择「切换到经典界面(Windows原生GUI)」，确认重启
- [x] **预期**：重启后进入经典 GUI，原有设置页功能正常
- [x] **预期**：日志没有 `WebBridge` 绑定/发送异常；不会因为 web 残留状态影响经典界面

### 异常路径：页面未握手

> 涉及模块：`WebHost`、`WebBridge`

- **跳过**：本 slice 未改动原有的 8 秒 ready 超时与回退策略。如需构造，可在开发态临时让页面不发送 `ready`，预期仍按现有策略提示/回退，且不会出现 `WebBridge` 异常堆栈；本项不作为本 slice 的必测项
- [x] **操作**：在 DevTools Console 执行 `chrome.webview.postMessage({v:1,type:'call',id:103,method:'app.getState'})`（不带 `params`）
- [x] **预期**：仍能收到 `ok:true` 的 `reply`；本项仅验证缺参不报错，`app.getState` 不观察 `params`，默认空对象由代码审查保证，待后续 params API 再补可判别测试

---

## 回归测试

### 功能：经典界面启动

- [x] 验证：`UiEngine=classic` 启动 AFA，设置窗口、热键、托盘菜单均正常；新增的 `JSON.ahk`/`WebBridge` 不产生启动副作用

### 功能：WebView2 宿主原有生命周期

- [x] 验证：web 窗口关闭按钮按 `ExitOnWindowClose` 配置工作；再次打开设置窗口能复用同一控制器，页面不空白
- [x] 验证：`DebugEnabled=1` 时 DevTools 正常打开
- [ ] 验证：`DebugEnabled=0` 时不打开 —— **跳过**：需改配置并重启，与本 slice 的桥接逻辑无关

### 功能：`app.getState` 的语言/主题字段

- [x] 验证：`app.getState` 返回的 `locale`/`theme` 与当前配置一致（第 2 组已覆盖）
- 说明：当前 Web UI 是通信占位页，没有多语言/主题渲染，不做视觉切换验证；等页面实现后再补

---

## 测试结果

- [x] 全部必测项通过
- [ ] 存在问题（详见下方问题反馈）

> 统计：32 项通过；2 项跳过（`DebugEnabled=0`、手工构造 ready 超时，均与本 slice 的桥接逻辑无关）。
> 语言/主题视觉切换不适用于当前占位页；只验证了 `app.getState` 的 `locale`/`theme` 字段。页面实现多语言/主题后再补视觉回归。

## 问题反馈

### 问题1：页面未 ready，日志报 `WebBridge 处理前端消息失败`

- 现象：页面停在 `loading`，8 秒后提示是否回退经典界面；日志只有 `This local variable has not been assigned a value...`
- 原因：`_OnMessage` 的局部变量 `type` 遮蔽了内置函数 `Type()`，`Type(msg)` 读到未赋值的局部变量，抛 `UnsetError`，`ready` 未被处理
- 修复：局部变量改名为 `msgType`
- [x] 重新编译后复测通过

## 追加测试（握手加固）

> 对应更改：ready 版本校验、旧版字符串 ready、导航时重置 `PageReady` 并重新武装超时、握手构造失败可重试。

- [ ] 正常启动 web UI，页面仍显示 `connected · ...`，DevTools 手动 `app.getState` 仍返回 `ok:true`
- [ ] 在 web 页面执行 `location.reload()`，页面重新显示 `connected · ...`，且 8 秒内不会误回退
- [ ] （可选）刷新后新页面不发送 `ready` 时，8 秒后按既有策略提示/回退；无法构造则跳过
- [ ] 追加测试结果：通过 / 存在问题

> 说明：ready 版本不匹配与旧版字符串 ready 两条分支由代码审查覆盖；运行态构造需要替换页面，不作为必测项。
