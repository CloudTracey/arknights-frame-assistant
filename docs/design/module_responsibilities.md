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
8. **资源与游戏按键** — `StartupMark("资源提取")` 起，经 `StartupMark("游戏按键识别")`、`StartupMark("热键注册")`：`FileExtractor.EnsureExtracted()` 提取嵌入资源；`GameKeys.Init()`（读注册表游戏按键 + 启动 10s 轮询定时器，**必须在 `HotkeyOn` 之前**）→ `HotkeyService.HotkeyOn()` 激活热键。
9. **GUI 初始化** — `StartupMark("GUI 初始化")`：发布 `ChangelogShowRequested` → `UiShell.Start()`（读 `UiEngine` 规范化后分派引擎：先 `TrayController.Init()` 建引擎无关的托盘，再按引擎分派——`web` → `WebHost.Activate()`，预检失败或 `classic` → `GuiManager.Start()`，后者含 Alt+F4 退出热键注册）→ `UpdateUI.Init()`；随游戏自启校准失败的托盘提示在此处（GUI 就绪后）只发一次。
10. **启动收尾** — `StartupMark("启动收尾")` 至 `StartupMark("")`：发布 `AppStartCompleted`（触发自动更新检查与游戏自动启动）→ `GameMonitor.Start()` → 发布 Legacy 事件 `SetSwitchKey`、`GuiUpdateHotkeyControls`、`GuiUpdateImportantControls`、`GuiUpdateCustomControls` 完成 GUI 初始化 → `StartupMark("")` 输出总耗时。

## 模块职责

### 架构分层

四层单向依赖 `bootstrap → ui → core → base`；core 不得引用 ui，base 不得引用 core/ui。静态校验：`python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS`。

### base 层（无依赖）

| 模块 | 职责 |
|------|------|
| `base/config.ahk`（含 `base/constants.ahk`、`base/hotkey_schema.ahk`） | 全局配置管理（`Config` 类；`Constants` 与 `HotkeySchema` 为独立类）。配置持久化到 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`。Config 用懒加载模式（`_IsLoaded` 标志位）。自定义按键工作副本为 `Array<{Key, Name, Func, Arg, Type}>`，读取时 `Type`/`Func` 非法值分别回退 `global`/`click` 并记 Warn（宽容回退，不抛异常）；`GamePath` 迁移不搬运不存在的路径，避免坏路径扩散到 `GamePath<Id>`。写入/迁移/Token 的硬约束见 [key_designs_base.md](key_designs_base.md#config-读写分离与工作副本) |
| `base/custom_hotkey_store.ahk` | `CustomHotkeys.json` 唯一 owner（自定义按键独立存储，与 Settings.ini 隔离）。UTF-8 JSON v2、写定式（键序固定 `key/name/func/arg/type`，func=按键功能码、arg=参数文本）+ 字符集白名单 + 严格正则读取；解析失败备份 `.bak` 并回退空列表（v1 脚本格式不迁移，按损坏处理）；写入走临时文件 + `ReplaceFileW` 原子替换；清空写空数组不删文件 |
| `base/token_protector.ahk` | GitHub Token 的 Windows DPAPI 加密保护（`TokenProtector` 类）。`Protect()` 用 `CryptProtectData`（CurrentUser）加密并 Base64 编码，返回带 `dpapi:v1:` 前缀的存储值；`Unprotect()` 解密，无前缀值按旧版明文处理（供迁移）。内存缓冲用 `_SecureZero` 清零。由 `config.ahk` 的 `_ReadGitHubToken`/`MigrateGitHubToken`（启动时把旧版明文迁移为加密值）调用，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键 |
| `base/eventbus.ahk` | 发布/订阅事件总线，模块间解耦。事件清单见 [reference.md](reference.md#eventbus-事件清单) |
| `base/file_extractor.ahk` | 管理编译时 `FileInstall` 嵌入资源的运行时提取。`EnsureExtracted()` 将 `logo.ico`（含大小校验防旧版残留）、三张 `TakeOverButton_*.png`（代理作战按钮图像）和关卡检测模板（保留备用，PixelSearch 方案不依赖）统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` |
| `base/webview_runtime.ahk` | WebView2 Runtime 探测（`WebViewRuntime`，纯注册表查询、无依赖）：`CLIENT_GUID` + 四个注册表根（**与进程架构匹配的视图优先**，另一视图兜底；两组内 HKLM 优先于 HKCU）；`pv` 为空或 `0.0.0.0` 视为未安装。`IsAvailable()` 结果缓存（一个进程只探测一次），`GetVersion()` 不走缓存、供日志使用 |
| `base/game_target.ahk` | 「当前目标游戏窗口」的唯一 owner：`Hwnd`/`Pid`/`ExePath`/`ServerId`。未绑定客户端实例时宽松回退旧语义 `ahk_exe Arknights.exe`（决策 D2），保证升级零回归、降级不弹窗；**禁止其他模块再直接写 `"ahk_exe Arknights.exe"`**。只持有状态与查询 API，绑定/仲裁由 `core/game/game_client_registry.ahk` 驱动 |
| `base/server_profile.ahk` | 区服元数据与识别的唯一 owner（纯数据 + 纯函数，不引用 core/ui、无副作用）。从安装目录/可执行文件推断区服并给出对应 Unity PlayerPrefs 注册表根。多区服细节见 [key_designs_hotkey.md](key_designs_hotkey.md#多区服与热路径预算) |
| `base/single_instance.ahk` | 单例识别（命名互斥体 `ArknightsFrameAssistant-Singleton`）。与可执行文件名无关（编译版/未编译版行为一致），不依赖 WMI/COM，启动早期即可安全使用。有意让新进程接管前（托盘重启/提权重启）须先 `Release()`，避免新进程被误判为重复启动；**`Restart()`（`Release()` + `Reload()`）是该顺序的唯一 owner**，托盘「重启AFA」与界面类型变更后的立即重启都走它 |
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
| `base/tray.ahk` | 托盘提示工具（`ShowTrayTip`/`HideTrayTip`）。包装 AHK 内建 `TrayTip`，避免 core 层散落内建调用；发出前 `Logger.Info` 记录（标题+消息前缀截断），便于核对「没看到提示」是否真的没发出 |
| `base/window.ahk` | 窗口/屏幕工具，供 core 与 UI 复用。`SafeWinGetClientPos()` 窗口不存在时返回 false 而非抛 `TargetError`；安全像素搜索包装（`PixelSearch` 内部 GDI 调用失败会抛 `OSError`） |

### core 层（依赖 base）

| 模块 | 职责 |
|------|------|
| `core/hotkey/game_keys.ahk` | 游戏按键注册表识别 + 注入（`GameKeys` 类）。详见 [key_designs_hotkey.md](key_designs_hotkey.md#gamekeys-类) |
| `core/hotkey/hotkey_service.ahk`（`HotkeyService`） | 热键注册/注销/分组切换。详见 [key_designs_hotkey.md](key_designs_hotkey.md#热键注册与拦截) |
| `core/hotkey/hotkey_actions.ahk`（`HotkeyActions`） | 热键触发后的具体功能实现（`Action*` 函数）。触控注入初始化由 `App.Bootstrap()` 调用 `HotkeyActionsStart()` 完成；所有游戏按键通过 `GameKeys.SendDown`/`SendUp`/`Tap` 发送，不再硬编码。常规作战 14 个功能带关卡守卫（`GuardInLevel`，读 `LevelDetector.IsInLevel()` 判定），拦截时经 `KeyForward` 透传原键 |
| `core/hotkey/custom_script.ahk`（`CustomScriptEngine`） | 自定义按键功能引擎：「功能码 + 参数」模型（目前仅 `click` 单击，参数为 `(x, y)` 0-1 比例坐标、最多 4 位小数，执行时按当前窗口尺寸换算像素，以 `HotkeyActions._ClickButton` 同款 Send 点击并还原光标）。对外仅 `Validate`/`Reload`/`RunById`/`IsRegistered` 四方法；解析只在保存/Reload 慢路径，触发时 O(1) 缓存查表零 IO。功能注册表（Builtins）供扩展：新增功能 = 注册表加一行 + `Validate`/执行路径扩展。执行整体 `Thread "NoTimers"` + `finally` 无条件归位；combat 类型经 `GuardInLevel` 受关卡守卫。`Validate` 返回 `{success, steps: Array<{F, A}>, message}`（message 已本地化可直接弹窗）；**判坐标非法不能用 `x = ""`**——AHK 数值比较会把空串当 0，`(0, 0)` 会被误判，必须用 `IsNumber` |
| `core/hotkey/timing_service.ahk` | 时序服务：`CurrentDelay`/`ClickDelay` 唯一 owner，提供 getter 与 `Refresh()` |
| `core/settings/settings_service.ahk`（`SettingsService`） | 唯一配置写口。`Initialize()` 启动加载，`Save/Apply/Cancel/Reset()` 处理 GUI 命令，`UpdatePersistedValue(key, value)` 单键原子写入并发布 `SettingsChanged`。保存/应用/重置后通过 `SettingsSaved/Applied/Reset` 驱动 HotkeyService/TimingService/LevelDetector/GuiManager 刷新。保存/应用收口于 `_SaveOrApply`：进校验前取一次 `ReadImportantFromIni("UiEngine")`，落盘后两侧都经 `Constants.NormalizeUiEngine` 归一比对（ini 里可能是 `WEB` 或缺行，直接比会误报）——**变了才弹「是否立刻重启」并走 `SingleInstance.Restart()`，这一次不显示原成功提示**；`_ValidateAndPersist` 末尾另有 WebView2 预检，仅在「本次真的改成 web 且本机 Runtime 不可用」时弹一次确认（选否则中止整个保存，与其他校验同语义） |
| `core/settings/hotkey_conflict_validator.ahk` | 热键冲突验证器（`HotkeyConflictValidator` 类）。`FindAll(hotkeys, customSettings, customHotkeys)` 在同时启用的热键组内检测按键重复（自定义按键按「按键类型」并入两组：global 并入两组、combat/quick 并入常规组、strongHold 并入卫戍组；同对冲突跨组去重），返回 `{HasConflicts, Items, ByControl}`。SwitchHotkey 在全部两组中各检测一次。`GetDisplayName()` 查找 KeyNames/CustomNames/自定义行名称用于错误提示。供 GUI 实时提示和 SettingsService 保存阶段校验共享 |
| `core/monitor/level_detector.ahk` | 关卡检测投票状态机（`LevelDetector` 类）：3 个关卡内专属对象颜色投票，≥2 命中置位 `InLevel` 并发布 `InLevelChanged`；守卫关闭时停轮询并强制 `InLevel=true`。详见 [key_designs_hotkey.md](key_designs_hotkey.md#关卡检测与守卫判定) |
| `core/monitor/game_monitor.ahk`（`GameMonitor` 类） | 三合一游戏状态监控：(1) **自动退出**：所有受管客户端退出时退出 AFA（`AutoExit` 运行时读 INI，且从关到开时重置运行记录，避免历史记录立刻触发退出）；(2) **自动开局暂停**；(3) **自动开局二倍速**——两者共用一套进关检测状态机（17 点黑屏采样 → Loading 三扫描线排除红/蓝进关 → 等待倍速按钮），代理作战识别后取消暂停且不切倍速；另有 **(4) 按住开局暂停**：热键按住期间直接进入「等待倍速按钮」（跳过黑屏/Loading、不判超时），松手经 `HoldGuard.RegisterTail` 撤销、接管前常规路径已在等待则保留，命中时忽略 ② 的开关且代理也保持暂停。主轮询 400ms，进关检测期间 200ms。**「等待倍速按钮」是自排程定时器状态机（30ms/拍；常规路径 8s 硬超时，按住路径以松手为界），不得改回忙等**：忙等会占满主线程、令 `HotIf` 求值排队，最终被系统摘除键盘钩子（所有热键失效）。像素/图像搜索一律走 `Safe*` 包装，检测前临时切 per-monitor DPI 感知并在 `finally` 还原。辅助函数 `LoadingPosition()`/`BlackScreenPoints()`/`StopSearchLoading()`。详见 [key_designs_base.md](key_designs_base.md#游戏状态监控game_monitorahk) |
| `core/monitor/hook_monitor.ahk`（`HookMonitor` 类） | 键盘钩子存活检测：仅游戏前台时每 30ms 采样（无输入 idle>1s 整轮跳过），用 `GetAsyncKeyState` 捕捉热键键的按下沿，再以 `A_TimeIdleKeyboard` 判断该沿是否被钩子同步刷新过；AFA 自己注入的按下（`GameKeys.IsInjectedPressPending`）不计入。连续 2 次 miss 判定「钩子疑似被系统摘除」并 `InstallKeybdHook(true, true)` 重装（两次重装间 5s 冷却），日志为 `[WARN] [HookMonitor] 键盘钩子疑似被系统摘除：键=X`。判读见 [input_stall_diagnosis.md](input_stall_diagnosis.md#第-5-步最后才怀疑-afa-自身) |
| `core/game/game_client_registry.ahk` | 游戏客户端实例注册表：枚举运行中的 `Arknights.exe` 实例、维护 PID→区服缓存、仲裁前台客户端，并发布 `GameClientsChanged`/`ForegroundClientChanged` 事实事件。枚举/路径查询是慢路径，只允许在定时器或事件线程中调用；**热键路径不得进入本模块的 IO 方法**。带重入保护（刷新可由 GameMonitor 400ms 定时器 / ScheduleRefresh 一次性定时器 / Init 三入口交错调用） |
| `core/launch/game_launcher.ahk` | 随 AFA 自动启动游戏。`CheckGamePath()` 识别游戏路径，`ProcessGetPath` 失败时降级到 WMI 查询（`_GetProcessPathByWmi`）。**清理必须先于 `GameClientRegistry.Refresh()`/`FindInstalledPaths()`**：两者都会读配置里的路径，清理晚了会拿到脏数据，且已删除的目录会被重新写回。清理的合法性判定须与 `SettingsService` 保存校验**同源**（`FileExist` + `ServerProfile.FromExePath`）——用 `FromExePath` 而非比较文件名，重命名过但仍能识别的安装目录属合法位置，不能误清 |
| `core/launch/game_auto_start.ahk` | 随明日方舟启动自动启动小助手（`GameAutoStartManager` 类）。审核事务临时启用 `SeSecurityPrivilege`，通过 `AuditQuerySystemPolicy` 读取优先，仅在成功审核缺失时调用 `AuditSetSystemPolicy`，复查后恢复令牌权限原状态；错误 1450 按 250/750ms 有限重试。计划任务按动作、参数、工作目录、事件订阅、主体和设置做语义比较，一致时不重写，缺失或漂移时才修复。手动启动执行校准；`--game-autostart` 触发启动在配置开启时跳过校准，配置关闭时尽力删除遗留任务后退出。启动校准失败保留配置和任务，仅在 GUI 就绪后显示一次托盘通知；设置页显式保存仍严格失败且不持久化。`Disable()` 只删除当前用户任务并保留系统审核。任务按 SID 独立命名（`ArknightsFrameAssistant-AutoStartWithGame-{SID}`） |
| `core/launch/app_context.ahk` | 应用启动上下文：`StartedByGameAutoStart` 唯一 owner，Bootstrap 写入，GameAutoStartManager/LogExporter 读取 |
| `core/updater/` | 自动更新全流程：`release_repository.ahk`（GitHub/国内源检查与 changelog 缓存）→ `version_checker.ahk`（门面：首选源/重试/降级）→ `downloader.ahk` → `self_replacer.ahk` → `updater_manager.ahk`（协调器，事件化）；`github_token_service.ahk` 提供 Token 验证（`Validate()`，超时 5000ms，带校验状态缓存）。`ui/updater_ui.ahk` 仅通过事件与 Updater 交互。详见 [key_designs_base.md](key_designs_base.md#双源更新与自动降级) |
| `core/changelog/changelog_checker.ahk` | 更新公告检查。订阅 `ChangelogShowRequested`，构建 body（经 `ChangelogFormat.LocalizeBody` 裁剪语言）后发布 `ChangelogAvailable` |
| `core/diagnostics/log_exporter.ahk` | 诊断压缩包导出（`LogExporter` 类）。`CreateArchiveInteractive()` 弹出文件保存对话框，收集所有日志 + 脱敏后的设置文件 + 诊断信息，通过 PowerShell 打包为 ZIP。`OpenLogDirectory()` 打开日志目录 |

### ui 层（依赖 core/base）

| 模块 | 职责 |
|------|------|
| `ui/gui.ahk` | 设置窗口 GUI 全部逻辑（标签页切换、控件事件）。详见 [key_designs_ui.md](key_designs_ui.md) |
| `ui/ui_shell.ahk` | 界面类型分派（`UiShell`）。`Start()` 读 `Constants.NormalizeUiEngine(Config.GetImportant("UiEngine"))` 决定引擎，先 `TrayController.Init()` 再分派；并订阅 `SettingsShowRequested` 调 `Show()`。`Engine` 是运行期实际引擎的唯一副本。新增引擎时需同步 **`Constants.UiEngines` + `Config._DefaultImportant` + `Constants.ImportantNames`**（第三项漏登记会被 `SaveAllToIni` 从 ini 抹掉）；**引擎启动失败必须回退经典界面且异常不得冒泡**——`Bootstrap()` 在分派之后还要初始化 `UpdateUI`/`GameMonitor`/`HookMonitor` |
| `ui/tray_controller.ahk` | 托盘菜单与图标提示的唯一 owner（`TrayController`）：`Init`/`OpenSettings`/`SetTooltip`/`SetHotkeyItemLabel`/`UpdateServer`。**与界面类型无关**：`UiShell.Start()` 与 `GuiManager.Init()` 各调一次，后者保证切语言重建窗口后托盘菜单文案跟着刷新；菜单固定四项（打开设置界面 / 启用-禁用热键 / 重启AFA / 退出），**语言切换不重建托盘菜单**也不需要，故不再订阅 `LocaleChanged`。「重启AFA」只调 `SingleInstance.Restart()`；界面类型的选择在「其他设置 → 显示」由 `GuiManager` 承担 |
| `ui/web/web_engine.ahk` | web 引擎聚合 include：`main.ahk` 只 include 本文件一行（上游 `#Include` 区是唯一热点），内部按序引入 vendored `Promise`/`WebView2`、`base/webview_runtime.ahk` 与 `web_host.ahk`。`src/lib/vendor/` 为 ahk2_lib 最小集（`ComVar`/`Promise`/`WebView2` + 两个 `WebView2Loader.dll`），来源与许可见其 `VENDOR_INFO.txt` |
| `ui/web/web_host.ahk` | web 引擎宿主（`WebHost`）：预检（Runtime → `app/index.html` 存在 → **加载器 DLL 存在**）→ **窗口可见 `Show()` 之后**才 `CreateControllerAsync(hwnd, , 应用私有用户数据目录, , 加载器绝对路径)` 并 `await2(15 s)`（**加载器必须显式传绝对路径**：库默认的相对名会命中进程工作目录，构成 DLL 劫持；预检在缺失时干净回退，不必等超时）→ 设置 + `SetVirtualHostNameToFolderMapping(host, dir, **1**)`（accessKind 必须为 `1`=ALLOW，`0`=DENY 会让页面全空白）→ 绑定 `WebMessageReceived`（回调**恰好两个参数**）→ `Navigate("https://afa.app/index.html")` → 武装 8 s 握手超时（未收到 `ready`：`DebugEnabled=1` 时**先弹确认「是否回退到经典界面」**，选「否」才只 Warn + 托盘气泡并保留窗口供查 DevTools；`DebugEnabled=0` 直接 `_Fallback()` 回落经典界面——托盘已无引擎切换项，超时不自愈用户就没有回到经典界面的入口）→ `Ready`；`Size` 事件与每次 `Show()` 都 `Fill()`。关闭按钮只隐藏窗口并复用控制器，销毁时 `Controller.Close()`。运行期失败经 `_Fallback()` 回退经典界面；窗口注册 **Alt+F4 始终退出**（与经典界面一致，销毁时注销）；`_Start()` 带**创建中门闩**（`await2` 期间允许新线程插入，不得二次进入创建流程覆盖 `Gui`/`Controller`）。**只订阅事件、不发布事件**。 |
| `ui/key_bind.ahk` | 按键绑定捕获（InputHook），处理用户在设置界面的按键录制。`NotifyBindingChanged` 发布 `HotkeyBindingsChanged` 触发冲突检测刷新 |
| `ui/custom_key_editor.ahk` | 自定义按键编辑窗口 + 坐标拾取。独立顶层 Gui（非 MainGui，KeyBinder 按键录制自动豁免）；单编辑窗口（再次打开直接切换目标行，未保存修改丢弃）；字段：命名 / 按键类型 / 按键功能（目前仅「单击」）/ 坐标（`(x, y)` 单值）；底部「删除」按钮确认后移除该行；打开期间光标在游戏客户区内（无需游戏前台）时 8ms 轮询 ToolTip 显示光标处 0-1 比例坐标，LButton 拾取（无 `~` 吞点击）**整体覆盖**坐标框并激活编辑窗口；保存时校验命名（50 字符、禁引号/反斜杠/控制字符）与「功能 + 坐标」，非法拒绝弹窗 |
| `ui/updater_ui.ahk` | 更新 UI（对话框）。仅通过事件与 Updater 交互，不直接调用其内部方法 |
| `ui/changelog_ui.ahk` | 更新公告展示，订阅 `ChangelogAvailable` |
| `ui/status_bar.ahk` | 主窗口底部模拟状态栏（`StatusBarHints`）：左下角主题色指示块 + 说明文本。鼠标悬停在已登记控件上时实时显示该控件功能说明；未悬停时每 `RotateIntervalMs`（默认 10 秒）随机轮播引导文案；首次打开窗口按系统时间显示时段问候语（进程内仅一次）。说明以「中文原文」为键存储，显示时才经 `I18n.T` 翻译（切语言后当前文本也会刷新）；键可带 `{1}` 占位符，`Register` 可传 `argsProvider` 回调实时求值 |
