# 参考：事件清单、配置与发布流程

> AGENTS.md 参考资料分册。查具体事件名/配置键/发布步骤时读本文件。
> 事件命名的**规则**（命令 `XxxRequested` / 事实 `XxxChanged|Started|Completed|Available`）与新增代码的约束见 [AGENTS.md 铁律速查](../../AGENTS.md#铁律速查新代码必须遵守)。

## EventBus 事件清单

事件契约由 `tools/event_contract_check.py` 静态校验（涉及 `EventBus.Publish/Subscribe` 的改动必须运行）：每个事件只有一个发布者，payload 字段以代码内事件声明为准。下表按域整理，标注 `Legacy` 的是为兼容保留的旧前缀名，新代码不应继续使用。

### 应用与生命周期

| 事件 | 说明 |
|------|------|
| `AppStartCompleted` | 启动完成（触发自动更新检查与游戏自动启动） |
| `SettingsShowRequested` | 请求显示设置窗口 |
| `ActiveTabChangeRequested` | 请求切换活动标签页 |
| `LocaleChanged` | 语言已切换 |
| `ConsoleOpened` | 调试控制台已打开 |

### 热键与按键绑定

| 事件 | 说明 |
|------|------|
| `HotkeyOn` / `HotkeyOff` | 热键总开关 |
| `HotkeyToggleRequested` | 请求切换热键开关 |
| `HotkeyStateChanged` | 热键状态事实 |
| `HotkeyGroupChanged` | 热键组切换事实 |
| `SwitchHotkey` | 切换键触发 |
| `SwitchKeyChanged` | 切换键变更事实 |
| `SetSwitchKey` / `UnsetSwitchKey` | 切换键管理（`Legacy`） |
| `KeyBindFocusSave` | 按键绑定保存 |
| `KeyBindFocusCancel` | 按键绑定取消 |
| `HotkeyBindingsChanged` | 按键绑定变更（触发冲突检测刷新） |
| `GameKeysChanged` | 游戏按键映射变更（注册表轮询检出） |
| `InLevelChanged` | 关卡内判定状态变更 |

### GUI 刷新（全为 `Legacy`）

`GuiUpdateHotkeyControls`、`GuiUpdateImportantControls`、`GuiUpdateCustomControls`、`GuiHideStopHook`。

### 设置

| 事件 | 说明 |
|------|------|
| `SettingsSaveRequested` / `SettingsApplyRequested` / `SettingsCancelRequested` / `SettingsResetRequested` | 设置命令 |
| `SettingsSaved` / `SettingsApplied` / `SettingsCancelled` / `SettingsReset` | 设置事实 |
| `SettingsChanged` | 单键设置变更 |
| `SettingsSaveStarting` | 保存前通知 |
| `SettingsValueChangeRequested` | 请求修改单个设置值 |
| `SettingsViewRefreshRequested` | 请求刷新设置视图 |

### 更新

| 事件 | 说明 |
|------|------|
| `UpdateCheckRequested` / `UpdateConfirmRequested` / `UpdateIgnoreRequested` / `UpdateManualDownloadRequested` / `UpdateDownloadCancelRequested` | 更新命令 |
| `UpdateCheckStarted` / `UpdateCheckCompleted` | 检查阶段事实 |
| `UpdateAvailable` | 发现新版本 |
| `UpdateDownloadStarted` / `UpdateDownloadProgress` / `UpdateDownloadRetryScheduled` / `UpdateFallbackNotice` / `UpdateDownloadCompleted` / `UpdateDownloadFailed` / `UpdateDownloadCancelled` | 下载阶段事实 |

### 更新公告

`ChangelogShowRequested`、`ChangelogAvailable`、`ChangelogDismissRequested`。

### 游戏客户端与路径

`GameClientsChanged`、`ForegroundClientChanged`、`CheckGamePathClick`、`GamePathDetected`、`GamePathNormalized`。

## 配置文件与数据文件

- **`Settings.ini`**：`%AppData%\ArknightsFrameAssistant\PC\Settings.ini`，三个 Section：`[Hotkeys]`、`[Main]`、`[Custom]`。GitHub Token 以 DPAPI 加密存于 `[Main] GitHubTokenProtected`（带 `dpapi:v1:` 前缀）。详见 [key_designs_base.md](key_designs_base.md#配置文件)。
- **`CustomHotkeys.json`**：自定义按键独立存储，与 `Settings.ini` 隔离，唯一 owner 是 `base/custom_hotkey_store.ahk`。
- **`changelog.json`**：`%AppData%\ArknightsFrameAssistant\PC\changelog.json`，存放从 GitHub Releases API 拉取的发布内容，由 `ReleaseRepository._SaveChangelogCache()` 写入、`ChangelogChecker` 读取。
- **日志与资源**：`…\PC\logs\`（`afa-*.log` / `critical-*.log`）、`…\PC\resources\`（`FileExtractor` 提取的嵌入资源）。

## 发布流程

见 [CONTRIBUTING.md](../../CONTRIBUTING.md) 的「版本发布流程」章节。与国内源同步相关的机制（`release-sync.yml`、`version.json`、5 个 GitHub Secrets、SHA-256 校验）见 [key_designs_base.md](key_designs_base.md#github-action-发布同步)。

## 静态检查工具

| 工具 | 命令 | 何时必须运行 |
|------|------|--------------|
| `tools/layer_check.py` | `python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS` | 涉及跨模块引用或 include 顺序的改动 |
| `tools/event_contract_check.py` | `python -X utf8 tools/event_contract_check.py` | 涉及 `EventBus.Publish/Subscribe` 的改动（已接入 CI） |
| `tools/i18n_check.py` | `python -X utf8 tools/i18n_check.py` | 涉及文案或语言资源的改动 |
| `test/scripts/smoke_test.ahk` | 见 AGENTS.md「用 AHK 脚本做测试时的错误捕获」 | 涉及模块结构/include 的改动（include 全模块后验证无顶层副作用） |
| `test/scripts/theme_test.ahk` | 同上 | 涉及主题逻辑的改动（`Theme.Resolve`/`Normalize` 与 `Constants.NormalizeThemeMode` 一致性断言） |
