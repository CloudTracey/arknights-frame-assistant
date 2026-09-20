# 模块职责与启动流程

> 本文件是 AGENTS.md 的参考资料分册：**改某个模块前查这里**，日常任务无需通读。
> 内容与 `src/` 实际结构对齐（`CONTRIBUTING.md` 的项目结构树已滞后，以其为准的是本文件）。

## 启动流程（当前实现）

所有 `.ahk` 只定义、零顶层副作用；`src/main.ahk` 的 `#Include` 仅负责加载定义，启动由 `App.Bootstrap()` 显式执行。

> **本流程用 `StartupMark("…")` 语义标记定位，不写行号**——行号会随任何一处增删而整体错位，而标记串只在阶段含义变化时才动。
> 快速查看当前标记序列：`grep -n 'StartupMark(' src/main.ahk`。

当前启动顺序：

1. **环境初始化**（`App.Bootstrap()` 开头，`StartupMark` **之前**）：`ListLines False`、`KeyHistory 200`、`ProcessSetPriority "High"`、`SendMode "Input"`、`SetKeyDelay -1,-1`、`A_MaxHotkeysPerInterval := 200` 且 `A_HotkeyInterval := 0`（详见 [ahk_v2_pitfalls.md](ahk_v2_pitfalls.md) 的热键频率阈值条）、`SetMouseDelay -1`、`SetWinDelay -1`、`SetDefaultMouseSpeed 0`、`SetTitleMatchMode 3`、`CoordMode "Mouse","Client"`、`timeBeginPeriod(1)`、`OnExit HandleAfaExit`。
   注意：`#Warn All, Off` 抑制了所有 AHK 警告，调试时如遇异常行为需手动排查，不会看到警告输出。
2. **单例识别**（无标记）：`SingleInstance.Acquire()` 失败时，`--game-autostart` 触发则静默退出，手动重复启动则弹窗提示后退出（弹窗早于 `SettingsService.Initialize()`，故先按 INI 语言 `I18n.Init`）。
3. **提权**（无标记）：非管理员先 `SingleInstance.Release()` 让位互斥体，再以 `*RunAs` + `/restart`（并透传 `--game-autostart`）重启，随后退出本进程。
4. **管理员进程日志** — `StartupMark("日志初始化")`：`Logger.Init()`；记录脚本名与互斥体句柄。
5. **初始化各域** — `StartupMark("模块初始化")`：`Config.InitPath()` → `GameClientRegistry.Init()` → `LogExporter.Init()` → `HotkeyActionsStart()` → `LevelDetector.Init()` → `KeyBinder.Start()` → `HotkeyService.Init()` → `TimingService.Init()` → `SettingsService.Init()` → `VersionChecker.Init()` → `Updater.Init()` → `ChangelogChecker.Init()` → `ChangelogUI.Init()` → `GameLauncher.Init()`。
6. **加载设置** — `StartupMark("设置加载")`：`SettingsService.Initialize()` 加载配置；`Logger.RegisterSecret()` 注册 Token 与脚本路径；若 `Logger.PreviousAbnormalFile != ""`（上一会话异常退出）则提示导出诊断包。
7. **随游戏自动启动校准** — `StartupMark("随游戏自动启动校准")`：`AppContext.SetStartedByGameAutoStart()` + `GameAutoStartManager.Reconcile()`；关闭该功能时若返回 `shouldExit` 则只清理任务并退出。
8. **资源与游戏按键** — `StartupMark("资源提取")` 起，经 `StartupMark("游戏按键识别")`、`StartupMark("热键注册")`：`FileExtractor.EnsureExtracted()` 提取嵌入资源；`GameKeys.Init()`（读注册表游戏按键 + 启动 10s 轮询定时器，**必须在 `HotkeyOn` 之前**）→ `HotkeyService.HotkeyOn()` 激活热键 → `HookHealth.Start()` 启动键盘钩子健康探针（**必须在 `HotkeyOn` 之后**，其监视键位表来自已注册热键）。
9. **GUI 初始化** — `StartupMark("GUI 初始化")`：发布 `ChangelogShowRequested` → `GuiManager.Start()`（含 Alt+F4 退出热键注册）→ `UpdateUI.Init()`；随游戏自启校准失败的托盘提示在此处（GUI 就绪后）只发一次。
10. **启动收尾** — `StartupMark("启动收尾")` 至 `StartupMark("")`：发布 `AppStartCompleted`（触发自动更新检查与游戏自动启动）→ `GameMonitor.Start()` → 发布 Legacy 事件 `SetSwitchKey`、`GuiUpdateHotkeyControls`、`GuiUpdateImportantControls`、`GuiUpdateCustomControls` 完成 GUI 初始化 → `StartupMark("")` 输出总耗时。

> 早期版本的 AGENTS.md 曾漏记 `GameClientRegistry.Init()`、`LogExporter.Init()`、`HookHealth.Start()` 三个调用。以本文件为准。

## 模块职责

### 架构分层

四层单向依赖 `bootstrap → ui → core → base`；core 不得引用 ui，base 不得引用 core/ui。静态校验：`python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS`。

### base 层（无依赖）

| 模块 | 职责 |
|------|------|
| `base/config.ahk`（含 `base/constants.ahk`、`base/hotkey_schema.ahk`） | 全局配置管理（`Config` 类；`Constants` 与 `HotkeySchema` 为独立类）。配置持久化到 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`。Config 用懒加载模式（`_IsLoaded` 标志位） |
| `base/custom_hotkey_store.ahk` | `CustomHotkeys.json` 唯一 owner（自定义按键独立存储，与 Settings.ini 隔离）。UTF-8 JSON v2、写定式（键序固定 `key/name/func/arg/type`，func=按键功能码、arg=参数文本）+ 字符集白名单 + 严格正则读取；解析失败备份 `.bak` 并回退空列表（v1 脚本格式不迁移，按损坏处理）；写入走临时文件 + `ReplaceFileW` 原子替换；清空写空数组不删文件 |
| `base/token_protector.ahk` | GitHub Token 的 Windows DPAPI 加密保护（`TokenProtector` 类）。`Protect()` 用 `CryptProtectData`（CurrentUser）加密并 Base64 编码，返回带 `dpapi:v1:` 前缀的存储值；`Unprotect()` 解密，无前缀值按旧版明文处理（供迁移）。内存缓冲用 `_SecureZero` 清零。由 `config.ahk` 的 `_ReadGitHubToken`/`MigrateGitHubToken`（启动时把旧版明文迁移为加密值）调用，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键 |
| `base/eventbus.ahk` | 发布/订阅事件总线，模块间解耦。事件清单见 [reference.md](reference.md#eventbus-事件清单) |
| `base/file_extractor.ahk` | 管理编译时 `FileInstall` 嵌入资源的运行时提取。`EnsureExtracted()` 将 `logo.ico`（含大小校验防旧版残留）、三张 `TakeOverButton_*.png`（代理作战按钮图像）和关卡检测模板（保留备用，PixelSearch 方案不依赖）统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` |
| `base/game_target.ahk` | 「当前目标游戏窗口」的唯一 owner：`Hwnd`/`Pid`/`ExePath`/`ServerId`。未绑定客户端实例时宽松回退旧语义 `ahk_exe Arknights.exe`（决策 D2），保证升级零回归、降级不弹窗；**禁止其他模块再直接写 `"ahk_exe Arknights.exe"`**。只持有状态与查询 API，绑定/仲裁由 `core/game/game_client_registry.ahk` 驱动 |
| `base/server_profile.ahk` | 区服元数据与识别的唯一 owner（纯数据 + 纯函数，不引用 core/ui、无副作用）。从安装目录/可执行文件推断区服并给出对应 Unity PlayerPrefs 注册表根。多区服细节见 [key_designs_hotkey.md](key_designs_hotkey.md#多区服与热路径预算) |
| `base/single_instance.ahk` | 单例识别（命名互斥体 `ArknightsFrameAssistant-Singleton`）。与可执行文件名无关（编译版/未编译版行为一致），不依赖 WMI/COM，启动早期即可安全使用。有意让新进程接管前（托盘重启/提权重启）须先 `Release()`，避免新进程被误判为重复启动 |
| `base/i18n.ahk` + `base/locales/*.ahk` | 国际化核心（`I18n` 类）与五语言资源（`LocaleZhHans`/`LocaleZhHant`/`LocaleJaJP`/`LocaleKoKR`/`LocaleEnUS`）。详见 [i18n.md](i18n.md) |
| `base/metrics.ahk` | UI 度量与字体（`Metrics` 类）：`FontFor(locale)` 返回各语言推荐字体，`TextWidth()` 估算文本像素宽度（供控件宽度按语言自适应） |
| `base/logger.ahk` | 双轨滚动日志 + 实时调试控制台。详见 [key_designs_base.md](key_designs_base.md#logger-日志系统) |
| `base/theme.ahk` | 配色与窗口资源的唯一 owner。详见 [key_designs_ui.md](key_designs_ui.md#主题生命周期与预览) |
| `base/message_box.ahk` | 自定义消息框（`MessageBox` 类），替代原生 `MsgBox`。支持同步/异步模式、按钮组合与按语言自适应的布局（配色由 `Theme` 管理、字体由 `Metrics.FontFor` 提供），窗口通过忙等循环实现同步 |
| `base/touch_injection.ahk` | Windows Touch Injection API 封装（`TouchInjector` 类）。用于暂停选人/技能/撤退等操作的模拟点击，通过 `InitializeTouchInjection`/`InjectTouchInput` 实现，不抢夺鼠标焦点 |
| `base/timing.ahk` | 高精度延迟工具（`USleep`），供 core 层过帧动作用；基于 `QueryPerformanceCounter`/`QueryPerformanceFrequency` |
| `base/key_format.ahk` | 热键键值格式化工具（`KeyFormat`），供 UI 与 core 共用。`VirtualNewkeyFormat` 生成可读显示值 |
| `base/version.ahk` | 版本管理（`Version` 类）：`Version.Number` 是 AFA 版本号唯一来源；同文件承载 Ahk2Exe 编译元数据指令（版本/语言/名称/公司/版权/描述） |
| `base/version_utils.ahk` | 版本/JSON 纯工具（`VersionUtils`），供 updater/changelog 复用：JSON 字符串反转义、版本号比较等 |
| `base/changelog_format.ahk` | 更新公告多语言裁剪（`ChangelogFormat`）。Release body 用 HTML 注释分段（`<!-- afa:lang zh-Hans -->`），渲染时按当前语言裁剪，无标记则回退整篇原文；裁剪前先剥离 GitHub 页面用的 `<details>/<summary>` 折叠标签 |
| `base/tray.ahk` | 托盘提示工具（`ShowTrayTip`/`HideTrayTip`）。包装 AHK 内建 `TrayTip`，避免 core 层散落内建调用；发出前 `Logger.Debug` 记录（标题+消息前缀截断），便于核对「没看到提示」是否真的没发出 |
| `base/window.ahk` | 窗口/屏幕工具，供 core 与 UI 复用。`SafeWinGetClientPos()` 窗口不存在时返回 false 而非抛 `TargetError`；安全像素搜索包装（`PixelSearch` 内部 GDI 调用失败会抛 `OSError`） |

### core 层（依赖 base）

| 模块 | 职责 |
|------|------|
| `core/hotkey/game_keys.ahk` | 游戏按键注册表识别 + 注入（`GameKeys` 类）。详见 [key_designs_hotkey.md](key_designs_hotkey.md#gamekeys-类) |
| `core/hotkey/hotkey_service.ahk`（`HotkeyService`） | 热键注册/注销/分组切换。详见 [key_designs_hotkey.md](key_designs_hotkey.md#热键注册与拦截) |
| `core/hotkey/hotkey_actions.ahk`（`HotkeyActions`） | 热键触发后的具体功能实现（`Action*` 函数）。触控注入初始化由 `App.Bootstrap()` 调用 `HotkeyActionsStart()` 完成；所有游戏按键通过 `GameKeys.SendDown`/`SendUp`/`Tap` 发送，不再硬编码。常规作战 14 个功能带关卡守卫（`GuardInLevel`，读 `LevelDetector.IsInLevel()` 判定），拦截时经 `KeyForward` 透传原键 |
| `core/hotkey/custom_script.ahk`（`CustomScriptEngine`） | 自定义按键功能引擎：「功能码 + 参数」模型（目前仅 `click` 单击，参数为 `(x, y)` 0-1 比例坐标、最多 4 位小数，执行时按当前窗口尺寸换算像素，以 `HotkeyActions._ClickButton` 同款 Send 点击并还原光标）。对外仅 `Validate`/`Reload`/`RunById`/`IsRegistered` 四方法；解析只在保存/Reload 慢路径，触发时 O(1) 缓存查表零 IO。功能注册表（Builtins）供未来扩展。执行整体 `Thread "NoTimers"` + `finally` 无条件归位；combat 类型经 `GuardInLevel` 受关卡守卫 |
| `core/hotkey/timing_service.ahk` | 时序服务：`CurrentDelay`/`ClickDelay` 唯一 owner，提供 getter 与 `Refresh()` |
| `core/settings/settings_service.ahk`（`SettingsService`） | 唯一配置写口。`Initialize()` 启动加载，`Save/Apply/Cancel/Reset()` 处理 GUI 命令，`UpdatePersistedValue(key, value)` 单键原子写入并发布 `SettingsChanged`。保存/应用/重置后通过 `SettingsSaved/Applied/Reset` 驱动 HotkeyService/TimingService/LevelDetector/GuiManager 刷新 |
| `core/settings/hotkey_conflict_validator.ahk` | 热键冲突验证器（`HotkeyConflictValidator` 类）。`FindAll(hotkeys, customSettings, customHotkeys)` 在同时启用的热键组内检测按键重复（自定义按键按「按键类型」并入两组：global 并入两组、combat/quick 并入常规组、strongHold 并入卫戍组；同对冲突跨组去重），返回 `{HasConflicts, Items, ByControl}`。SwitchHotkey 在全部两组中各检测一次。`GetDisplayName()` 查找 KeyNames/CustomNames/自定义行名称用于错误提示。供 GUI 实时提示和 SettingsService 保存阶段校验共享 |
| `core/monitor/level_detector.ahk` | 关卡检测投票状态机（`LevelDetector` 类）。详见 [key_designs_hotkey.md](key_designs_hotkey.md#关卡检测与守卫判定) |
| `core/monitor/game_monitor.ahk`（`GameMonitor` 类） | 三合一游戏状态监控：(1) **自动退出**：游戏进程退出时自动退出 AFA；(2) **自动开局暂停**：通过 17 点全屏黑屏检测 → 三条扫描线 Loading 识别 → 暂停按钮颜色识别的三阶段状态机，在进关卡时自动暂停；(3) 定时器频率随状态动态调整（400ms → 黑屏后 200ms → 8 秒超时恢复 400ms）。包含 `LoadingPosition()`、`BlackScreenPoints()`、`StopSearchLoading()` 三个辅助函数 |
| `core/game/game_client_registry.ahk` | 游戏客户端实例注册表：枚举运行中的 `Arknights.exe` 实例、维护 PID→区服缓存、仲裁前台客户端，并发布 `GameClientsChanged`/`ForegroundClientChanged` 事实事件。枚举/路径查询是慢路径，只允许在定时器或事件线程中调用；**热键路径不得进入本模块的 IO 方法**。带重入保护（刷新可由 GameMonitor 400ms 定时器 / ScheduleRefresh 一次性定时器 / Init 三入口交错调用） |
| `core/launch/game_launcher.ahk` | 随 AFA 自动启动游戏。`CheckGamePath()` 识别游戏路径，`ProcessGetPath` 失败时降级到 WMI 查询（`_GetProcessPathByWmi`） |
| `core/launch/game_auto_start.ahk` | 随明日方舟启动自动启动小助手（`GameAutoStartManager` 类）。审核事务临时启用 `SeSecurityPrivilege`，通过 `AuditQuerySystemPolicy` 读取优先，仅在成功审核缺失时调用 `AuditSetSystemPolicy`，复查后恢复令牌权限原状态；错误 1450 按 250/750ms 有限重试。计划任务按动作、参数、工作目录、事件订阅、主体和设置做语义比较，一致时不重写，缺失或漂移时才修复。手动启动执行校准；`--game-autostart` 触发启动在配置开启时跳过校准，配置关闭时尽力删除遗留任务后退出。启动校准失败保留配置和任务，仅在 GUI 就绪后显示一次托盘通知；设置页显式保存仍严格失败且不持久化。`Disable()` 只删除当前用户任务并保留系统审核。任务按 SID 独立命名（`ArknightsFrameAssistant-AutoStartWithGame-{SID}`） |
| `core/launch/app_context.ahk` | 应用启动上下文：`StartedByGameAutoStart` 唯一 owner，Bootstrap 写入，GameAutoStartManager/LogExporter 读取 |
| `core/updater/` | 自动更新全流程：`release_repository.ahk`（GitHub/国内源检查与 changelog 缓存）→ `version_checker.ahk`（门面：首选源/重试/降级）→ `downloader.ahk` → `self_replacer.ahk` → `updater_manager.ahk`（协调器，事件化）；`github_token_service.ahk` 提供 Token 验证（`Validate()`，超时 5000ms，带校验状态缓存）。`ui/updater_ui.ahk` 仅通过事件与 Updater 交互。详见 [key_designs_base.md](key_designs_base.md#双源更新与自动降级) |
| `core/changelog/changelog_checker.ahk` | 更新公告检查。订阅 `ChangelogShowRequested`，构建 body（经 `ChangelogFormat.LocalizeBody` 裁剪语言）后发布 `ChangelogAvailable` |
| `core/diagnostics/log_exporter.ahk` | 诊断压缩包导出（`LogExporter` 类）。`CreateArchiveInteractive()` 弹出文件保存对话框，收集所有日志 + 脱敏后的设置文件 + 诊断信息，通过 PowerShell 打包为 ZIP。`OpenLogDirectory()` 打开日志目录 |
| `core/diagnostics/hook_health.ahk` | 键盘钩子存活探针与自愈（`HookHealth`）。详见 [key_designs_base.md](key_designs_base.md#键盘钩子健康探针) |

### ui 层（依赖 core/base）

| 模块 | 职责 |
|------|------|
| `ui/gui.ahk` | 设置窗口 GUI 全部逻辑（标签页切换、控件事件、托盘菜单）。详见 [key_designs_ui.md](key_designs_ui.md) |
| `ui/key_bind.ahk` | 按键绑定捕获（InputHook），处理用户在设置界面的按键录制。`NotifyBindingChanged` 发布 `HotkeyBindingsChanged` 触发冲突检测刷新 |
| `ui/custom_key_editor.ahk` | 自定义按键编辑窗口 + 坐标拾取。独立顶层 Gui（非 MainGui，KeyBinder 按键录制自动豁免）；单编辑窗口（再次打开直接切换目标行，未保存修改丢弃）；字段：命名 / 按键类型 / 按键功能（目前仅「单击」）/ 坐标（`(x, y)` 单值）；底部「删除」按钮确认后移除该行；打开期间光标在游戏客户区内（无需游戏前台）时 8ms 轮询 ToolTip 显示光标处 0-1 比例坐标，LButton 拾取（无 `~` 吞点击）**整体覆盖**坐标框并激活编辑窗口；保存时校验命名（50 字符、禁引号/反斜杠/控制字符）与「功能 + 坐标」，非法拒绝弹窗 |
| `ui/updater_ui.ahk` | 更新 UI（对话框）。仅通过事件与 Updater 交互，不直接调用其内部方法 |
| `ui/changelog_ui.ahk` | 更新公告展示，订阅 `ChangelogAvailable` |
| `ui/status_bar.ahk` | 主窗口底部模拟状态栏（`StatusBarHints`）：左下角主题色指示块 + 说明文本。鼠标悬停在已登记控件上时实时显示该控件功能说明；未悬停时每 `RotateIntervalMs`（默认 10 秒）随机轮播引导文案；首次打开窗口按系统时间显示时段问候语（进程内仅一次）。说明以「中文原文」为键存储，显示时才经 `I18n.T` 翻译（切语言后当前文本也会刷新）；键可带 `{1}` 占位符，`Register` 可传 `argsProvider` 回调实时求值 |
