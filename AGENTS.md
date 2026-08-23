# AGENTS.md

This file provides guidance to AI coding agents (DeepSeek Harness / dsh, etc.) when working with code in this repository.

## 项目概述

明日方舟帧操小助手（ArknightsFrameAssistant, AFA）— 优化明日方舟 PC 端体验的 Windows 工具。基于 **AutoHotkey v2** 开发，提供全按键自定义、过帧操作、卫戍协议一键操作等功能。仅对明日方舟进程生效。

## 构建与开发

- **语言**: AutoHotkey v2
- **编辑器**: 推荐 VS Code + AHK++ 扩展
- **AHK 文档**: `docs/ahk_docs/` 目录包含最新的 AHK v2 官方文档。开发时优先读取 `ahk_docs/lib/` 下的对应 `.htm` 文件（如 `ahk_docs/lib/Control.htm`），而非依赖模型内置的 AHK 知识，因为内置知识可能过时或不完整。
- **Win32文档**: `docs/win_docs/` 目录包含项目所需的Windows API 文档，开发时优先读取 `win_docs/` 下的对应 `.md` 文件
- **入口文件**: `src/main.ahk`
- 如果开发过程中使用AHK脚本进行测试，需要增加 `OnError` 全局回调 + 主流程 `try/catch`，出错才能把错误信息写文件，不然会弹窗报错，获取不到结果
- 默认不编译或启动 AFA；只有用户明确要求构建时才使用已验证的本地 AutoHotkey/Ahk2Exe 工具。涉及 GUI、提权、计划任务和真实游戏联动的验收仍由用户操作并反馈
- 没有自动化测试框架，所有测试为手工验证。每次完成工作后，调用 `test-checklist` skill 生成测试清单，逐项引导用户完成手工验证。测试清单放在 `test/` 目录，格式参考 `test/template/test_template.md`。
- 静态分层检查已落地：`tools/layer_check.py` 与基线 `KNOWN_VIOLATIONS`。涉及跨模块引用或 include 顺序的改动必须先跑 `python3 tools/layer_check.py --baseline KNOWN_VIOLATIONS`；`test/scripts/smoke_test.ahk` 用于 include 全模块后验证无顶层副作用；事件契约检查器 `tools/event_contract_check.py` 已接入 CI，涉及 `EventBus.Publish/Subscribe` 的改动需运行 `python3 tools/event_contract_check.py`。
- 不使用worktree进行开发
- 提前查看.gitignore，以确认哪些更改不需要commit
- 用户没有要求的话，不要擅自commit，不要擅自Push，不创建PR，不创建或改变branch，这些操作由用户自行进行
- 如果用户要求提交，请对diff进行详细分类，并分开提交，提交的标题和描述要通顺易懂

## 架构概览

> **当前架构约束**（新代码必须遵守）：
> 1. 四层单向依赖 `bootstrap → ui → core → base`；core 不得引用 ui，base 不得引用 core/ui。
> 2. 所有 `.ahk` 只定义、零顶层副作用；启动由 `main.ahk` 显式 `App.Bootstrap()` 执行。
> 3. 事件命名统一 `XxxRequested`（命令）/ `XxxChanged`/`Started`/`Completed`（事实）；事件契约由 `tools/event_contract_check.py` 静态校验。
> 4. 配置写入只经 `SettingsService`；热键元数据只来自 `base/hotkey_schema.ahk`；`State` 类已删除，字段归唯一 owner。

### 启动流程（当前实现）

所有 `.ahk` 只定义、零顶层副作用；`main.ahk` 的 `#Include` 仅负责加载定义，启动由 `App.Bootstrap()` 显式执行。当前启动顺序：

1. 环境初始化（性能参数、窗口匹配模式、`A_MaxHotkeysPerInterval=200`、`OnExit` 等）。注意：`#Warn All, Off` 抑制了所有 AHK 警告，调试时如遇异常行为需手动排查，不会看到警告输出。
2. 非管理员时以 `*RunAs` 提权重启；管理员进程继续执行 `Logger.Init()`。
3. `Config.InitPath()` 初始化配置路径，随后初始化各域：`HotkeyActionsStart()`、`LevelDetector.Init()`、`KeyBinder.Start()`、`HotkeyService.Init()`、`TimingService.Init()`、`SettingsService.Init()`、`VersionChecker.Init()`、`Updater.Init()`、`ChangelogChecker.Init()`、`ChangelogUI.Init()`、`GameLauncher.Init()`。
4. `SettingsService.Initialize()` 加载配置并注册敏感值；`AppContext.SetStartedByGameAutoStart()` + `GameAutoStartManager.Reconcile()` 校准随游戏自启。
5. `FileExtractor.EnsureExtracted()` 提取嵌入资源；`GameKeys.Init()`（读取注册表游戏按键 + 启动 10s 轮询定时器，**必须在 `HotkeyOn` 之前**）→ `HotkeyService.HotkeyOn()` 激活热键。
6. 发布 `ChangelogShowRequested`；`GuiManager.Start()`；`UpdateUI.Init()`。
7. 发布 `AppStartCompleted` 触发自动更新检查与游戏自动启动；`GameMonitor.Start()` 启动游戏监控。
8. 发布 Legacy 事件 `SetSwitchKey`、`GuiUpdateHotkeyControls`、`GuiUpdateImportantControls`、`GuiUpdateCustomControls` 完成 GUI 初始化。

### 模块职责（当前实现）

| 模块 | 职责 |
|------|------|
| `base/config.ahk`（含 `base/constants.ahk`、`base/hotkey_schema.ahk`） | 全局配置管理（`Config` 类；`Constants` 与 `HotkeySchema` 为独立类）。配置持久化到 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`。Config 用懒加载模式（`_IsLoaded` 标志位） |
| `base/custom_hotkey_store.ahk` | `CustomHotkeys.json` 唯一 owner（自定义按键独立存储，与 Settings.ini 隔离）。UTF-8 JSON、写定式（键序固定 `key/name/script/type`）+ 字符集白名单 + 严格正则读取；解析失败备份 `.bak` 并回退空列表；写入走临时文件 + `ReplaceFileW` 原子替换；清空写空数组不删文件 |
| `base/token_protector.ahk` | GitHub Token 的 Windows DPAPI 加密保护（`TokenProtector` 类）。`Protect()` 用 `CryptProtectData`（CurrentUser）加密并 Base64 编码，返回带 `dpapi:v1:` 前缀的存储值；`Unprotect()` 解密，无前缀值按旧版明文处理（供迁移）。内存缓冲用 `_SecureZero` 清零。由 `config.ahk` 的 `_ReadGitHubToken`/`_MigrateLegacyToken` 调用，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键 |
| `base/eventbus.ahk` | 发布/订阅事件总线，模块间解耦。核心事件：`AppStartCompleted`（启动完成）、`HotkeyOn`/`HotkeyOff`/`SwitchHotkey`（热键开关）、`SetSwitchKey`/`UnsetSwitchKey`（切换键管理）、`GuiUpdate*` 系列（GUI 刷新）、`SettingsSaveRequested`/`SettingsApplyRequested`/`SettingsCancelRequested`/`SettingsResetRequested`（设置命令）与 `SettingsSaved`/`SettingsApplied`/`SettingsCancelled`/`SettingsReset`（设置事实）、`SettingsChanged`（单键设置变更）、`SettingsSaveStarting`（保存前通知）、`UpdateCheckRequested`/`UpdateConfirmRequested`/`UpdateIgnoreRequested`/`UpdateManualDownloadRequested`/`UpdateDownloadCancelRequested`（更新命令）与 `UpdateCheckStarted/Completed`、`UpdateAvailable`、`UpdateDownloadStarted/Progress/RetryScheduled/FallbackNotice/Completed/Failed/Cancelled`（更新事实）、`ChangelogShowRequested`/`ChangelogAvailable`/`ChangelogDismissRequested`（公告事件）、`KeyBindFocusSave`（按键绑定保存）、`HotkeyBindingsChanged`（按键绑定变更，触发冲突检测刷新） |
| `base/file_extractor.ahk` | 管理编译时 `FileInstall` 嵌入资源的运行时提取。`EnsureExtracted()` 将 `logo.ico`（含大小校验防旧版残留）、三张 `TakeOverButton_*.png`（代理作战按钮图像）和关卡检测模板（保留备用，PixelSearch 方案不依赖）统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` |
| `core/hotkey/game_keys.ahk` | 游戏按键注册表识别（`GameKeys` 类）。从 `HKCU\Software\HyperGryph\Arknights` 读取 `KEYBOARD_SETTING_V2_h*`（REG_BINARY→hex→JSON），将 Unity KeyId 映射为 AHK 键名。提供 `SendDown`/`SendUp`/`Tap(gameFunc)` 封装方法，供 `core/hotkey/hotkey_actions.ahk` 调用。`GetInterceptPattern()` 动态生成热键拦截正则。每 10 秒轮询注册表检测变更，自动重建热键。六层 fallback 防御（精确→小写→numX→alphaX→char*→单字符），读取失败回退默认值并弹警告 |
| `core/hotkey/hotkey_service.ahk`（`HotkeyService`） | 热键注册/注销/分组切换。三组热键：CombatHotkeys（常规作战）、QuickHotkeys（快捷操作）、StrongHoldHotkeys（卫戍协议）。按标签页启用对应组，组间互斥。自定义按键按「按键类型」并入既有组（global 任何标签下注册、combat/quick 并入常规组、strongHold 并入卫戍组）；「自定义按键」标签页为管理型（不切换热键组）。拦截正则由 `GameKeys.GetInterceptPattern()` 动态生成。`ActionCallbacks` 数据化（`{Fn, Guarded}`）声明守卫标志，为守卫拦截键注册 Up 变体补发透传 |
| `core/hotkey/hotkey_actions.ahk`（`HotkeyActions`） | 热键触发后的具体功能实现（`Action*` 函数）。触控注入初始化由 `App.Bootstrap()` 调用 `HotkeyActionsStart()` 完成；所有游戏按键通过 `GameKeys.SendDown`/`SendUp`/`Tap` 发送，不再硬编码。常规作战 14 个功能带关卡守卫（`GuardInLevel`，读 `LevelDetector.IsInLevel()` 判定），拦截时经 `KeyForward` 透传原键 |
| `core/hotkey/custom_script.ahk`（`CustomScriptEngine`） | 自定义指令引擎：行式脚本（`tap(x, y)` 0-1 比例坐标单击、`usleep(ms)` 延迟）的校验/编译/执行。对外仅 `Validate`/`Reload`/`RunById`/`IsRegistered` 四方法；解析只在保存/Reload 慢路径，触发时 O(1) 缓存查表零 IO。内置函数注册表供未来扩展。执行整体 `Thread "NoTimers"`，每次 tap 后即时还原光标 + `finally` 无条件归位（操作完成后鼠标回归原位）；combat 类型经 `GuardInLevel` 受关卡守卫 |
| `base/touch_injection.ahk` | Windows Touch Injection API 封装（`TouchInjector` 类）。用于暂停选人/技能/撤退等操作的模拟点击，通过 `InitializeTouchInjection`/`InjectTouchInput` 实现，不抢夺鼠标焦点 |
| `base/i18n.ahk` + `base/locales/*.ahk` | 国际化核心（`I18n` 类）与五语言资源（`LocaleZhHans`/`LocaleZhHant`/`LocaleJaJP`/`LocaleKoKR`/`LocaleEnUS`）。`Init(localeId)`/`SetLocale()`/`T(key, args*)`；回退链 请求语言 → zh-Hans → key 本身；**键即中文原文**（`LocaleZhHans.Data` 为空表，zh-Hans 命中原文）；`Data` 超约 19KB 拆分 `Data2` |
| `base/metrics.ahk` | UI 度量与字体（`Metrics` 类）：`FontFor(locale)` 返回各语言推荐字体，`TextWidth()` 估算文本像素宽度（供控件宽度按语言自适应） |
| `ui/key_bind.ahk` | 按键绑定捕获（InputHook），处理用户在设置界面的按键录制 |
| `ui/gui.ahk` | 设置窗口 GUI 全部逻辑（标签页切换、控件事件、托盘菜单）。`UpdateSaveButtonState()` 根据 `IsModified` 和 `HasHotkeyConflicts` 决定保存/应用按钮状态。`RefreshHotkeyConflicts()` 调用 `HotkeyConflictValidator` 进行增量字体标红（仅更新冲突状态变化的控件，使用 `_PrevConflictedControls` 做 diff）。`SwitchTab()` 确认放弃修改后调用 `Config.LoadFromIni()` 显式丢弃内存修改。自定义按键页：12 行预建（两列 × 6 行）（显隐 + 重写值实现增删，AHK 控件无法运行时移除）、行控件命名 `CustomHotkey{i}Key/Gear`（删除功能在编辑窗口内）、`TrackChange` 对 `CustomHotkey*Key` 委托 `TrackCustomHotkeysChange` |
| `ui/custom_key_editor.ahk` | 自定义按键编辑窗口 + 帮助窗口 + 坐标拾取。独立顶层 Gui（非 MainGui，KeyBinder 按键录制自动豁免）；单编辑窗口（再次打开直接切换目标行，未保存修改丢弃）；底部「删除」按钮确认后移除该行；打开期间光标在游戏客户区内（无需游戏前台）时 8ms 轮询 ToolTip 显示光标处 0-1 比例坐标，LButton 拾取（无 `~` 吞点击）经 `EditPaste` 插入 `(x, y)` 并激活编辑窗口；保存时校验命名（50 字符、禁引号/反斜杠/控制字符）与指令语法，非法拒绝弹窗 |
| `base/logger.ahk` | 双轨日志系统（`Logger` 类）。普通日志（15 MiB）和关键日志 WARN/ERROR（5 MiB）分轨滚动存储到 `%AppData%\ArknightsFrameAssistant\PC\logs\`。支持会话级文件命名（`afa-{timestamp}-{pid}-{tick}.log`）、7 天过期清理、敏感值脱敏（`RegisterSecret`/`Redact`）、异常退出检测（启动时检查上一会话是否含 Shutdown 标记）、全局未处理异常回调。所有模块通过 `Logger.Info`/`Warn`/`Error`/`Debug`/`Exception` 写日志 |
| `core/diagnostics/log_exporter.ahk` | 诊断压缩包导出（`LogExporter` 类）。`CreateArchiveInteractive()` 弹出文件保存对话框，收集所有日志 + 脱敏后的设置文件 + 诊断信息，通过 PowerShell 打包为 ZIP。`OpenLogDirectory()` 打开日志目录 |
| `core/settings/hotkey_conflict_validator.ahk` | 热键冲突验证器（`HotkeyConflictValidator` 类）。`FindAll(hotkeys, customSettings, customHotkeys)` 在同时启用的热键组内检测按键重复（自定义按键按「按键类型」并入两组：global 并入两组、combat/quick 并入常规组、strongHold 并入卫戍组；同对冲突跨组去重），返回 `{HasConflicts, Items, ByControl}`。SwitchHotkey 在全部两组中各检测一次。`GetDisplayName()` 查找 KeyNames/CustomNames/自定义行名称用于错误提示。供 GUI 实时提示和 SettingsService 保存阶段校验共享 |
| `core/settings/settings_service.ahk`（`SettingsService`） | 唯一配置写口。`Initialize()` 启动加载，`Save/Apply/Cancel/Reset()` 处理 GUI 命令，`UpdatePersistedValue(key, value)` 单键原子写入并发布 `SettingsChanged`。保存/应用/重置后通过 `SettingsSaved/Applied/Reset` 驱动 HotkeyService/TimingService/LevelDetector/GuiManager 刷新 |
| `core/updater/` | 自动更新全流程：`release_repository.ahk`（GitHub/国内源检查与 changelog 缓存）→ `version_checker.ahk`（门面：首选源/重试/降级）→ `downloader.ahk` → `self_replacer.ahk` → `updater_manager.ahk`（协调器，事件化）；`github_token_service.ahk` 提供 Token 验证。`ui/updater_ui.ahk` 仅通过事件与 Updater 交互 |
| `core/changelog/changelog_checker.ahk` + `ui/changelog_ui.ahk` | 更新公告检查和显示。`ChangelogChecker` 订阅 `ChangelogShowRequested`，构建 body 后发布 `ChangelogAvailable`；`ChangelogUI` 订阅展示 |
| `core/launch/game_launcher.ahk` | 随 AFA 自动启动游戏。`CheckGamePath()` 识别游戏路径，`ProcessGetPath` 失败时降级到 WMI 查询（`_GetProcessPathByWmi`） |
| `core/launch/game_auto_start.ahk` | 随明日方舟启动自动启动小助手（`GameAutoStartManager` 类）。审核事务临时启用 `SeSecurityPrivilege`，通过 `AuditQuerySystemPolicy` 读取优先，仅在成功审核缺失时调用 `AuditSetSystemPolicy`，复查后恢复令牌权限原状态；错误 1450 按 250/750ms 有限重试。计划任务按动作、参数、工作目录、事件订阅、主体和设置做语义比较，一致时不重写，缺失或漂移时才修复。手动启动执行校准；`--game-autostart` 触发启动在配置开启时跳过校准，配置关闭时尽力删除遗留任务后退出。启动校准失败保留配置和任务，仅在 GUI 就绪后显示一次托盘通知；设置页显式保存仍严格失败且不持久化。`Disable()` 只删除当前用户任务并保留系统审核。任务按 SID 独立命名（`ArknightsFrameAssistant-AutoStartWithGame-{SID}`） |
| `core/launch/app_context.ahk` | 应用启动上下文：`StartedByGameAutoStart` 唯一 owner，Bootstrap 写入，GameAutoStartManager/LogExporter 读取 |
| `core/hotkey/timing_service.ahk` | 时序服务：`CurrentDelay`/`ClickDelay` 唯一 owner，提供 getter 与 `Refresh()` |
| `base/message_box.ahk` | 自定义消息框（`MessageBox` 类），替代原生 `MsgBox`。支持同步/异步模式、按钮组合与按语言自适应的布局（背景色/字体由 `Metrics.FontFor` 提供），窗口通过忙等循环实现同步。注意：右键/图标渲染已移除 |
| `core/monitor/level_detector.ahk` | 关卡检测投票状态机（`LevelDetector` 类）。每 333ms 轮询对 3 个关卡内专属对象（关卡内文本/退出按钮/暂停按钮）做 PixelSearch 颜色检测（区域用相对比例定位，低分辨率时文本容差放宽到 20），命中 ≥2 个 → 私有 `InLevel=true`，<2 → `false`。维护守卫判定依据；守卫关闭（`InLevelGuard=0`）时停止轮询并强制 `InLevel=true` |
| `core/monitor/game_monitor.ahk`（`GameMonitor` 类） | 三合一游戏状态监控：(1) **自动退出**：游戏进程退出时自动退出 AFA；(2) **自动开局暂停**：通过 17 点全屏黑屏检测 → 三条扫描线 Loading 识别 → 暂停按钮颜色识别的三阶段状态机，在进关卡时自动暂停；(3) 定时器频率随状态动态调整（400ms → 黑屏后 200ms → 8 秒超时恢复 400ms）。包含 `LoadingPosition()`、`BlackScreenPoints()`、`StopSearchLoading()` 三个辅助函数 |

### 关键设计

- **多区服与热路径预算（v2.0.0+）**：`GameTarget` 是“目标游戏窗口”的唯一 owner，禁止在热键/监控路径再直接写 `ahk_exe Arknights.exe`（宽松回退集中在 `GameTarget`）。热键触发路径只允许 O(1) 内存查表 + 最多 2 次轻量 Win32 调用（`GetForegroundWindow` / `GetWindowThreadProcessId`）；`ProcessGetPath`、WMI、`RegRead`、`PixelSearch`、文件 IO 一律走定时器慢路径。`GameClientRegistry` 维护 PID→区服缓存并由 `GameMonitor` 400ms 轮询刷新；`GameKeys` 按前台区服取映射，拦截正则为所有已安装区服并集。

- **FileDelete/Map.Delete 陷阱**：`FileDelete` 对不存在的文件会抛异常，与 `Map.Delete` 同类，删除前必须先 `FileExist`/`Has` 判断。

- **不用 AHK 执行/编译脚本**：默认不编译或启动 AFA；涉及 GUI、提权、计划任务和真实游戏联动的验收仍由用户操作并反馈。脚本取不到输出时直接问用户。

- **Constants 类**：常量定义。`Delay30`~`Delay240` 是各帧率对应的延迟毫秒值（取 `ceil(1000/fps)`，例外：`Delay144=8` 多 1ms 余量），`TimingService.GetCurrentDelay()` 依此计算。`FrameOptions` 定义下拉框选项数组，`FrameTextToOldIndex`/`FrameOldIndexToText` 用于 Frame155 双写转换。`KeyNames` 是 `Map(热键id, i18n键名)`（由 `HotkeySchema` 生成），显示名经 `I18n.T(nameKey)` 获取——新增热键功能时**必须**在 `HotkeySchema.Items` 中同步添加带 `nameKey` 的条目。`CustomNames` 对应自定义设置的显示名，新增自定义配置项时也需同步添加，否则设置无法保存；同时需在 `Config._DefaultCustom` 加默认值——老用户已有 INI 缺新键时由 `LoadFromIni` 的 `_BackfillMissingCustomDefaults()`（v1.9.0+）自动补齐，无需手工迁移。
- **Logger 日志系统**（v1.5.10+）：双轨滚动存储，普通日志（`afa-*.log`）保留 15 MiB，关键日志 WARN/ERROR（`critical-*.log`）单独保留 5 MiB，总容量 20 MiB。按会话隔离（文件名含时间戳+PID+tick），支持 7 天过期清理和容量驱动的分段轮换。`RegisterSecret(value)` 注册敏感值，`_BuildLine` 自动调用 `Redact` 脱敏。启动时检测上一会话是否异常退出（无 Shutdown 标记的上一会话日志文件受保护不被清理）。`SetDebugEnabled(enabled)` 控制 DEBUG 级别是否持久化。所有日志通过 `OutputDebug` 同步输出到 DebugView。容量清理依赖缓存指标（`CachedOrdinaryFiles`/`CachedOrdinaryBytes` 等），每 64 次写入或有容量压力时触发。
- **实时调试控制台**（v1.9.0+，logger.ahk）：`SetConsoleEnabled` 经 `AllocConsole` 创建「AFA 调试日志」窗口。输出**必须用 `WriteConsoleW` DllCall 直接写入**——`FileOpen("CONOUT$")`+`WriteLine` 因 File 对象内部缓冲、控制台不关闭不刷新而空屏。`SetConsoleTextAttribute` 按级别着色（ERROR红/WARN黄/DEBUG灰/INFO白）；打开时显示亮蓝横幅并回放 `RecentLines` 最近日志。安全措施：X 按钮置灰、`SetConsoleCtrlHandler(NULL, TRUE)` 忽略 Ctrl+C/Break、`SetConsoleMode` 清除 `ENABLE_QUICK_EDIT_MODE(0x0040)` 并置 `ENABLE_EXTENDED_FLAGS(0x0080)`（否则点击控制台进入选择态、阻塞进程控制台 I/O 卡死 AFA）。`AllocConsole` 失败（进程已有控制台，如从终端启动）→ 静默降级并**复位 `ConsoleEnabled=false`**（避免 `CloseConsole` 误 `FreeConsole` 脱离调用方终端）。`ConsoleTipShown` 内存标志控"当次会话仅首次"提示。`DebugEnabled`（Important）经 `SettingsService.Initialize()` 接线同时控制持久化与控制台；`version_checker.IsDebugLogging()` 直接读 `Logger.DebugEnabled`（单源，勿重读 INI 造成双源）。
- **Config 读写分离与工作副本**（v1.5.10+）：`GetHotkey()`/`GetImportant()`/`GetCustom()` 返回内存工作副本（`_HotkeySettings`/`_ImportantSettings`/`_CustomSettings`），供 GUI 显示和冲突检测使用。`SetHotkey()`/`SetImportant()`/`SetCustom()` 仅写内存。`LoadFromIni()` 一次性从 INI 重载全部三组设置，用于显式丢弃内存中的未保存修改（取消设置时）。热键注册和运行时逻辑不应触碰工作副本，应使用 `ReadHotkeyFromIni()`/`ReadImportantFromIni()`/`ReadCustomFromIni()` 直接从 INI 读取——这三个方法不会修改内存 Map。`AllHotkeys`/`AllImportant`/`AllCustom` 三个属性直接返回内存 Map 的引用，供遍历使用——注意 `AllHotkeys` 的值是"真实键值"（`RealNewkeyFormat`），而 GUI 显示的是 `VirtualNewkeyFormat` 后的可读值。`TrackChange()` 在检测控件变更时同步将新值写入 Config 内存（确保切换标签页后编辑不丢失）。`SetImportant("Frame", value)` 内部自动同步 `Frame155`，调用方无需手动双写。`UpdateSource`（`"1"` = 国内源默认，`"2"` = GitHub）为 v1.5.6+ 新增的 Important 配置项。三组设置分别通过 `GetHotkey`/`GetImportant`/`GetCustom` 懒加载，各自对应 `_DefaultHotkeys`/`_DefaultImportant`/`_DefaultCustom` 默认值 Map
- **State 类已删除**：原运行时字段已收归唯一 owner：`CurrentDelay`/`ClickDelay` → `TimingService`；`InLevel` → `LevelDetector.IsInLevel()`；`GameHasStarted`/`ReadyForPause`/`BlackScreenDetected` → `GameMonitor` 私有；`HoverOperate` → `HotkeyService`；`StartedByGameAutoStart` → `AppContext`；`GuiWindowName` 删除。
- **EventBus 事件命名约定（新代码必须遵守）**：命令用 `XxxRequested`，事实用 `XxxChanged`/`XxxStarted`/`XxxCompleted`/`XxxAvailable`；每个事件只有一个发布者，payload 字段以代码内事件声明与 `tools/event_contract_check.py` 校验为准。旧前缀名（`GuiUpdate*`、`Settings*`、`Update*`、`Set*`/`Unset*`）为兼容遗留，新代码不应继续使用。
- **自动开局暂停流程**（v1.5.3+）：三阶段状态机 — 全屏黑屏检测 → Loading 扫描线识别（排除红/蓝进关）→ 暂停按钮颜色确认后 ESC 暂停，再用代理作战按钮图像确认避免重复暂停；8 秒超时自动取消，定时器频率随状态动态调整（400ms → 200ms → 超时恢复 400ms）。细节见 `game_monitor.ahk`。
- **热键注册与拦截**：用 `HotIf(HotkeyContext)` 回调（core/hotkey/hotkey_service.ahk 顶部）限制热键作用域——鼠标键/滚轮（LButton/RButton/MButton/XButton1/2/Wheel*）返回 `IsMouseInClient()`（悬停在游戏窗口上才触发，修复窗口外任务栏/桌面点击被吞）；键盘键返回 `WinActive("ahk_exe Arknights.exe")` **或** `IsMouseInClient()`（#213：游戏失焦时鼠标悬停游戏窗口也能操作，动作层负责激活游戏；该失焦悬停路径受「自定义」页开关 `HotkeyService.GetHoverOperate()` 门控，保存/应用后生效，关闭后键盘键仅活动窗口触发，鼠标键/滚轮不受影响）。**动作包装**（#213，`_WrapAction` 于 `_RegisterOne` 注册时套用）：主热键与 OnUp 型动作执行前 `WinActivate` 游戏 + `WinWaitActive`（超时 500ms 则跳过动作，避免按键发往非游戏窗口），激活后不恢复原窗口（焦点留在游戏）；守卫补发 Up 变体（`ActionUpForward`）与 SwitchKey 切换键**不包装**。通过 `GameKeys.GetInterceptPattern()` 动态生成拦截正则——从注册表读取所有游戏按键 + `Escape|RButton|MButton`。AFA 热键绑定的按键若匹配拦截正则，不加 `~` 前缀（阻止原键传递到游戏），否则加 `~` 前缀（透传）。用户自定义游戏按键后，轮询检测到注册表变更自动重建热键，拦截列表随之更新。
- **常规作战关卡守卫与按键透传**（v1.5.12+，core/hotkey/hotkey_actions.ahk + core/hotkey/hotkey_service.ahk）：常规作战 14 个功能经 `GuardInLevel(actionName, ThisHotkey)` 守卫——关卡内放行、关卡外拦截。拦截时由 `KeyForward` 类透传原键：`ForwardOriginalKey()` 补发 key down 并记录 `InterceptedKeys` 标志（带 `~` 前缀的键本就透传不补发；Up 型热键只补发 key up；滚轮发完整事件）；`ActionUpForward()` 为 Up 变体回调——**补发 key up**（对未按下的键是无害 no-op）：AHK Send 对物理按住的修饰键会“释放-重注入”，被拦截（无 `~`）的修饰键物理 up 也被吞。**Up 变体放行依据**是 `KeyForward.DownHandled`（运行时标记，`GuardInLevel` 在主热键触发时记录，无论守卫放行/拦截）——仅 down 被 AFA 处理过才放行补发 up；游戏外主热键不触发（down 透传）则不放行，物理 up 正常透传（打字不受影响）。`SuppressUp` 标志（**键级 Map**，按 pureKey 记录，非全局布尔）防 Send 注入的 up 被钩子重新捕获触发 Up 变体导致无限递归。键名规范化：`PureKeyName` 保留左右修饰键（`<SHIFT`→`lshift`、`>SHIFT`→`rshift`）且统一大小写（防 `a/A` 拼写不一致漏发 Up），`InterceptedKeys` 关闭大小写敏感。`_RegisterOne()` 为守卫拦截键（非滚轮）注册 `X Up` 变体（类静态方法引用需 `.Bind(KeyForward)`），`DisableGroup()` 同规则注销。失焦边界（按住修饰键 Alt+Tab 切走再松开）已由 DownHandled 机制解决。守卫判定读 `LevelDetector.IsInLevel()`（无像素检测、无 DPI 切换），拦截日志用 Info 级别（同一按住周期经 `InterceptedKeys` 去重，避免 key repeat 刷屏）。位置函数统一用 `SafeWinGetClientPos(&ww,&wh)`（窗口关闭返回 false 而非抛 TargetError）。
- **关卡检测与守卫判定**（level_detector.ahk + core/hotkey/hotkey_actions.ahk）：关卡检测使用 `LevelDetector` 投票状态机——每 333ms 对 3 个关卡内专属对象（关卡内文本/退出按钮/暂停按钮）做 PixelSearch 颜色检测（区域用相对比例定位，低分辨率时文本容差放宽到 20；v1.7.2 起默认容差 3→5/10、关卡内文本识别线加宽，以误识别率为代价适应更多窗口/屏幕配置），命中 ≥2 个置位私有 `InLevel`、<2 复位。`GuardInLevel` 读 `LevelDetector.IsInLevel()` 判定（无瞬时像素检测）。`ActionCeaseOperations`（放弃行动）只发 `battleLeftPopup`、`ActionBack`（返回上级菜单）只发 ESC——两者功能分离于 v1.6.1；`BackCeaseOperations`（Important 配置项，默认关闭）开启后 `ActionBack` 在 ESC 后补发 `battleLeftPopup`，还原旧版"放弃行动"行为。`InLevelGuard`（Important 配置项，默认开启）控制 `GuardInLevel` 守卫开关——关闭后 `LevelDetector` 停止轮询并强制 `InLevel=true`，守卫直接放行（零 I/O）；开启后恢复 333ms 轮询。**线程抢占风险**（v1.7.0+，已修复）：`LevelDetector` 的 SetTimer 轮询与热键回调同为 priority 0，AHK 单线程下新线程会中断当前线程（`misc/Threads.htm#Interrupt`）——Poll 的 PixelSearch（每次最多 16 色）会随机插入时序敏感动作的 `USleep` 忙等，拉长实际间隔（5~50ms）导致过帧波动（一次过两帧/不过帧）。修复：时序敏感动作的 Send/Touch 序列加中断保护（单次 `Tap` 动作无需）——**过帧三件套（16/33/166ms）保留 `Critical`/`Critical "Off"`**（帧数精确性依赖完全不可中断，连热键也不放行）；**暂停选中/技能/撤退、一键技能/撤退、视角切换 v1.9.4 起改用 `Thread "NoTimers"`/`Thread "NoTimers", false`**（只挡定时器轮询，放行其他热键——动作中可即时响应倍速等热键；`Critical` 会连热键一起挡掉，故非过帧动作不再用）；`USleep` 到期时记录 overshoot 诊断日志（`current-target` 换算毫秒，≥1ms 时 `Logger.Debug`）便于观察中断。
- **GameKeys 类**（v1.5.10+）：负责游戏按键的动态识别。核心流程：`Init()` 首次读取注册表并启动 10s 定时器 → `_OnPoll()` 定时比对 hex，有变更则重新解析 JSON → 更新 `_Bindings` → 调用 `HotkeyService.EnableByTab()` 重建热键。`SendDown`/`SendUp`/`Tap` 三个方法封装了查表+Send 逻辑，接受注册表中的 function 名（如 `"releaseSkill"`），内部转换为用户实际绑定的 AHK 键名。游戏内绑定的鼠标键（自定义名 `mouseLeft/Right/Middle/Forward/Back` → `LButton/RButton/MButton/XButton2/XButton1`，标准 Unity `Mouse0-4`）同样映射进 `_Bindings` 参与拦截正则。注册表键名前缀匹配 `KEYBOARD_SETTING_V` 应对游戏版本更新。ESC 和 LButton 不经过 GameKeys（不可重新绑定的系统级按键）。
- **更新渠道**：`UpdateChannel` 设置为 1（正式版）或 2（测试版），版本检查器据此选择检查 stable releases 还是包含 pre-release。GUI 通过下拉框切换，默认正式版。
- **双源更新与自动降级**（v1.5.6+）：更新系统支持 GitHub API 和国内源（腾讯云 COS+CDN）两源，`UpdateSource` 选首选源，失败自动降级备选源（`token_invalid`/`rate_limited` 静默降级）。国内源用 CDN 静态 `version.json`（`version`/`downloadUrl`/`releases`），`releases` 格式与 GitHub API 一致，复用 changelog 缓存。发布时 Action（`.github/workflows/release-sync.yml`）自动同步 exe 和 version.json 到 COS。**v1.8.1+ 双源 SHA-256 下载校验**：`expectedHash` 从版本检查结果一路透传到 `downloader`，下载完成后用 `_GetFileSha256`（分块流式 `CryptHashData`）校验，不匹配则删除文件并弹窗中止（防篡改）。GitHub 源从 asset 的 `digest` 字段（`sha256:<hex>`，正则限定 `"name":"AFA.exe"` asset）提取；国内源从 `version.json` 的 `sha256` 字段提取。`version.json` 的 `sha256` 由发布 Action 计算写入。
- **配置文件**：INI 格式，三个 Section：`[Hotkeys]`、`[Main]`、`[Custom]`。`GitHubToken` 使用 Windows DPAPI（`token_protector.ahk` 的 `TokenProtector` 类）按当前 Windows 用户加密，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键（带 `dpapi:v1:` 前缀），读取经 `_ReadGitHubToken()` 解密。旧版明文 `GitHubToken` 键在启动时自动迁移为加密格式并删除明文（迁移失败会保留原配置并提示恢复写入权限）。
- **数据文件**：`%AppData%\ArknightsFrameAssistant\PC\changelog.json` 存储从 GitHub Releases API 拉取的所有版本发布内容，每次版本检查时更新。由 `ReleaseRepository._SaveChangelogCache()` 写入，`ChangelogChecker` 读取。
- **GUI 脏值对比**：`GuiManager` 维护 `_InitialValues` 快照和 `_IsModified` 标志。`CaptureInitialSnapshot()` 在设置加载/保存/应用后保存所有控件当前值，`TrackChange(key)` 在控件变更时将当前值与快照对比，同时将新值同步写入 Config 内存（热键控件和 SwitchHotkey 已由 `KeyBinder.EndChange` 提前写入，`TrackChange` 负责其余控件）。新增可修改控件时需在 `CaptureInitialSnapshot` 中添加对应 key，并在控件事件中调用 `TrackChange`。
- **热键冲突实时检测**（v1.5.10+）：`HotkeyConflictValidator.FindAll()` 在 CombatHotkeys+QuickHotkeys 组和 StrongHoldHotkeys 组内分别检测重复（组间不互检）；自定义按键按「按键类型」并入两组（global 始终生效故并入两组，combat/quick 入常规组、strongHold 入卫戍组），同对冲突跨组去重。`GuiManager.RefreshHotkeyConflicts()` 用增量字体更新——仅对新进入冲突的控件标红 `cD93025`、离开冲突的恢复 `cDefault`，避免全页闪烁。`UpdateSaveButtonState()` 据 `IsModified && !HasHotkeyConflicts` 决定按钮启用。`key_bind.ahk` 的 `NotifyBindingChanged` 发布 `HotkeyBindingsChanged` 触发刷新。切换标签页不丢弃修改，冲突状态跨标签页保持。
- **key_bind.ahk 的 WM_LBUTTONDOWN 处理**：`OnMessage(0x0201, WM_LBUTTONDOWN)` 是进程级回调，会在所有 GUI 的 Edit 控件点击时触发。为防止非设置窗口的 Edit 控件误触发按键录制，回调开头有父窗口检查：`if (KeyBinder.ControlObj.Gui.Hwnd != GuiManager.MainGui.Hwnd) return`。新增 Edit 控件且不需要按键录制功能时，确保其父窗口不是 `GuiManager.MainGui`。点击非 Edit 区域时自动聚焦取消按钮（`GuiManager.FocusCancelButton()`），取消普通 Edit 控件的选中状态。
- **Alt+F4 始终退出**：通过 `GuiManager.Start()` 中的 `HotIf` + `Hotkey("!F4", ...)` 动态注册拦截设置窗口的 Alt+F4，始终彻底退出 AFA。标题栏 X 按钮仍由 `ExitOnWindowClose` 设置控制（关闭窗口 or 退出）。
- **AHK v2 GUI 布局要点**：`xs`/`ys` 引用**最近**的 `Section`（叠加布局中会追到前一个分类的 Section 导致偏移，每组首控件应用绝对坐标如 `x160 y45`）。Text 的 `Center` 仅水平居中，文字要填满控件需去掉固定高度自适应（`hp`）而非依赖 Center。
- **"其他设置"页面结构**（v1.5.5+）：左侧 Text 导航项（`NavItems`）+ 右侧四分类内容叠加（`LaunchControls`/`UpdateControls`/`CustomControls`/`AboutControls`），经 `_SwitchOtherCategory` 切换 Visible。`OtherCategories` Map（分类名→[控件组, 导航索引]）统一管理，新增分类只需加一行。导航切换有 `force` 参数（标签页切换强制显示、导航点击不传以守卫重复点击）。关于页是纯展示页，切换时禁用保存/应用按钮。
- **更新源下拉框**（v1.5.6+）："更新"分类中新增"更新源"下拉框（国内源/GitHub，默认国内源）。切换时 `_OnUpdateSourceChange()` 联动 Token 复选框、输入框、提示文字三者的 `Enabled` 状态——选国内源时全部灰掉，选 GitHub 时恢复。
- **Frame155 双写机制**（v1.5.5+）：帧率存储有两个 INI 键 — `Frame155` 存文本值（如 "90"、"180"、"240+"），`Frame` 存旧版索引（1~7，180 映射为 6）。新版优先读取 Frame155，回退读 Frame 旧序号并转换。保存时双写两个键，`MigrateFrameRate()` 在启动时自动将旧序号迁移到 Frame155。新增帧率时需同步更新 3 处：`Constants.FrameOptions`（下拉框选项）、`Constants.FrameTextToOldIndex`（文本→旧序号）、`Constants.FrameOldIndexToText`（旧序号→文本）。
- **DropDownList.Value 陷阱**：AHK v2 的 `DropDownList.Value` **始终使用索引**（1-based），与 `AltSubmit` 无关。`AltSubmit` 只影响 `Gui.Submit()` 的返回值格式（有→索引，无→文本）。如果下拉框去掉 `AltSubmit` 以让 Submit 返回文本，赋值 `.Value` 时仍需传索引，需做文本→索引转换。
- **Map.Delete 陷阱**：AHK v2 的 `Map.Delete(key)` 对不存在的键抛 `UnsetItemError`（`Item has no value`），删除前需 `Has` 检查（带默认值参数的是 `Get`，`Delete` 没有）。
- **热键频率阈值**：AHK v2 用内置变量 `A_MaxHotkeysPerInterval`（默认 66 热键/2000ms）而非 v1 的 `#MaxHotkeysPerInterval` 指令；被拦截的游戏键每个按键触发 down+up 两个热键，极速连打 WASD 等易超默认值弹警告框，main.ahk 已设 200。**#279 起同时设 `A_HotkeyInterval := 0`**：高分辨率/无级滚轮可轻松超过 200 次/2000ms，触发警告弹窗与系统“嘟嘟”提示音；设 0 的含义是**永久关闭该洪峰告警**（不是调高上限）。已接受的代价：未来若出现“热键自触发循环”将不再有告警兜底，需另行评估热键注册/InputLevel 加固，**不得擅自恢复该告警**。
- **明日方舟按键限制**：游戏设置禁止将 Ctrl 绑定为游戏内按键，故 Ctrl 不命中拦截正则——纯 Ctrl 热键的卡键路径无法在真实环境复现/测试。
- **Send 注入会触发热键**：AHK 的 Send 命令注入的按键事件默认会被自身钩子捕获并触发热键。Up 变体回调用 Send 补发 key up 时，若放行条件不含递归抑制，注入的 up 会再次触发 Up 变体 → 无限循环补发 → 系统键盘状态被轰炸、按键完全失灵。回调内"Send 同键"的机制必须加防递归标志（如 `KeyForward.SuppressUp`，**须键级作用域**——用 `Map(pureKey→true)` 而非全局布尔，全局布尔会在多键同松时让第二个键的物理 Up 落在第一个键补发窗口内被误挡，`HotkeyContext` 条件失败→物理 up 被吞→卡键）。
- **AHK 线程优先级 vs Critical/NoTimers**（v1.9.4+，core/hotkey/hotkey_actions.ahk）：AHK 优先级规则是"**新线程优先级低于当前线程才不能中断**"，且低优先级事件按下会被**直接丢弃（not buffered）**而非排队（`misc/Threads.htm#Priority`）——"提高热键优先级、降低定时器优先级"的方案有静默丢键风险（动作快结束时按的低优先级热键会整个丢失），AHK 文档明确 Critical 因能缓冲事件而优于 Priority。`Thread "NoTimers"` 是"只挡定时器、放行热键"的精确工具（`Thread.htm`："similar to Critical except that it only prevents interruptions from timers"），线程级设置、无需改热键注册。选用原则：需"防定时器轮询抖动、但允许其他热键中断"时用 `Thread "NoTimers"` 代替 Critical；需"完全不可中断"（帧数精确）时保留 Critical。
- **cmd `chcp 65001` 批处理陷阱**（self_replacer.ahk）：cmd 按当前控制台代码页解析批处理文件，中文 Windows 默认 GBK。在**批处理内部**执行 `chcp 65001` 会触发 cmd 重读文件并**错位解析中文行**，报 "is not recognized" 乱码错误（如 `'�我'`）。**触发需同时满足**：行以多字节中文字符结尾（cmd 会把行尾换行符吞进上一个多字节字符）。已实测规避方式：每行以 ASCII 结尾（如 `...`，与 `正在等待程序关闭...` 风格一致）、中文块前插 ASCII 分隔行、或把中文内容合并成单行。彻底修复需权衡：在 cmd 命令行前置 chcp（`cmd /c "chcp 65001 >nul & call 批处理"`）会引入 `cmd /c "..." & ...` 命令行签名、增加杀软误报风险（本分支反误报优化所忌）；批处理改 GBK 编码则 update 日志变 GBK（LogExporter 按 UTF-8 读取会乱码）。本分支决定保留 `Run batchFile` + 内部 chcp，用 ASCII 行尾规避。
- **File.Read 只接受 1 参数**：AHK v2 的 `File.Read(Characters)` 只读字符串，不支持 v1 的 `Read(&Buffer, Count)` 二参形式——传 2 参会抛 `Too many parameters passed to function.`。读原始字节到 Buffer 须用 `File.RawRead(&Buffer, Bytes)`（返回实际读取字节数）；哈希等二进制读取建议分块流式，避免大文件整体载入内存。
- **AHK 箭头函数限制与函数名引用**：AHK v2 的箭头函数 `(p) => expr` **只支持单一表达式，不支持 `{ }` 语句块**——多行逻辑需用**嵌套函数闭包**实现（`Functions.htm#closures`：在函数内 `Name(params) { ... }`，捕获外层局部变量即闭包，可用于 Hotkey 回调）。另外 `ActionCallbacks` 等 Map 里的 `Fn: ActionBack` 存的是**函数引用（Func 对象）**而非字符串——AHK v2 中函数定义即同名只读变量、其值即 Func 对象，可直接 `Fn(ThisHotkey)` 调用（`Hotkey` 回调同样接受函数对象）。AHK v2 的 `Func()` 只接受**函数名字符串**，对函数对象套 `IsObject(fn) ? fn : Func(fn)` 规范化是死代码（v1 残留认知），空 `catch` 还会掩盖动作内部真实异常（修复见 core/hotkey/hotkey_service.ahk 的 `_WrapAction`）。
- **`SetTimer Func, 0` 是解除定时器**：AHK v2 中它取消待触发的回调、**不调用函数**；与 `SetTimer Func, -8000`（一次性定时调用）含义不同，勿混淆（曾有审查误判"0 会触发回调"）。
- **AHK v2 无 `..` 范围运算符**：`for i in 1..5` 不是 v2 语法——`1..5` 会被解析为对 Float 取属性 `"5"`，**编译不报错**，运行时报 `This value of type "Float" has no property named "5"`（#283 debug 实测踩坑）。循环用 `loop 5` + `A_Index`，或数组字面量（如 `[1,2,3,4,5]`）；不要使用 `..` 连写。
- **FrameSkip 自定义延迟**（v1.5.5+）：三档过帧延迟（16ms/33ms/166ms）可通过"自定义"分类中的"过帧档位1/2/3" Edit 控件自定义。延迟值存为 `FrameSkip*Delay` 自定义配置项，Action 函数通过 `Config.GetCustom()` 读取。`GuiManager` 维护 `FrameSkipDelayKeys` 列表和 `FrameSkipLabels` Map，`_UpdateFrameSkipLabels()` 在保存/应用后动态更新"常规作战"标签页的过帧行文本。
- **FileInstall 嵌入资源**：编译时通过 `FileInstall` 将 `logo.ico`、`resources/images/TakeOverButton_*.png`（三张代理作战按钮截图）和关卡检测模板（保留备用，PixelSearch 方案不依赖）打包进 exe，运行时由 `FileExtractor.EnsureExtracted()` **统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` 子目录**（避免散落根目录）。`logo.ico` 使用文件大小校验（`FileGetSize`）判断是否需要重新提取以防止旧版本残留。新增需要嵌入的资源时遵循此模式，在 `FileExtractor` 类中添加路径和提取逻辑。
- **GitHub Action 发布同步**（v1.5.6+）：`.github/workflows/release-sync.yml` 监听 Release 发布事件，将 `AFA.exe` 和 `version.json` 上传到 COS 并刷新 CDN。`.github/scripts/build_version_json.py` 构建含全量 releases 历史的 `version.json`，处理首次初始化（COS 上无文件时自动创建），支持 stable/beta 双通道独立 version.json。Action 需要 5 个 GitHub Secrets（`COS_SECRET_ID`/`COS_SECRET_KEY`/`COS_BUCKET`/`COS_REGION`/`CDN_DOMAIN`）。`release-sync.yml` 不在 `.gitignore` 中，会被 git 跟踪。发布时对 `AFA.exe` 计算 sha256 写入 `version.json`（`--sha256` 参数）；**GitHub Actions step outputs 大小写敏感**——输出键名须用小写 `sha256`，否则引用为空。
- **GUI 控件统一管理**：对于批量重复的控件组（如过帧延迟字段、导航分类），优先使用列表/Map 集中定义再循环遍历（如 `FrameSkipDelayKeys`、`OtherCategories`），避免单个 try 块的 OR 链，便于扩展。
- **顶部标签页管理器**（v1.5.12+，gui.ahk）：`TabItems` 数组描述五个标签（`keyBind`/`quick`/`strongHoldProtocol`/`customKeys`/`other`），`CanHide` 控制可否隐藏（`other` 不可隐藏；`customKeys` 为管理型标签页可隐藏，隐藏仅失去编辑入口、已绑定按键照常按其类型生效）。`TabOrder`/`HiddenTabs` 两个 Important 配置项存顺序与隐藏列表，通过两个 **Hidden Edit 表单变量**（`vTabOrder`/`vHiddenTabs`）与 `MainGui["TabOrder"]` 交互——必须放布局链之外（如 `sepCustom` 前），否则破坏自定义页左列 `y+10` 相对定位。`AppliedTabSettings` 存已应用快照，`IsTabVisible()` 优先读快照、`tabItem.Visible` 是工作态（统计当前可见性直接遍历 `tabItem.Visible`）。眼睛图标统一 `U+E890`（蓝=显示/灰=隐藏），禁止隐藏最后一个功能标签时弹窗。`LastActiveTab` 只记录功能标签页（排除 `other` 与 `customKeys`）。
- **Segoe MDL2 Assets 图标码点**：`U+E890`=View（眼睛，可靠）；`U+E8F4`=NewFolder（**不是闭眼**）；`U+E9CE` 在部分系统字形缺失会显示问号。选图标码点前用像素渲染实测确认，不要凭记忆推断。`game_monitor.ahk`/`core/hotkey/hotkey_actions.ahk` 用 `SetThreadDpiAwarenessContext(-3)` 是局部临时切换（像素检测用），不影响 GUI 主窗口 DPI 基准。
- **AHK DPI 与坐标换算**：AHK v2 是 **system DPI aware**（非 per-monitor，官方文档明确"not marked as per-monitor DPI-aware"）。`A_ScreenDPI`=主屏 DPI 是正确基准，系统对副屏做 bitmap scaling 并统一坐标——多屏不同缩放下用 `A_ScreenDPI` 换算即可，不要用 `GetDpiForWindow`。`MouseGetPos` 在 `CoordMode "Mouse","Client"` 下返回**物理像素**，而 GUI `Move()` 用**逻辑像素**（DPI 缩放），两者换算：`物理像素 * 96 / A_ScreenDPI`。
- **AHK Text 控件运行时改背景色不可靠**：`Opt("Background" color)` 对已创建 Text 控件改背景色，文档明确"the control might choose to ignore it"——高亮能显示但取消高亮不刷新，`Sleep -1`/`Redraw()` 均无法绕过。需要运行时切换背景时用**双控件叠加**（固定背景层 + 高亮层，通过 `Visible` 切换），并将高亮层加入命中测试（`GetTabManagerHit`）。注意 `_ShowControls` 会把组内所有控件设为可见（含高亮层），需在分类切换后重绘重置。
- **动态对齐 vs 绝对坐标**：GUI 中右列对齐左列时，用 `GetPos` 动态读取左列控件实际 y 存入类成员（如 `TabManagerTitleY`），而非硬编码绝对坐标——AHK 的 `y+10` 相对"前一个控件底部"（非 Section），绝对坐标估算易随字体/布局漂移。控件尺寸/垂直偏移（`y+4` 等）在各子控件间应统一，否则视觉高度不齐。

### i18n 多语言（v2.0.0+）

- **键 = 中文原文（source-as-key / gettext 风格）**：调用点直接写中文，如 `I18n.T("常规作战")`、`I18n.T("前进 {1}ms", delay)`。**简体中文不需要维护资源表**（`LocaleZhHans.Data` 保持空 Map，回退链命中 key 本身即原文）；改文案 = 全局替换中文串 + 同步 4 张翻译表，**无需再起英文点键名**。**新增用户可见文案**（GUI/托盘/弹窗/消息字段）即以中文原文为键，并同步 zh-Hant / ja-JP / ko-KR / en-US 四表。
- **重复中文文案共享同一键**：相同原文合并为一个键（如「取消」= 旧 `btn.cancel`/`msg.btnCancel`）；若不同上下文需要不同翻译，先区分中文原文（改措辞）再建新键。
- **语言 id 用 BCP-47**：`zh-Hans` / `zh-Hant` / `ja-JP` / `ko-KR` / `en-US`；`Language=auto` 用 `GetUserDefaultUILanguage()` 检测（`A_Language` 是系统区域设置，不是 UI 语言；四语覆盖，其余回退 `en-US`）。
- **资源 = 编译内置 Map**：`base/locales/*.ahk` 的 `LocaleXxx.Data`（键 = 中文原文，值 = 各语言翻译；zh-Hant/ja-JP/ko-KR/en-US 需要维护）。**AHK 单条静态 `Map(...)` 声明约 19KB 解析上限**——大资源表拆 `Data2`，`I18n._Lookup` 按 `Data → Data2` 顺序查找（键数 >254 或语句超约 19KB 时沿用此约定，勿合并回单表）。`tools/i18n_check.py` 校验源码字面 `I18n.T("key")` 与四语言资源键集合（使用键必须在所有语言中存在；残留旧点键或未同步翻译会报 FAIL）；`HotkeySchema.nameKey` / `Constants.*Names` / `DisplayNameKey` 等经变量动态引用的键报 INFO 属预期。
- **`I18n.T(key, args*)`**：回退链 请求语言 → `zh-Hans`（空表）→ key 本身（即中文原文）；缺键仅对非 zh-Hans 语言每键 `Warn` 一次（zh-Hans 命中原文属预期不告警）；回退路径同样执行 `Format`（带 `{1}` 的中文键在 zh-Hans 下也能正确插值）；占位符用 `Format` 风格 `{1}`，**禁止拼接句子**；`I18n` 未 `Init` 前调用会惰性加载兜底，正常流程在 `SettingsService.Initialize()` 内完成 `I18n.Init`（崩溃提示等展示须在 Init 之后）。
- 以下**保持中文不翻译**：`Logger.*`、`VersionChecker._Log`、`OutputDebug`、调试控制台横幅、诊断包（`read-errors.txt` / `diagnostics.txt`）、热键明细日志（"战斗=/快捷="）、内部 `throw Error("...")` 及仅被日志消费的 message 字段。键化前先确认文案是否展示给用户。
- **`self_replacer.ahk` 批处理控制台**（含 `update-*.log` 内容）：zh-Hans/zh-Hant 保留中文与求饶文案，**其它语言统一英文**（`batch.*` 键，ja/ko 值与 en 相同）；批处理行尾必须 ASCII（`chcp 65001` 陷阱见上）。
- **控件宽度按语言自适应**：`Metrics.TextWidth()` 仅作快速估算；关键长标签（绑定行、帧率标签等）用**独立临时 Gui 探测真实字形宽度**（`Gui()` + `Add("Text")` + `GetPos` + `probeGui.Destroy()`），不要在主窗口建隐藏探测控件。列栅格约定：编辑控件列固定（左列 x155 / 右列 x515，w140），左侧标签右缘固定 135 右对齐、宽出向左延伸（列内上限 135px）；消息框/更新/下载弹窗的按钮宽度与窗口尺寸按实际控件位置动态计算。
- **AHK 控件无 `Destroy()`**：Gui 控件对象没有 `Destroy`/`Delete` 方法（只有 `Gui` 窗口可 `Destroy()`）；Text 控件改 `.Value` **不会**自动重新量宽（需 `Move`）。"测量后重定位"一律用临时 Gui 窗口或 `GetPos` + `Move`。
- **布局/文案改动后须五语言人工验证**：按 `test/test_i18n_four_language_regression.md` 逐语言核对换行/截断/对齐（中文为基准；中文界面默认要求不动）。优先"测量真实宽度"，不要按估算值设死宽度。

## 代码规范

参考 CONTRIBUTING.md：
- 函数名/方法名/全局变量/静态变量：大驼峰 `CheckVersion()`
- 局部变量：小驼峰 `gameProcess`
- 常量：全大写 `MAX_RETRY`
- 注释使用 `;`（单行）或 `/* */`（多行）
- Commit 遵循 Conventional Commits：`feat(scope): subject`，subject部分使用中文。scope 与改动涉及的模块文件名保持一致（如 `game_keys`、`hotkey_actions`），测试清单的 scope 与常规不同，使用 `test` 且类型为 `docs`（如 `docs(test):`）
- 分支命名：`feat/描述`、`fix/描述`、`ui/描述`、`docs/描述`、`style/描述`、`perf/描述`、`refactor/描述` 等
- PR 目标分支：`develop`（非 main）

## 版本号

- **AFA**：在 `src/lib/base/version.ahk` 的 `Version.Number` 中定义，版本检查器通过 GitHub API 或国内源 CDN 对比此值与远程 release tag/version.json
- **AHK**：当前为 v2.0.26，无需向用户确认
- **Windows**：跟随测试环境，自行获取，无需向用户确认
