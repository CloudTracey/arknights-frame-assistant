# 关键设计：基础设施（配置、日志、诊断、更新）

> AGENTS.md 参考资料分册。AGENTS.md 只保留必须遵守的铁律，本文件保留完整机制、历史与理由。

## Constants 类

常量定义。`Delay30`~`Delay240` 是各帧率对应的延迟毫秒值（取 `ceil(1000/fps)`，例外：`Delay144=8` 多 1ms 余量），`TimingService.GetCurrentDelay()` 依此计算。`FrameOptions` 定义下拉框选项数组，`FrameTextToOldIndex`/`FrameOldIndexToText` 用于 Frame155 双写转换。

`ThemeModes` 与 `NormalizeThemeMode()` 是界面主题模式的**唯一合法值集合与规范化规则**（Config/Theme/GuiManager 共用，勿在别处重复定义或再写一份 switch）。

`KeyNames` 是 `Map(热键id, i18n键名)`（由 `HotkeySchema` 生成），显示名经 `I18n.T(nameKey)` 获取——新增热键功能时**必须**在 `HotkeySchema.Items` 中同步添加带 `nameKey` 的条目。

`CustomNames` 对应自定义设置的显示名，新增自定义配置项时也需同步添加，否则设置无法保存；同时需在 `Config._DefaultCustom` 加默认值——老用户已有 INI 缺新键时由 `LoadFromIni` 的 `_BackfillMissingCustomDefaults()`（v1.9.0+）自动补齐，无需手工迁移。

## Logger 日志系统

双轨滚动存储，普通日志（`afa-*.log`）保留 15 MiB，关键日志 WARN/ERROR（`critical-*.log`）单独保留 5 MiB，总容量 20 MiB，存储于 `%AppData%\ArknightsFrameAssistant\PC\logs\`。按会话隔离（文件名含时间戳+PID+tick，即 `afa-{timestamp}-{pid}-{tick}.log`），支持 7 天过期清理和容量驱动的分段轮换。`RegisterSecret(value)` 注册敏感值，`_BuildLine` 自动调用 `Redact` 脱敏。启动时检测上一会话是否异常退出（无 Shutdown 标记的上一会话日志文件受保护不被清理），并挂全局未处理异常回调。所有模块通过 `Logger.Info`/`Warn`/`Error`/`Debug`/`Exception` 写日志。

**DEBUG 恒持久化**（v2.0.3+）：`Logger.Debug` 无条件写盘（不受任何开关控制），用户不开调试模式也能拿到完整运行轨迹；`DebugEnabled`（Important）仅控制实时调试控制台显示。

透传日志按键按下→松开配对合并为一条；高频源（HookHealth 心跳 60s/条、LevelDetector 每 20 次轮询、滚轮 100ms）均已有节流。所有日志通过 `OutputDebug` 同步输出到 DebugView。容量清理依赖缓存指标（`CachedOrdinaryFiles`/`CachedOrdinaryBytes` 等），每 64 次写入或有容量压力时触发。

## 实时调试控制台（logger.ahk）

`SetConsoleEnabled` 经 `AllocConsole` 创建「AFA 调试日志」窗口。

输出**必须用 `WriteConsoleW` DllCall 直接写入**——`FileOpen("CONOUT$")`+`WriteLine` 因 File 对象内部缓冲、控制台不关闭不刷新而空屏。`SetConsoleTextAttribute` 按级别着色（ERROR红/WARN黄/DEBUG灰/INFO白）；打开时显示亮蓝横幅并回放 `RecentLines` 最近日志。

安全措施：X 按钮置灰、`SetConsoleCtrlHandler(NULL, TRUE)` 忽略 Ctrl+C/Break、`SetConsoleMode` 清除 `ENABLE_QUICK_EDIT_MODE(0x0040)` 并置 `ENABLE_EXTENDED_FLAGS(0x0080)`（否则点击控制台进入选择态、阻塞进程控制台 I/O 卡死 AFA）。

`AllocConsole` 失败（进程已有控制台，如从终端启动）→ 静默降级并**复位 `ConsoleEnabled=false`**（避免 `CloseConsole` 误 `FreeConsole` 脱离调用方终端）。`ConsoleTipShown` 内存标志控"当次会话仅首次"提示。

`DebugEnabled`（Important）经 `SettingsService.Initialize()` 接线**仅控制控制台**（`SetConsoleEnabled`，单源，勿重读 INI 造成双源）；`version_checker` 的 `IsDebugLogging()`/`DebugMode` 门控已随 DEBUG 恒持久化删除，`_Log` 直接写 `Logger.Debug`。

## Config 读写分离与工作副本

`GetHotkey()`/`GetImportant()`/`GetCustom()` 返回内存工作副本（`_HotkeySettings`/`_ImportantSettings`/`_CustomSettings`），供 GUI 显示和冲突检测使用。`SetHotkey()`/`SetImportant()`/`SetCustom()` 仅写内存。

`LoadFromIni()` 一次性从 INI 重载全部三组设置，用于显式丢弃内存中的未保存修改（取消设置时）。

热键注册和运行时逻辑不应触碰工作副本，应使用 `ReadHotkeyFromIni()`/`ReadImportantFromIni()`/`ReadCustomFromIni()` 直接从 INI 读取——这三个方法不会修改内存 Map。

`AllHotkeys`/`AllImportant`/`AllCustom` 三个属性直接返回内存 Map 的引用，供遍历使用——注意 `AllHotkeys` 的值是"真实键值"（`RealNewkeyFormat`），而 GUI 显示的是 `VirtualNewkeyFormat` 后的可读值。

`TrackChange()` 在检测控件变更时同步将新值写入 Config 内存（确保切换标签页后编辑不丢失）。`SetImportant("Frame", value)` 内部自动同步 `Frame155`，调用方无需手动双写。

`UpdateSource`（`"1"` = 国内源默认，`"2"` = GitHub）为 v1.5.6+ 新增的 Important 配置项。三组设置分别通过 `GetHotkey`/`GetImportant`/`GetCustom` 懒加载，各自对应 `_DefaultHotkeys`/`_DefaultImportant`/`_DefaultCustom` 默认值 Map。

`Settings.ini` 的 `[Hotkeys]` 与 `[Custom] SwitchHotkey` 在 Config 边界只将单个 ASCII 大写字母主键规范化为小写并于启动加载时原子写回（如 `A→a`、`+C→+c`），命名键与 `CustomHotkeys.json` 不改；`VirtualNewkeyFormat` 只负责可读显示，必须保留修饰键间的 `+` 分隔符。

## State 类已删除

原运行时字段已收归唯一 owner：`CurrentDelay`/`ClickDelay` → `TimingService`；`InLevel` → `LevelDetector.IsInLevel()`；`GameHasStarted`/`ReadyForPause`/`BlackScreenDetected` → `GameMonitor` 私有；`HoverOperate` → `HotkeyService`；`StartedByGameAutoStart` → `AppContext`；`GuiWindowName` 删除。

## EventBus 事件命名约定（新代码必须遵守）

命令用 `XxxRequested`，事实用 `XxxChanged`/`XxxStarted`/`XxxCompleted`/`XxxAvailable`；每个事件只有一个发布者，payload 字段以代码内事件声明与 `tools/event_contract_check.py` 校验为准。旧前缀名（`GuiUpdate*`、`Settings*`、`Update*`、`Set*`/`Unset*`）为兼容遗留，新代码不应继续使用。事件清单见 [reference.md](reference.md#eventbus-事件清单)。

## 自动开局暂停流程

三阶段状态机 — 全屏黑屏检测 → Loading 扫描线识别（排除红/蓝进关）→ 暂停按钮颜色确认后 ESC 暂停，再用代理作战按钮图像确认避免重复暂停；8 秒超时自动取消，定时器频率随状态动态调整（400ms → 200ms → 超时恢复 400ms）。细节见 `game_monitor.ahk`。

## 双源更新与自动降级

更新系统支持 GitHub API 和国内源（腾讯云 COS+CDN）两源，`UpdateSource` 选首选源，失败自动降级备选源（`token_invalid`/`rate_limited` 静默降级）。国内源用 CDN 静态 `version.json`（`version`/`downloadUrl`/`releases`），`releases` 格式与 GitHub API 一致，复用 changelog 缓存。发布时 Action（`.github/workflows/release-sync.yml`）自动同步 exe 和 version.json 到 COS。

**v1.8.1+ 双源 SHA-256 下载校验**：`expectedHash` 从版本检查结果一路透传到 `downloader`，下载完成后用 `_GetFileSha256`（分块流式 `CryptHashData`）校验，不匹配则删除文件并弹窗中止（防篡改）。GitHub 源从 asset 的 `digest` 字段（`sha256:<hex>`，正则限定 `"name":"AFA.exe"` asset）提取；国内源从 `version.json` 的 `sha256` 字段提取。`version.json` 的 `sha256` 由发布 Action 计算写入。

## 更新渠道

`UpdateChannel` 设置为 1（正式版）或 2（测试版），版本检查器据此选择检查 stable releases 还是包含 pre-release。GUI 通过下拉框切换，默认正式版。

## 配置文件

INI 格式，三个 Section：`[Hotkeys]`、`[Main]`、`[Custom]`。`GitHubToken` 使用 Windows DPAPI（`token_protector.ahk` 的 `TokenProtector` 类）按当前 Windows 用户加密，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键（带 `dpapi:v1:` 前缀），读取经 `_ReadGitHubToken()` 解密。旧版明文 `GitHubToken` 键在启动时自动迁移为加密格式并删除明文（迁移失败会保留原配置并提示恢复写入权限）。

## 数据文件

`%AppData%\ArknightsFrameAssistant\PC\changelog.json` 存储从 GitHub Releases API 拉取的所有版本发布内容，每次版本检查时更新。由 `ReleaseRepository._SaveChangelogCache()` 写入，`ChangelogChecker` 读取。

## 键盘钩子健康探针

（`core/diagnostics/hook_health.ahk`，背景 #340）

AFA 全部热键注册在 `HotIf` 回调下，每次按键都要主线程求值，求值期间钩子回调阻塞。主线程若超过系统低级钩子超时（`LowLevelHooksTimeout`，未配置时默认 300ms）无法响应，系统累计 11 次后即静默摘除键盘钩子，表现为「所有快捷键突然失效，必须重启或重新注册热键才恢复」，且 AHK 自身无从感知。

观测手法：用**不依赖钩子**的 `GetAsyncKeyState` 采样已注册热键键位的物理按下沿，与**依赖钩子**的热键回调计数（`NoteFire`）对照。观测到物理按下却在宽限期内没有任何热键回调 ⇒ 记一次未命中；连续多次 ⇒ 判定钩子失效，落一份完整状态快照并按需自愈。

判读要点：快照里的 idle/idleKbd/idlePhys 三值恒等，说明 `A_TimeIdleKeyboard` 与 `A_TimeIdlePhysical` 已退化为 `A_TimeIdle`（文档：钩子未安装时二者等价于 `A_TimeIdle`），即钩子确已不再被调用；三值有差异则说明钩子仍在正常区分键盘与鼠标输入。**注意单看 idleKbd 数值大小无法判定**——纯键盘输入时两种情况都接近 0，必须看三值是否恒等。

快照另外带 `ctxEval`（单次 HotIf 求值耗时，用 QueryPerformanceCounter 采样、频率缓存见 `base/timing.ahk` 的 `Qpc()`）与累计自愈次数 `recover`。**这是快照里唯一的耗时项**：曾有的 `inToAction`（首次求值→动作线程开始）因在生产上无法自证正确、连报假延迟而整项移除——测不准的指标不留。**判读顺序与「Windows 卡住 / 游戏正常」的完整排查路径见 [input_stall_diagnosis.md](input_stall_diagnosis.md)**，不要只凭快照里单个数字下结论。

自愈用 `InstallKeybdHook(true, true)`，文档明确该 Force 重装会"抢占其它进程先前安装钩子的优先级"——因此它对"钩子被摘除"有效，对"输入被前置钩子吞掉"却是反向操作，故阈值与冷却都取保守值（见 `input_stall_diagnosis.md` 第 6 节）。

## cmd `chcp 65001` 批处理陷阱

（`self_replacer.ahk`）

cmd 按当前控制台代码页解析批处理文件，中文 Windows 默认 GBK。在**批处理内部**执行 `chcp 65001` 会触发 cmd 重读文件并**错位解析中文行**，报 "is not recognized" 乱码错误（如 `'�我'`）。**触发需同时满足**：行以多字节中文字符结尾（cmd 会把行尾换行符吞进上一个多字节字符）。

已实测规避方式：每行以 ASCII 结尾（如 `...`，与 `正在等待程序关闭...` 风格一致）、中文块前插 ASCII 分隔行、或把中文内容合并成单行。

彻底修复需权衡：在 cmd 命令行前置 chcp（`cmd /c "chcp 65001 >nul & call 批处理"`）会引入 `cmd /c "..." & ...` 命令行签名、增加杀软误报风险（本分支反误报优化所忌）；批处理改 GBK 编码则 update 日志变 GBK（LogExporter 按 UTF-8 读取会乱码）。本分支决定保留 `Run batchFile` + 内部 chcp，用 ASCII 行尾规避。

## GitHub Action 发布同步

`.github/workflows/release-sync.yml` 监听 Release 发布事件，将 `AFA.exe` 和 `version.json` 上传到 COS 并刷新 CDN。`.github/scripts/build_version_json.py` 构建含全量 releases 历史的 `version.json`，处理首次初始化（COS 上无文件时自动创建），支持 stable/beta 双通道独立 version.json。Action 需要 5 个 GitHub Secrets（`COS_SECRET_ID`/`COS_SECRET_KEY`/`COS_BUCKET`/`COS_REGION`/`CDN_DOMAIN`）。`release-sync.yml` 不在 `.gitignore` 中，会被 git 跟踪。发布时对 `AFA.exe` 计算 sha256 写入 `version.json`（`--sha256` 参数）；**GitHub Actions step outputs 大小写敏感**——输出键名须用小写 `sha256`，否则引用为空。
