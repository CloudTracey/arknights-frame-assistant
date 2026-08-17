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
- 没有编译步骤 — AHK 脚本可直接运行。发布时用 AutoHotkey 编译器打包为 exe。
- 默认不编译或启动 AFA；只有用户明确要求构建时才使用已验证的本地 AutoHotkey/Ahk2Exe 工具。涉及 GUI、提权、计划任务和真实游戏联动的验收仍由用户操作并反馈
- 没有自动化测试框架，所有测试为手工验证。每次完成工作后，调用 `test-checklist` skill 生成测试清单，逐项引导用户完成手工验证。测试清单放在 `test/` 目录，格式参考 `test/template/test_template.md`。

- 架构迁移已落地静态分层检查 `tools/layer_check.py` 与基线 `KNOWN_VIOLATIONS`（阶段 1 完成）。涉及跨模块引用或 include 顺序的改动必须先跑 `python3 tools/layer_check.py --baseline KNOWN_VIOLATIONS`；`test/smoke_test.ahk` 尚未落地（阶段 3 完成前不要假设其存在）。
- 不使用worktree进行开发
- 提前查看.gitignore，以确认哪些更改不需要commit
- 用户没有要求的话，不要擅自commit，不要擅自Push，不创建PR，不创建或改变branch，这些操作由用户自行进行

## 架构概览

> **迁移状态（2026-08-17）**：阶段 1（工具/门禁基线）与阶段 2（base 层建设）已完成；以下「当前实现」章节在剩余迁移完成前仍是对现状的准确描述。同时，已确认的目标架构约束对新代码立即生效：
> 1. 四层单向依赖 `bootstrap → ui → core → base`；core 不得引用 ui，base 不得引用 core/ui。
> 2. 所有 `.ahk` 只定义、零顶层副作用；启动由 `main.ahk` 显式 `App.Bootstrap()` 执行。
> 3. 事件命名统一 `XxxRequested`（命令）/ `XxxChanged`/`Started`/`Completed`（事实）；唯一契约表在 `docs/adr/2026-08-17-event-contract-and-naming.md`。
> 4. 配置写入只经 `SettingsService`；热键元数据只来自 `base/hotkey_schema.ahk`；`State` 类将被删除，字段归唯一 owner。
>
> 决策全文与实施顺序：`docs/adr/2026-08-17-four-layer-dependency-and-explicit-bootstrap.md`、`docs/adr/2026-08-17-settings-write-port-hotkey-schema-state-ownership.md`、`docs/architecture/coupling-improvement-roadmap.md`。
>
> **迁移进度**：
> - ✅ 阶段 1：`tools/layer_check.py` + `KNOWN_VIOLATIONS` + CI workflow
> - ✅ 阶段 2：`src/lib/base/` 落位、config 拆分、`base/hotkey_schema.ahk`、base 纯函数抽取
> - ⏳ 阶段 3+：定义/启动分离、State 归位、热键/设置/更新/UI 重构

### 启动流程（当前实现，迁移前）

`main.ahk` 的 #Include 顺序就是启动顺序，不可随意调整：

1. 环境初始化（权限提升、性能参数、窗口匹配模式）。注意：`#Warn All, Off` 抑制了所有 AHK 警告，调试时如遇异常行为需手动排查，不会看到警告输出
2. `base/logger.ahk` → `Logger.Init()`（日志系统必须在 `base/version.ahk` 之后、其他模块之前初始化，确保后续所有模块的日志都能写入）+ `base/version.ahk` → `base/message_box.ahk` → `base/hotkey_schema.ahk` + `base/constants.ahk` + `base/config.ahk`（配置系统必须先于所有模块）
3. `base/eventbus.ahk`（事件总线，模块间解耦通信）
4. `base/file_extractor.ahk`（文件提取模块，管理编译时嵌入资源的运行时提取——logo.png、3 张 TakeOverButton 图片及关卡检测模板）
5. `game_keys.ahk`（游戏按键注册表识别，内部无运行时执行代码，纯类定义）→ `hotkey_actions.ahk`（内部 `#Include touch_injection.ahk`，文件末尾有立即执行的初始化代码：`TouchInjector.Init(3, 1)` + `TouchInjector.Move()`，Touch Injection 在此步即就绪）→ `key_bind.ahk` → `hotkey_control.ahk`（热键四件套）
6. `settings/settings_manager.ahk`（依赖 config + eventbus，内部链式包含 loader → saver → actions）
7. `updater/` 模块（依赖 eventbus）
8. `game_launcher.ahk`（依赖 config + eventbus）
9. 调用 `Loader.LoadSettings()` + `FileExtractor.EnsureExtracted()`（提取嵌入资源到 AppData）+ `GameKeys.Init()`（读取注册表游戏按键 + 启动 10s 轮询定时器，**必须在 HotkeyOn 之前**）+ `HotkeyController.HotkeyOn()` — 加载配置、提取资源、初始化按键识别并激活热键
10. `changelog/` 模块（依赖 eventbus），随后调用 `ChangelogChecker.CheckAndShow()` 检查并显示更新公告
11. `gui.ahk` + `updater_ui.ahk`（依赖所有配置和管理器就绪）
12. `EventBus.Publish("AppStarted")` — 触发自动更新检查 & 游戏自动启动
13. `level_detector.ahk` — 在 `hotkey_actions.ahk` 之后加载，启动 333ms 投票定时器维护关卡状态 `State.InLevel`
14. `game_monitor.ahk` — 最后加载，启动 400ms 定时器监控游戏进程（含自动退出 + 自动开局暂停检测）
14. 发布 `SetSwitchKey` 事件初始化按键，随后发布 `GuiUpdateHotkeyControls`、`GuiUpdateImportantControls`、`GuiUpdateCustomControls` 刷新 GUI 显示

### 模块职责（当前实现，迁移前）

| 模块 | 职责 |
|------|------|
| `base/config.ahk`（含 `base/constants.ahk`、`base/hotkey_schema.ahk`） | 全局配置管理（Config/State/Constants 三个类）。配置持久化到 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`。Config 用懒加载模式（`_IsLoaded` 标志位） |
| `base/token_protector.ahk` | GitHub Token 的 Windows DPAPI 加密保护（`TokenProtector` 类）。`Protect()` 用 `CryptProtectData`（CurrentUser）加密并 Base64 编码，返回带 `dpapi:v1:` 前缀的存储值；`Unprotect()` 解密，无前缀值按旧版明文处理（供迁移）。内存缓冲用 `_SecureZero` 清零。由 `config.ahk` 的 `_ReadGitHubToken`/`_MigrateLegacyToken` 调用，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键 |
| `base/eventbus.ahk` | 发布/订阅事件总线，模块间解耦。核心事件：`AppStarted`（启动完成）、`HotkeyOn`/`HotkeyOff`/`SwitchHotkey`（热键开关）、`SetSwitchKey`/`UnsetSwitchKey`（切换键管理）、`GuiUpdate*` 系列（GUI 刷新）、`SettingsSave`/`SettingsApply`/`SettingsCancel`/`SettingsReset`（设置操作）、`UpdateAvailable`/`UpdateConfirmed`/`UpdateDownloadComplete`（更新流程）、`KeyBindFocusSave`（按键绑定保存）、`HotkeyBindingsChanged`（按键绑定变更，触发冲突检测刷新） |
| `base/file_extractor.ahk` | 管理编译时 `FileInstall` 嵌入资源的运行时提取。`EnsureExtracted()` 将 `logo.ico`（含大小校验防旧版残留）、三张 `TakeOverButton_*.png`（代理作战按钮图像）和关卡检测模板（保留备用，PixelSearch 方案不依赖）统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` |
| `game_keys.ahk` | 游戏按键注册表识别（`GameKeys` 类）。从 `HKCU\Software\HyperGryph\Arknights` 读取 `KEYBOARD_SETTING_V2_h*`（REG_BINARY→hex→JSON），将 Unity KeyId 映射为 AHK 键名。提供 `SendDown`/`SendUp`/`Tap(gameFunc)` 封装方法，供 `hotkey_actions.ahk` 调用。`GetInterceptPattern()` 动态生成热键拦截正则。每 10 秒轮询注册表检测变更，自动重建热键。六层 fallback 防御（精确→小写→numX→alphaX→char*→单字符），读取失败回退默认值并弹警告 |
| `hotkey_control.ahk` | 热键注册/注销/分组切换。三组热键：CombatHotkeys（常规作战）、QuickHotkeys（快捷操作）、StrongHoldHotkeys（卫戍协议）。按标签页启用对应组，组间互斥。拦截正则由 `GameKeys.GetInterceptPattern()` 动态生成。`ActionCallbacks` 数据化（`{Fn, Guarded}`）声明守卫标志，为守卫拦截键注册 Up 变体补发透传 |
| `hotkey_actions.ahk` | 热键触发后的具体功能实现（`Action*` 函数）。内部 `#Include ./base/touch_injection.ahk`。所有游戏按键通过 `GameKeys.SendDown`/`SendUp`/`Tap` 发送，不再硬编码。常规作战 14 个功能带关卡守卫（`GuardInLevel`，读 `State.InLevel` 判定），拦截时经 `KeyForward` 透传原键 |
| `base/touch_injection.ahk` | Windows Touch Injection API 封装（`TouchInjector` 类）。用于暂停选人/技能/撤退等操作的模拟点击，通过 `InitializeTouchInjection`/`InjectTouchInput` 实现，不抢夺鼠标焦点 |
| `key_bind.ahk` | 按键绑定捕获（InputHook），处理用户在设置界面的按键录制 |
| `gui.ahk` | 设置窗口 GUI 全部逻辑（标签页切换、控件事件、托盘菜单）。`UpdateSaveButtonState()` 根据 `IsModified` 和 `HasHotkeyConflicts` 决定保存/应用按钮状态。`RefreshHotkeyConflicts()` 调用 `HotkeyConflictValidator` 进行增量字体标红（仅更新冲突状态变化的控件，使用 `_PrevConflictedControls` 做 diff）。`SwitchTab()` 确认放弃修改后调用 `Config.LoadFromIni()` 显式丢弃内存修改 |
| `base/logger.ahk` | 双轨日志系统（`Logger` 类）。普通日志（15 MiB）和关键日志 WARN/ERROR（5 MiB）分轨滚动存储到 `%AppData%\ArknightsFrameAssistant\PC\logs\`。支持会话级文件命名（`afa-{timestamp}-{pid}-{tick}.log`）、7 天过期清理、敏感值脱敏（`RegisterSecret`/`Redact`）、异常退出检测（启动时检查上一会话是否含 Shutdown 标记）、全局未处理异常回调。所有模块通过 `Logger.Info`/`Warn`/`Error`/`Debug`/`Exception` 写日志 |
| `log_exporter.ahk` | 诊断压缩包导出（`LogExporter` 类）。`CreateArchiveInteractive()` 弹出文件保存对话框，收集所有日志 + 脱敏后的设置文件 + 诊断信息，通过 PowerShell 打包为 ZIP。`OpenLogDirectory()` 打开日志目录 |
| `settings/hotkey_conflict_validator.ahk` | 热键冲突验证器（`HotkeyConflictValidator` 类）。`FindAll(hotkeys, customSettings)` 在同时启用的热键组内检测按键重复，返回 `{HasConflicts, Items, ByControl}`。SwitchHotkey 在全部两组中各检测一次。`GetDisplayName()` 查找 KeyNames/CustomNames 用于错误提示。供 GUI 实时提示和 saver 保存阶段校验共享 |
| `settings/` | 设置读/写/操作。loader.ahk 加载配置，saver.ahk 含验证逻辑（复用 `HotkeyConflictValidator`），actions.ahk 处理重置/保存/应用/取消 |
| `updater/` | 自动更新全流程：version_checker（GitHub API + 国内源 CDN 双源检查，含降级机制）→ downloader → self_replacer（生成批处理自替换）→ updater_manager（协调器，含下载降级逻辑）→ updater_ui。`VersionChecker` 在检查更新时从 GitHub Releases API 提取版本 body 和发布日期，缓存到 `changelog.json`，并构建 changelogBody 通过 `UpdateAvailable` 事件传递 |
| `changelog/` | 更新公告检查和显示。`changelog_checker.ahk` 从 `changelog.json` 缓存读取所有 release 内容（按版本降序），`changelog_ui.ahk` 用只读 Edit 控件显示原始 Markdown。`changelog.ahk` 的 `ChangelogData` 类已清空，保留骨架仅用于向后兼容 |
| `game_launcher.ahk` | 随 AFA 自动启动游戏。`CheckGamePath()` 识别游戏路径，`ProcessGetPath` 失败时降级到 WMI 查询（`_GetProcessPathByWmi`） |
| `game_auto_start.ahk` | 随明日方舟启动自动启动小助手（`GameAutoStartManager` 类）。审核事务临时启用 `SeSecurityPrivilege`，通过 `AuditQuerySystemPolicy` 读取优先，仅在成功审核缺失时调用 `AuditSetSystemPolicy`，复查后恢复令牌权限原状态；错误 1450 按 250/750ms 有限重试。计划任务按动作、参数、工作目录、事件订阅、主体和设置做语义比较，一致时不重写，缺失或漂移时才修复。手动启动执行校准；`--game-autostart` 触发启动在配置开启时跳过校准，配置关闭时尽力删除遗留任务后退出。启动校准失败保留配置和任务，仅在 GUI 就绪后显示一次托盘通知；设置页显式保存仍严格失败且不持久化。`Disable()` 只删除当前用户任务并保留系统审核。任务按 SID 独立命名（`ArknightsFrameAssistant-AutoStartWithGame-{SID}`） |
| `base/message_box.ahk` | 自定义消息框（`MessageBox` 类），替代原生 `MsgBox`。支持同步/异步模式、多种图标和按钮组合，窗口通过忙等循环实现同步 |
| `level_detector.ahk` | 关卡检测投票状态机（`LevelDetector` 类）。每 333ms 轮询对 3 个关卡内专属对象（关卡内文本/退出按钮/暂停按钮）做 PixelSearch 颜色检测（区域用相对比例定位，低分辨率时文本容差放宽到 20），命中 ≥2 个 → `State.InLevel=true`，<2 → `false`。维护守卫判定依据；守卫关闭（`InLevelGuard=0`）时停止轮询并强制 `InLevel=true` |
| `game_monitor.ahk` | 三合一游戏状态监控：(1) **自动退出**：游戏进程退出时自动退出 AFA；(2) **自动开局暂停**：通过 17 点全屏黑屏检测 → 三条扫描线 Loading 识别 → 暂停按钮颜色识别的三阶段状态机，在进关卡时自动暂停；(3) 定时器频率随状态动态调整（400ms → 黑屏后 200ms → 8 秒超时恢复 400ms）。包含 `LoadingPosition()`、`BlackScreenPoints()`、`StopSearchLoading()` 三个辅助函数 |

### 关键设计

- **Constants 类**：常量定义。`Delay30`~`Delay240` 是各帧率对应的延迟毫秒值（取 `ceil(1000/fps)`，例外：`Delay144=8` 多 1ms 余量），`State.CurrentDelay` 依此计算。`FrameOptions` 定义下拉框选项数组，`FrameTextToOldIndex`/`FrameOldIndexToText` 用于 Frame155 双写转换。`KeyNames` 是一个 `Map(keyName, displayName)`，定义所有热键 key 到 GUI 中文显示名的映射——新增热键功能时**必须**在此 Map 中同步添加条目。`CustomNames` 对应自定义设置的显示名，新增自定义配置项时也需同步添加，否则设置无法保存；同时需在 `Config._DefaultCustom` 加默认值——老用户已有 INI 缺新键时由 `LoadFromIni` 的 `_BackfillMissingCustomDefaults()`（v1.9.0+）自动补齐，无需手工迁移。
- **Logger 日志系统**（v1.5.10+）：双轨滚动存储，普通日志（`afa-*.log`）保留 15 MiB，关键日志 WARN/ERROR（`critical-*.log`）单独保留 5 MiB，总容量 20 MiB。按会话隔离（文件名含时间戳+PID+tick），支持 7 天过期清理和容量驱动的分段轮换。`RegisterSecret(value)` 注册敏感值，`_BuildLine` 自动调用 `Redact` 脱敏。启动时检测上一会话是否异常退出（无 Shutdown 标记的上一会话日志文件受保护不被清理）。`SetDebugEnabled(enabled)` 控制 DEBUG 级别是否持久化。所有日志通过 `OutputDebug` 同步输出到 DebugView。容量清理依赖缓存指标（`CachedOrdinaryFiles`/`CachedOrdinaryBytes` 等），每 64 次写入或有容量压力时触发。
- **实时调试控制台**（v1.9.0+，logger.ahk）：`SetConsoleEnabled` 经 `AllocConsole` 创建「AFA 调试日志」窗口。输出**必须用 `WriteConsoleW` DllCall 直接写入**——`FileOpen("CONOUT$")`+`WriteLine` 因 File 对象内部缓冲、控制台不关闭不刷新而空屏。`SetConsoleTextAttribute` 按级别着色（ERROR红/WARN黄/DEBUG灰/INFO白）；打开时显示亮蓝横幅并回放 `RecentLines` 最近日志。安全措施：X 按钮置灰、`SetConsoleCtrlHandler(NULL, TRUE)` 忽略 Ctrl+C/Break、`SetConsoleMode` 清除 `ENABLE_QUICK_EDIT_MODE(0x0040)` 并置 `ENABLE_EXTENDED_FLAGS(0x0080)`（否则点击控制台进入选择态、阻塞进程控制台 I/O 卡死 AFA）。`AllocConsole` 失败（进程已有控制台，如从终端启动）→ 静默降级并**复位 `ConsoleEnabled=false`**（避免 `CloseConsole` 误 `FreeConsole` 脱离调用方终端）。`ConsoleTipShown` 内存标志控"当次会话仅首次"提示。`DebugEnabled`（Important）经 `Loader.LoadSettings()` 接线同时控制持久化与控制台；`version_checker.IsDebugLogging()` 直接读 `Logger.DebugEnabled`（单源，勿重读 INI 造成双源）。
- **Config 读写分离与工作副本**（v1.5.10+）：`GetHotkey()`/`GetImportant()`/`GetCustom()` 返回内存工作副本（`_HotkeySettings`/`_ImportantSettings`/`_CustomSettings`），供 GUI 显示和冲突检测使用。`SetHotkey()`/`SetImportant()`/`SetCustom()` 仅写内存。`LoadFromIni()` 一次性从 INI 重载全部三组设置，用于显式丢弃内存中的未保存修改（取消设置时）。热键注册和运行时逻辑不应触碰工作副本，应使用 `ReadHotkeyFromIni()`/`ReadImportantFromIni()`/`ReadCustomFromIni()` 直接从 INI 读取——这三个方法不会修改内存 Map。`AllHotkeys`/`AllImportant`/`AllCustom` 三个属性直接返回内存 Map 的引用，供遍历使用——注意 `AllHotkeys` 的值是"真实键值"（`RealNewkeyFormat`），而 GUI 显示的是 `VirtualNewkeyFormat` 后的可读值。`TrackChange()` 在检测控件变更时同步将新值写入 Config 内存（确保切换标签页后编辑不丢失）。`SetImportant("Frame", value)` 内部自动同步 `Frame155`，调用方无需手动双写。`UpdateSource`（`"1"` = 国内源默认，`"2"` = GitHub）为 v1.5.6+ 新增的 Important 配置项。三组设置分别通过 `GetHotkey`/`GetImportant`/`GetCustom` 懒加载，各自对应 `_DefaultHotkeys`/`_DefaultImportant`/`_DefaultCustom` 默认值 Map
- **State 类**：运行时状态。`CurrentDelay` 根据游戏帧率设置计算（30/60/90/120/144/165/180/240+ 帧对应不同的 ms 延迟值），引用 `Constants.Delay*` 常量。`GameHasStarted` 跟踪游戏是否曾运行过（用于自动退出判断）。`ReadyForPause` 和 `BlackScreenDetected` 是自动开局暂停状态机的两个标志位。`InLevel` 是关卡检测投票状态机（`LevelDetector`）的输出，守卫消费。
- **EventBus 事件命名约定（目标，新代码必须遵守）**：命令用 `XxxRequested`，事实用 `XxxChanged`/`XxxStarted`/`XxxCompleted`/`XxxAvailable`；每个事件只有一个发布者，payload 字段以契约表为准。旧前缀名（`GuiUpdate*`、`Settings*`、`Update*`、`Set*`/`Unset*`）为迁移前遗留，映射见 `docs/adr/2026-08-17-event-contract-and-naming.md`。
- **自动开局暂停流程**（v1.5.3+）：三阶段状态机 — 全屏黑屏检测 → Loading 扫描线识别（排除红/蓝进关）→ 暂停按钮颜色确认后 ESC 暂停，再用代理作战按钮图像确认避免重复暂停；8 秒超时自动取消，定时器频率随状态动态调整（400ms → 200ms → 超时恢复 400ms）。细节见 `game_monitor.ahk`。
- **热键注册与拦截**：用 `HotIf(HotkeyContext)` 回调（hotkey_control.ahk 顶部）限制热键作用域——鼠标键/滚轮（LButton/RButton/MButton/XButton1/2/Wheel*）返回 `IsMouseInClient()`（悬停在游戏窗口上才触发，修复窗口外任务栏/桌面点击被吞）；键盘键返回 `WinActive("ahk_exe Arknights.exe")` **或** `IsMouseInClient()`（#213：游戏失焦时鼠标悬停游戏窗口也能操作，动作层负责激活游戏；该失焦悬停路径受「自定义」页开关 `State.HoverOperate` 门控，保存/应用后生效，关闭后键盘键仅活动窗口触发，鼠标键/滚轮不受影响）。**动作包装**（#213，`_WrapAction` 于 `_RegisterOne` 注册时套用）：主热键与 OnUp 型动作执行前 `WinActivate` 游戏 + `WinWaitActive`（超时 500ms 则跳过动作，避免按键发往非游戏窗口），激活后不恢复原窗口（焦点留在游戏）；守卫补发 Up 变体（`ActionUpForward`）与 SwitchKey 切换键**不包装**。通过 `GameKeys.GetInterceptPattern()` 动态生成拦截正则——从注册表读取所有游戏按键 + `Escape|RButton|MButton`。AFA 热键绑定的按键若匹配拦截正则，不加 `~` 前缀（阻止原键传递到游戏），否则加 `~` 前缀（透传）。用户自定义游戏按键后，轮询检测到注册表变更自动重建热键，拦截列表随之更新。
- **常规作战关卡守卫与按键透传**（v1.5.12+，hotkey_actions.ahk + hotkey_control.ahk）：常规作战 14 个功能经 `GuardInLevel(actionName, ThisHotkey)` 守卫——关卡内放行、关卡外拦截。拦截时由 `KeyForward` 类透传原键：`ForwardOriginalKey()` 补发 key down 并记录 `InterceptedKeys` 标志（带 `~` 前缀的键本就透传不补发；Up 型热键只补发 key up；滚轮发完整事件）；`ActionUpForward()` 为 Up 变体回调——**补发 key up**（对未按下的键是无害 no-op）：AHK Send 对物理按住的修饰键会“释放-重注入”，被拦截（无 `~`）的修饰键物理 up 也被吞。**Up 变体放行依据**是 `KeyForward.DownHandled`（运行时标记，`GuardInLevel` 在主热键触发时记录，无论守卫放行/拦截）——仅 down 被 AFA 处理过才放行补发 up；游戏外主热键不触发（down 透传）则不放行，物理 up 正常透传（打字不受影响）。`SuppressUp` 标志（**键级 Map**，按 pureKey 记录，非全局布尔）防 Send 注入的 up 被钩子重新捕获触发 Up 变体导致无限递归。键名规范化：`PureKeyName` 保留左右修饰键（`<SHIFT`→`lshift`、`>SHIFT`→`rshift`）且统一大小写（防 `a/A` 拼写不一致漏发 Up），`InterceptedKeys` 关闭大小写敏感。`_RegisterOne()` 为守卫拦截键（非滚轮）注册 `X Up` 变体（类静态方法引用需 `.Bind(KeyForward)`），`DisableGroup()` 同规则注销。失焦边界（按住修饰键 Alt+Tab 切走再松开）已由 DownHandled 机制解决。守卫判定读 `State.InLevel`（无像素检测、无 DPI 切换），拦截日志用 Info 级别（同一按住周期经 `InterceptedKeys` 去重，避免 key repeat 刷屏）。位置函数统一用 `SafeWinGetClientPos(&ww,&wh)`（窗口关闭返回 false 而非抛 TargetError）。
- **关卡检测与守卫判定**（level_detector.ahk + hotkey_actions.ahk）：关卡检测改为 `LevelDetector` 投票状态机——每 333ms 对 3 个关卡内专属对象（关卡内文本/退出按钮/暂停按钮）做 PixelSearch 颜色检测（区域用相对比例定位，低分辨率时文本容差放宽到 20；v1.7.2 起默认容差 3→5/10、关卡内文本识别线加宽，以误识别率为代价适应更多窗口/屏幕配置），命中 ≥2 个置位 `State.InLevel`、<2 复位。`GuardInLevel` 读 `State.InLevel` 判定（无瞬时像素检测，替代旧版瞬时像素检测方案）。`ActionCeaseOperations`（放弃行动）只发 `battleLeftPopup`、`ActionBack`（返回上级菜单）只发 ESC——两者功能分离于 v1.6.1；`BackCeaseOperations`（Important 配置项，默认关闭）开启后 `ActionBack` 在 ESC 后补发 `battleLeftPopup`，还原旧版"放弃行动"行为。`InLevelGuard`（Important 配置项，默认开启）控制 `GuardInLevel` 守卫开关——关闭后 `LevelDetector` 停止轮询并强制 `State.InLevel=true`，守卫直接放行（零 I/O）；开启后恢复 333ms 轮询。**线程抢占风险**（v1.7.0+，已修复）：`LevelDetector` 的 SetTimer 轮询与热键回调同为 priority 0，AHK 单线程下新线程会中断当前线程（`misc/Threads.htm#Interrupt`）——Poll 的 PixelSearch（每次最多 16 色）会随机插入时序敏感动作的 `USleep` 忙等，拉长实际间隔（5~50ms）导致过帧波动（一次过两帧/不过帧）。修复：时序敏感动作的 Send/Touch 序列加中断保护（单次 `Tap` 动作无需）——**过帧三件套（16/33/166ms）保留 `Critical`/`Critical "Off"`**（帧数精确性依赖完全不可中断，连热键也不放行）；**暂停选中/技能/撤退、一键技能/撤退、视角切换 v1.9.4 起改用 `Thread "NoTimers"`/`Thread "NoTimers", false`**（只挡定时器轮询，放行其他热键——动作中可即时响应倍速等热键；`Critical` 会连热键一起挡掉，故非过帧动作不再用）；`USleep` 到期时记录 overshoot 诊断日志（`current-target` 换算毫秒，≥1ms 时 `Logger.Debug`）便于观察中断。
- **GameKeys 类**（v1.5.10+）：负责游戏按键的动态识别。核心流程：`Init()` 首次读取注册表并启动 10s 定时器 → `_OnPoll()` 定时比对 hex，有变更则重新解析 JSON → 更新 `_Bindings` → 调用 `HotkeyController.EnableByTab()` 重建热键。`SendDown`/`SendUp`/`Tap` 三个方法封装了查表+Send 逻辑，接受注册表中的 function 名（如 `"releaseSkill"`），内部转换为用户实际绑定的 AHK 键名。游戏内绑定的鼠标键（自定义名 `mouseLeft/Right/Middle/Forward/Back` → `LButton/RButton/MButton/XButton2/XButton1`，标准 Unity `Mouse0-4`）同样映射进 `_Bindings` 参与拦截正则。注册表键名前缀匹配 `KEYBOARD_SETTING_V` 应对游戏版本更新。ESC 和 LButton 不经过 GameKeys（不可重新绑定的系统级按键）。
- **更新渠道**：`UpdateChannel` 设置为 1（正式版）或 2（测试版），版本检查器据此选择检查 stable releases 还是包含 pre-release。GUI 通过下拉框切换，默认正式版。
- **双源更新与自动降级**（v1.5.6+）：更新系统支持 GitHub API 和国内源（腾讯云 COS+CDN）两源，`UpdateSource` 选首选源，失败自动降级备选源（`token_invalid`/`rate_limited` 静默降级）。国内源用 CDN 静态 `version.json`（`version`/`downloadUrl`/`releases`），`releases` 格式与 GitHub API 一致，复用 changelog 缓存。发布时 Action（`.github/workflows/release-sync.yml`）自动同步 exe 和 version.json 到 COS。**v1.8.1+ 双源 SHA-256 下载校验**：`expectedHash` 从版本检查结果一路透传到 `downloader`，下载完成后用 `_GetFileSha256`（分块流式 `CryptHashData`）校验，不匹配则删除文件并弹窗中止（防篡改）。GitHub 源从 asset 的 `digest` 字段（`sha256:<hex>`，正则限定 `"name":"AFA.exe"` asset）提取；国内源从 `version.json` 的 `sha256` 字段提取。`version.json` 的 `sha256` 由发布 Action 计算写入。
- **配置文件**：INI 格式，三个 Section：`[Hotkeys]`、`[Main]`、`[Custom]`。`GitHubToken` 使用 Windows DPAPI（`token_protector.ahk` 的 `TokenProtector` 类）按当前 Windows 用户加密，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键（带 `dpapi:v1:` 前缀），读取经 `_ReadGitHubToken()` 解密。旧版明文 `GitHubToken` 键在启动时自动迁移为加密格式并删除明文（迁移失败会保留原配置并提示恢复写入权限）。
- **数据文件**：`%AppData%\ArknightsFrameAssistant\PC\changelog.json` 存储从 GitHub Releases API 拉取的所有版本发布内容，每次版本检查时更新。由 `VersionChecker._SaveChangelogCache()` 写入，`ChangelogChecker` 读取。
- **GUI 脏值对比**：`GuiManager` 维护 `_InitialValues` 快照和 `_IsModified` 标志。`CaptureInitialSnapshot()` 在设置加载/保存/应用后保存所有控件当前值，`TrackChange(key)` 在控件变更时将当前值与快照对比，同时将新值同步写入 Config 内存（热键控件和 SwitchHotkey 已由 `KeyBinder.EndChange` 提前写入，`TrackChange` 负责其余控件）。新增可修改控件时需在 `CaptureInitialSnapshot` 中添加对应 key，并在控件事件中调用 `TrackChange`。
- **热键冲突实时检测**（v1.5.10+）：`HotkeyConflictValidator.FindAll()` 在 CombatHotkeys+QuickHotkeys 组和 StrongHoldHotkeys 组内分别检测重复（组间不互检）。`GuiManager.RefreshHotkeyConflicts()` 用增量字体更新——仅对新进入冲突的控件标红 `cD93025`、离开冲突的恢复 `cDefault`，避免全页闪烁。`UpdateSaveButtonState()` 据 `IsModified && !HasHotkeyConflicts` 决定按钮启用。`key_bind.ahk` 的 `NotifyBindingChanged` 发布 `HotkeyBindingsChanged` 触发刷新。切换标签页不丢弃修改，冲突状态跨标签页保持。`saver.ahk._CheckKeyConflicts()` 复用同一 validator 作为保存前最后防线
- **key_bind.ahk 的 WM_LBUTTONDOWN 处理**：`OnMessage(0x0201, WM_LBUTTONDOWN)` 是进程级回调，会在所有 GUI 的 Edit 控件点击时触发。为防止非设置窗口的 Edit 控件误触发按键录制，回调开头有父窗口检查：`if (KeyBinder.ControlObj.Gui.Hwnd != GuiManager.MainGui.Hwnd) return`。新增 Edit 控件且不需要按键录制功能时，确保其父窗口不是 `GuiManager.MainGui`。点击非 Edit 区域时自动聚焦取消按钮（`GuiManager.FocusCancelButton()`），取消普通 Edit 控件的选中状态。
- **Alt+F4 始终退出**：通过 `#HotIf WinActive(GuiManager.WindowName)` + `!F4::ExitApp()` 拦截设置窗口的 Alt+F4，始终彻底退出 AFA。标题栏 X 按钮仍由 `ExitOnWindowClose` 设置控制（关闭窗口 or 退出）。
- **AHK v2 GUI 布局要点**：`xs`/`ys` 引用**最近**的 `Section`（叠加布局中会追到前一个分类的 Section 导致偏移，每组首控件应用绝对坐标如 `x160 y45`）。Text 的 `Center` 仅水平居中，文字要填满控件需去掉固定高度自适应（`hp`）而非依赖 Center。
- **"其他设置"页面结构**（v1.5.5+）：左侧 Text 导航项（`NavItems`）+ 右侧四分类内容叠加（`LaunchControls`/`UpdateControls`/`CustomControls`/`AboutControls`），经 `_SwitchOtherCategory` 切换 Visible。`OtherCategories` Map（分类名→[控件组, 导航索引]）统一管理，新增分类只需加一行。导航切换有 `force` 参数（标签页切换强制显示、导航点击不传以守卫重复点击）。关于页是纯展示页，切换时禁用保存/应用按钮。
- **更新源下拉框**（v1.5.6+）："更新"分类中新增"更新源"下拉框（国内源/GitHub，默认国内源）。切换时 `_OnUpdateSourceChange()` 联动 Token 复选框、输入框、提示文字三者的 `Enabled` 状态——选国内源时全部灰掉，选 GitHub 时恢复。
- **Frame155 双写机制**（v1.5.5+）：帧率存储有两个 INI 键 — `Frame155` 存文本值（如 "90"、"180"、"240+"），`Frame` 存旧版索引（1~7，180 映射为 6）。新版优先读取 Frame155，回退读 Frame 旧序号并转换。保存时双写两个键，`MigrateFrameRate()` 在启动时自动将旧序号迁移到 Frame155。新增帧率时需同步更新 3 处：`Constants.FrameOptions`（下拉框选项）、`Constants.FrameTextToOldIndex`（文本→旧序号）、`Constants.FrameOldIndexToText`（旧序号→文本）。
- **DropDownList.Value 陷阱**：AHK v2 的 `DropDownList.Value` **始终使用索引**（1-based），与 `AltSubmit` 无关。`AltSubmit` 只影响 `Gui.Submit()` 的返回值格式（有→索引，无→文本）。如果下拉框去掉 `AltSubmit` 以让 Submit 返回文本，赋值 `.Value` 时仍需传索引，需做文本→索引转换。
- **Map.Delete 陷阱**：AHK v2 的 `Map.Delete(key)` 对不存在的键抛 `UnsetItemError`（`Item has no value`），删除前需 `Has` 检查（带默认值参数的是 `Get`，`Delete` 没有）。
- **热键频率阈值**：AHK v2 用内置变量 `A_MaxHotkeysPerInterval`（默认 66 热键/2000ms）而非 v1 的 `#MaxHotkeysPerInterval` 指令；被拦截的游戏键每个按键触发 down+up 两个热键，极速连打 WASD 等易超默认值弹警告框，main.ahk 已设 200。
- **明日方舟按键限制**：游戏设置禁止将 Ctrl 绑定为游戏内按键，故 Ctrl 不命中拦截正则——纯 Ctrl 热键的卡键路径无法在真实环境复现/测试。
- **Send 注入会触发热键**：AHK 的 Send 命令注入的按键事件默认会被自身钩子捕获并触发热键。Up 变体回调用 Send 补发 key up 时，若放行条件不含递归抑制，注入的 up 会再次触发 Up 变体 → 无限循环补发 → 系统键盘状态被轰炸、按键完全失灵。回调内"Send 同键"的机制必须加防递归标志（如 `KeyForward.SuppressUp`，**须键级作用域**——用 `Map(pureKey→true)` 而非全局布尔，全局布尔会在多键同松时让第二个键的物理 Up 落在第一个键补发窗口内被误挡，`HotkeyContext` 条件失败→物理 up 被吞→卡键）。
- **AHK 线程优先级 vs Critical/NoTimers**（v1.9.4+，hotkey_actions.ahk）：AHK 优先级规则是"**新线程优先级低于当前线程才不能中断**"，且低优先级事件按下会被**直接丢弃（not buffered）**而非排队（`misc/Threads.htm#Priority`）——"提高热键优先级、降低定时器优先级"的方案有静默丢键风险（动作快结束时按的低优先级热键会整个丢失），AHK 文档明确 Critical 因能缓冲事件而优于 Priority。`Thread "NoTimers"` 是"只挡定时器、放行热键"的精确工具（`Thread.htm`："similar to Critical except that it only prevents interruptions from timers"），线程级设置、无需改热键注册。选用原则：需"防定时器轮询抖动、但允许其他热键中断"时用 `Thread "NoTimers"` 代替 Critical；需"完全不可中断"（帧数精确）时保留 Critical。
- **cmd `chcp 65001` 批处理陷阱**（self_replacer.ahk）：cmd 按当前控制台代码页解析批处理文件，中文 Windows 默认 GBK。在**批处理内部**执行 `chcp 65001` 会触发 cmd 重读文件并**错位解析中文行**，报 "is not recognized" 乱码错误（如 `'�我'`）。**触发需同时满足**：行以多字节中文字符结尾（cmd 会把行尾换行符吞进上一个多字节字符）。已实测规避方式：每行以 ASCII 结尾（如 `...`，与 `正在等待程序关闭...` 风格一致）、中文块前插 ASCII 分隔行、或把中文内容合并成单行。彻底修复需权衡：在 cmd 命令行前置 chcp（`cmd /c "chcp 65001 >nul & call 批处理"`）会引入 `cmd /c "..." & ...` 命令行签名、增加杀软误报风险（本分支反误报优化所忌）；批处理改 GBK 编码则 update 日志变 GBK（LogExporter 按 UTF-8 读取会乱码）。本分支决定保留 `Run batchFile` + 内部 chcp，用 ASCII 行尾规避。
- **File.Read 只接受 1 参数**：AHK v2 的 `File.Read(Characters)` 只读字符串，不支持 v1 的 `Read(&Buffer, Count)` 二参形式——传 2 参会抛 `Too many parameters passed to function.`。读原始字节到 Buffer 须用 `File.RawRead(&Buffer, Bytes)`（返回实际读取字节数）；哈希等二进制读取建议分块流式，避免大文件整体载入内存。
- **AHK 箭头函数限制与函数名引用**：AHK v2 的箭头函数 `(p) => expr` **只支持单一表达式，不支持 `{ }` 语句块**——多行逻辑需用**嵌套函数闭包**实现（`Functions.htm#closures`：在函数内 `Name(params) { ... }`，捕获外层局部变量即闭包，可用于 Hotkey 回调）。另外 `ActionCallbacks` 等 Map 里的 `Fn: ActionBack` 存的是**函数引用（Func 对象）**而非字符串——AHK v2 中函数定义即同名只读变量、其值即 Func 对象，可直接 `Fn(ThisHotkey)` 调用（`Hotkey` 回调同样接受函数对象）。AHK v2 的 `Func()` 只接受**函数名字符串**，对函数对象套 `IsObject(fn) ? fn : Func(fn)` 规范化是死代码（v1 残留认知），空 `catch` 还会掩盖动作内部真实异常（修复见 hotkey_control.ahk 的 `_WrapAction`）。
- **`SetTimer Func, 0` 是解除定时器**：AHK v2 中它取消待触发的回调、**不调用函数**；与 `SetTimer Func, -8000`（一次性定时调用）含义不同，勿混淆（曾有审查误判"0 会触发回调"）。
- **FrameSkip 自定义延迟**（v1.5.5+）：三档过帧延迟（16ms/33ms/166ms）可通过"自定义"分类中的"过帧档位1/2/3" Edit 控件自定义。延迟值存为 `FrameSkip*Delay` 自定义配置项，Action 函数通过 `Config.GetCustom()` 读取。`GuiManager` 维护 `FrameSkipDelayKeys` 列表和 `FrameSkipLabels` Map，`_UpdateFrameSkipLabels()` 在保存/应用后动态更新"常规作战"标签页的过帧行文本。
- **FileInstall 嵌入资源**：编译时通过 `FileInstall` 将 `logo.ico`、`resources/images/TakeOverButton_*.png`（三张代理作战按钮截图）和关卡检测模板（保留备用，PixelSearch 方案不依赖）打包进 exe，运行时由 `FileExtractor.EnsureExtracted()` **统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` 子目录**（避免散落根目录）。`logo.ico` 使用文件大小校验（`FileGetSize`）判断是否需要重新提取以防止旧版本残留。新增需要嵌入的资源时遵循此模式，在 `FileExtractor` 类中添加路径和提取逻辑。
- **GitHub Action 发布同步**（v1.5.6+）：`.github/workflows/release-sync.yml` 监听 Release 发布事件，将 `AFA.exe` 和 `version.json` 上传到 COS 并刷新 CDN。`.github/scripts/build_version_json.py` 构建含全量 releases 历史的 `version.json`，处理首次初始化（COS 上无文件时自动创建），支持 stable/beta 双通道独立 version.json。Action 需要 5 个 GitHub Secrets（`COS_SECRET_ID`/`COS_SECRET_KEY`/`COS_BUCKET`/`COS_REGION`/`CDN_DOMAIN`）。`release-sync.yml` 不在 `.gitignore` 中，会被 git 跟踪。发布时对 `AFA.exe` 计算 sha256 写入 `version.json`（`--sha256` 参数）；**GitHub Actions step outputs 大小写敏感**——输出键名须用小写 `sha256`，否则引用为空。
- **GUI 控件统一管理**：对于批量重复的控件组（如过帧延迟字段、导航分类），优先使用列表/Map 集中定义再循环遍历（如 `FrameSkipDelayKeys`、`OtherCategories`），避免单个 try 块的 OR 链，便于扩展。
- **顶部标签页管理器**（v1.5.12+，gui.ahk）：`TabItems` 数组描述四个标签（`keyBind`/`quick`/`strongHoldProtocol`/`other`），`CanHide` 控制可否隐藏（`other` 不可隐藏）。`TabOrder`/`HiddenTabs` 两个 Important 配置项存顺序与隐藏列表，通过两个 **Hidden Edit 表单变量**（`vTabOrder`/`vHiddenTabs`）与 `MainGui["TabOrder"]` 交互——必须放布局链之外（如 `sepCustom` 前），否则破坏自定义页左列 `y+10` 相对定位。`AppliedTabSettings` 存已应用快照，`IsTabVisible()` 优先读快照、`tabItem.Visible` 是工作态（统计当前可见性直接遍历 `tabItem.Visible`）。眼睛图标统一 `U+E890`（蓝=显示/灰=隐藏），禁止隐藏最后一个功能标签时弹窗。
- **Segoe MDL2 Assets 图标码点**：`U+E890`=View（眼睛，可靠）；`U+E8F4`=NewFolder（**不是闭眼**）；`U+E9CE` 在部分系统字形缺失会显示问号。选图标码点前用像素渲染实测确认，不要凭记忆推断。`game_monitor.ahk`/`hotkey_actions.ahk` 用 `SetThreadDpiAwarenessContext(-3)` 是局部临时切换（像素检测用），不影响 GUI 主窗口 DPI 基准。
- **AHK DPI 与坐标换算**：AHK v2 是 **system DPI aware**（非 per-monitor，官方文档明确"not marked as per-monitor DPI-aware"）。`A_ScreenDPI`=主屏 DPI 是正确基准，系统对副屏做 bitmap scaling 并统一坐标——多屏不同缩放下用 `A_ScreenDPI` 换算即可，不要用 `GetDpiForWindow`。`MouseGetPos` 在 `CoordMode "Mouse","Client"` 下返回**物理像素**，而 GUI `Move()` 用**逻辑像素**（DPI 缩放），两者换算：`物理像素 * 96 / A_ScreenDPI`。
- **AHK Text 控件运行时改背景色不可靠**：`Opt("Background" color)` 对已创建 Text 控件改背景色，文档明确"the control might choose to ignore it"——高亮能显示但取消高亮不刷新，`Sleep -1`/`Redraw()` 均无法绕过。需要运行时切换背景时用**双控件叠加**（固定背景层 + 高亮层，通过 `Visible` 切换），并将高亮层加入命中测试（`GetTabManagerHit`）。注意 `_ShowControls` 会把组内所有控件设为可见（含高亮层），需在分类切换后重绘重置。
- **动态对齐 vs 绝对坐标**：GUI 中右列对齐左列时，用 `GetPos` 动态读取左列控件实际 y 存入类成员（如 `TabManagerTitleY`），而非硬编码绝对坐标——AHK 的 `y+10` 相对"前一个控件底部"（非 Section），绝对坐标估算易随字体/布局漂移。控件尺寸/垂直偏移（`y+4` 等）在各子控件间应统一，否则视觉高度不齐。

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

- **AFA**：在 `src/lib/version.ahk` 的 `Version.Number` 中定义，版本检查器通过 GitHub API 或国内源 CDN 对比此值与远程 release tag/version.json
- **AHK**：当前为 v2.0.26，无需向用户确认
- **Windows**：跟随测试环境，自行获取，无需向用户确认
