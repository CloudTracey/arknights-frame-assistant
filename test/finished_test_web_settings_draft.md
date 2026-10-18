<!-- 由 AI 根据 test/template/test_template.md 生成 -->
# 测试清单：`web_settings_draft`

> 对应更改：Slice 2 设置桥。新增 `settings.get` / `settings.setDraft`，读取可编辑配置快照并把草稿写入 `Config` 内存工作副本；转发 `SettingsChanged`。本 slice 不做保存/应用，不改 `index.html`。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.2.0` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 10.0.26300.9711` |
| 测试日期 | `2026-10-18` |

---

## 单元测试

### 功能点：`settings.get` 快照

- [x] **操作**：确认 `UiEngine=web`，启动 AFA 并打开 web 设置窗口；DevTools Console 执行 `chrome.webview.addEventListener('message', e => console.log(e.data))`
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:201,method:'settings.get',params:{}})`
- [x] **预期**：收到 `id:201`、`ok:true`；`result.values` 非空，包含 `AutoExit`、`Frame155`、`ClickDelay`、`PressPause` 等键
- [x] **预期**：`result.values` 不包含 `GitHubToken`，回复中没有任何 Token 原文
- [x] **预期**：`result.customHotkeys` 是数组；`result.hasGitHubToken` 是布尔值
- [x] **操作**：检查 `result.values.Frame155` 与 `result.values.Frame`
- [x] **预期**：快照使用 `Frame155`，不出现 `Frame`

### 功能点：草稿写入成功

- [x] **操作**：记录当前 `Settings.ini` 的 `[Custom] ClickDelay` 值；执行 `chrome.webview.postMessage({v:1,type:'call',id:202,method:'settings.setDraft',params:{key:'ClickDelay',value:'60'}})`
- [x] **预期**：收到 `id:202`、`ok:true`，`result.success` 为 `true`，`result.value` 为 `"60"`
- [x] **操作**：再次执行 `settings.get`
- [x] **预期**：`values.ClickDelay` 为 `"60"`，说明草稿在内存中生效
- [x] **预期**：`Settings.ini` 的 `ClickDelay` 未被改写；重启 AFA 后恢复原值

### 功能点：非法键与只读键

- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:203,method:'settings.setDraft',params:{key:'Nope',value:'1'}})`
- [x] **预期**：`result.success` 为 `false`，`result.code` 为 `unknown_key`
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:204,method:'settings.setDraft',params:{key:'GitHubToken',value:'abc'}})`
- [x] **预期**：`result.success` 为 `false`，`result.code` 为 `read_only`；回复中不出现 `abc`

### 功能点：值规范化

- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:205,method:'settings.setDraft',params:{key:'PressPause',value:'A'}})`
- [x] **预期**：`result.success` 为 `true`，`result.value` 为 `"a"`（热键值规范化）
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:206,method:'settings.setDraft',params:{key:'Frame155',value:'180'}})`
- [x] **预期**：`result.success` 为 `true`，`key` 为 `Frame155`；再次 `settings.get` 得到 `Frame155="180"`
- [x] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:207,method:'settings.setDraft',params:{key:'Frame155',value:'999'}})`
- [x] **预期**：`result.success` 为 `false`，`result.code` 为 `invalid_value`

---

## 集成测试

### 流程：设置桥与现有握手共存

> 涉及模块：`WebBridge`、`WebSettings`、`WebHost`

- [x] **前置**：web UI 已正常显示 `connected · ...`
- [x] **操作**：如果 DevTools 截到 `welcome`，检查 `methods`；否则直接执行 `settings.get`
- [x] **预期**：`settings.get` 返回 `ok:true`；`welcome.methods` 未截到时不作运行时断言，方法注册由直接调用覆盖
- **说明**：`welcome.methods` 的完整性由代码审查覆盖；运行态以三个方法可直接调用为准
- [x] **操作**：执行 `location.reload()`，重新执行 `settings.get`
- [x] **预期**：页面重新握手，`settings.get` 仍返回快照；没有 8 秒误回退

### 流程：外部设置变更事件

> 涉及模块：`WebBridge`、`SettingsService`、`HotkeyService`

- [x] **操作**：在 DevTools Console 保持消息监听；在游戏内按 `AutoBeginPauseSwitch` 热键（默认 `c`）
- [x] **预期**：收到 `type:'event'`、`name:'SettingsChanged'`、`data.key:'AutoBeginPause'` 的事件
- [x] **说明**：如果当前环境不方便触发游戏热键，本项可跳过；事件转发代码由审查覆盖

### 流程：不落盘与回归

> 涉及模块：`SettingsService`、`WebHost`、`GuiManager`

- [x] **操作**：执行 `settings.setDraft` 修改 `ClickDelay`，然后关闭/重启 AFA
- [x] **预期**：重启后 `ClickDelay` 恢复原值，确认本 slice 没有写盘
- [x] **操作**：在 web 页面切换到经典界面并重新打开设置
- [x] **预期**：经典界面正常；`Settings.ini` 未被草稿意外改写
- [x] **操作**：确认 `index.html` 仍是占位页，没有新增设置控件
- [x] **预期**：页面布局与 Slice 1 一致；本 slice 只提供桥能力

---

## 回归测试

### 功能：Slice 1 通信链路

- [x] 验证：`app.getState` 仍返回 `ok:true`，页面显示 `connected · ...`
- [x] 验证：`location.reload()` 后重新握手正常
- [x] 验证：外部导航 `location.href='https://example.com'` 仍被拦截

### 功能：经典界面

- [x] 验证：切回经典界面后设置窗口、托盘、热键正常，未受 `WebSettings` 影响

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

无。
