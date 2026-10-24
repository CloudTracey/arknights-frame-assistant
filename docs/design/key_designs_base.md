# 关键设计：基础设施（配置、日志、诊断、更新）

> AGENTS.md 参考资料分册。AGENTS.md 只保留必须遵守的铁律，本文件保留完整机制、历史与理由。

## Constants 类

常量定义。`Delay30`~`Delay240` 是各帧率对应的延迟毫秒值（取 `ceil(1000/fps)`，例外：`Delay144=8` 多 1ms 余量），`TimingService.GetCurrentDelay()` 依此计算。`FrameOptions` 定义下拉框选项数组，`FrameTextToOldIndex`/`FrameOldIndexToText` 用于 Frame155 双写转换。

`ThemeModes` 与 `NormalizeThemeMode()` 是界面主题模式的**唯一合法值集合与规范化规则**（Config/Theme/GuiManager 共用，勿在别处重复定义或再写一份 switch）。

`KeyNames` 是 `Map(热键id, i18n键名)`（由 `HotkeySchema` 生成），显示名经 `I18n.T(nameKey)` 获取——新增热键功能时**必须**在 `HotkeySchema.Items` 中同步添加带 `nameKey` 的条目。

`CustomNames` 对应自定义设置的显示名，新增自定义配置项时也需同步添加，否则设置无法保存；同时需在 `Config._DefaultCustom` 加默认值——老用户已有 INI 缺新键时由 `LoadFromIni` 的 `_BackfillMissingCustomDefaults()`（v1.9.0+）自动补齐，无需手工迁移。

## Logger 日志系统

双轨滚动存储，普通日志（`afa-*.log`）保留 15 MiB，关键日志 WARN/ERROR（`critical-*.log`）单独保留 5 MiB，总容量 20 MiB，存储于 `%AppData%\ArknightsFrameAssistant\PC\logs\`。按会话隔离（文件名含时间戳+PID+tick，即 `afa-{timestamp}-{pid}-{tick}.log`），支持 7 天过期清理和容量驱动的分段轮换。`RegisterSecret(value)` 注册敏感值，`_BuildLine` 自动调用 `Redact` 脱敏。启动时检测上一会话是否异常退出（无 Shutdown 标记的上一会话日志文件受保护不被清理），并挂全局未处理异常回调。所有模块通过 `Logger.Info`/`Warn`/`Error`/`Debug`/`Exception` 写日志。

**退出回调有顺序依赖**：`Theme.Stop` 以 `OnExit(callback, -1)` 注册（优先级更低，先执行），`main.ahk` 的 `HandleAfaExit`/`Logger.HandleExit` 负责写 `[Shutdown]` 标记——若把写标记的回调排到 `Theme.Stop` 之前，标记会在主题清理前落盘，异常退出检测（下一会话据此判定上次是否正常退出）就失去意义。

**DEBUG 不落盘**（v2.1.1+）：`Logger.Debug` 只走 `OutputDebug` 与实时调试控制台，不写日志文件、也不进 `RecentLines`（因此不会出现在 WARN/ERROR 的 critical 上下文里）；`DebugEnabled`（Important）仅控制实时调试控制台显示。需要留在日志文件里的信息（动作执行、透传配对、识别判定、更新报文等）一律用 `Info`/`Warn`/`Error` 记录，`Debug` 只留给"盯着控制台时才关心"的高频明细。

透传日志按键按下→松开配对合并为一条；高频源（LevelDetector 每 20 次轮询、滚轮 100ms）均已有节流。所有日志通过 `OutputDebug` 同步输出到 DebugView。容量清理依赖缓存指标（`CachedOrdinaryFiles`/`CachedOrdinaryBytes` 等），每 64 次写入或有容量压力时触发。

## 实时调试控制台（logger.ahk）

`SetConsoleEnabled` 经 `AllocConsole` 创建「AFA 调试日志」窗口。

输出**必须用 `WriteConsoleW` DllCall 直接写入**——`FileOpen("CONOUT$")`+`WriteLine` 因 File 对象内部缓冲、控制台不关闭不刷新而空屏。`SetConsoleTextAttribute` 按级别着色（ERROR红/WARN黄/DEBUG灰/INFO白）；打开时显示亮蓝横幅并回放 `RecentLines` 最近日志。

安全措施：X 按钮置灰、`SetConsoleCtrlHandler(NULL, TRUE)` 忽略 Ctrl+C/Break、`SetConsoleMode` 清除 `ENABLE_QUICK_EDIT_MODE(0x0040)` 并置 `ENABLE_EXTENDED_FLAGS(0x0080)`（否则点击控制台进入选择态、阻塞进程控制台 I/O 卡死 AFA）。

`AllocConsole` 失败（进程已有控制台，如从终端启动）→ 静默降级并**复位 `ConsoleEnabled=false`**（避免 `CloseConsole` 误 `FreeConsole` 脱离调用方终端）。`ConsoleTipShown` 内存标志控"当次会话仅首次"提示。

`DebugEnabled`（Important）经 `SettingsService.Initialize()` 接线**仅控制控制台**（`SetConsoleEnabled`，单源，勿重读 INI 造成双源）；`version_checker` 无 `IsDebugLogging()`/`DebugMode` 门控，`_Log` 直接写 `Logger.Info`——报文级日志要留在文件里就不能用 `Debug`。

## Config 读写分离与工作副本

`GetHotkey()`/`GetImportant()`/`GetCustom()` 返回内存工作副本（`_HotkeySettings`/`_ImportantSettings`/`_CustomSettings`），供 GUI 显示和冲突检测使用。`SetHotkey()`/`SetImportant()`/`SetCustom()` 仅写内存。

`LoadFromIni()` 一次性从 INI 重载全部三组设置，用于显式丢弃内存中的未保存修改（取消设置时）。

热键注册和运行时逻辑不应触碰工作副本，应使用 `ReadHotkeyFromIni()`/`ReadImportantFromIni()`/`ReadCustomFromIni()` 直接从 INI 读取——这三个方法不会修改内存 Map。

`AllHotkeys`/`AllImportant`/`AllCustom` 三个属性直接返回内存 Map 的引用，供遍历使用——注意 `AllHotkeys` 的值是"真实键值"（`RealNewkeyFormat`），而 GUI 显示的是 `VirtualNewkeyFormat` 后的可读值。

**写入一律原子替换**：`SaveToIni`/`SaveAllToIni`/`SaveHotkeysToIni`/`_WriteIniEntriesAtomic` 都先在**同目录临时副本**（`FileCopy` 会继承只读属性，故先 `FileSetAttrib("-R")`）中完成全部写入，再用 `_CommitIniTemp`（`ReplaceFileW` + `REPLACEFILE_WRITE_THROUGH`，目标不存在时退化为 `FileMove`）替换正式文件；失败路径的 `finally` 负责删除临时文件并复位 `IniFile`。原配置在提交前始终不变。

异常退出可能留下 `Settings.ini.bak-<tick>-<rand>`、`Settings.ini.tmp-<tick>-<rand>` 与 `CustomHotkeys.json.tmp-<tick>-<rand>`；`SettingsService.Initialize()` 启动时调用 `Config.CleanupStaleFiles()` / `CustomHotkeyStore.CleanupStaleFiles()` 按该命名模式清理（`CustomHotkeys.json.bak` 是损坏文件备份，不清理）。

**保存失败可回滚**：`SaveAllToIni()` 通过 `ReplaceFileW` 的备份参数原子保留提交前的 Settings.ini，`SettingsService` 在 `CustomHotkeys.json` 也写成功后才删除该备份（`Config.DiscardIniBackup`）；后者写入失败时用备份原子替换回去（`Config.RollbackIni`），因此两个文件要么一起更新、要么都保持原状。回滚本身失败时保留备份并记录路径，提示用户配置可能已被部分修改。

计划任务不在文件事务内：保存前由 `SettingsService._SnapshotAutoStartState()` 读取已持久化的开关与路径，自启应用后任何失败都用 `_RestoreAutoStart()` 把任务恢复到该状态；恢复任务走 `EnsureTask` 而不走 `Apply`，因为待恢复的路径可能刚被用户确认清除或游戏已卸载，不能再做存在性校验。任务恢复失败时提示用户重启 AFA，启动校准会再次对齐。

所有已配置的游戏路径（`GamePath` 与 `GamePath<Id>`）在写入 INI 前由 `SettingsService._NormalizeDraftGamePaths()` 规范化为绝对长路径（与「随游戏自动启动」是否开启无关）；任务订阅仍会内部规范化并去重。保存成功后 GUI 经 `_RefreshGamePathControls()` 从内存回读，不再有独立的路径规范化事件。保存失败时磁盘保持旧值，取消/重开时 GUI 回读旧值。

`Read*FromIni` 的取值也过一遍 `_NormalizeHotkeyValue`（热键串键）；`Set*` 同样规范化后再写内存——因此内存工作副本与 INI 的取值形态一致，GUI 不会显示大写主键。工作副本入口统一规范化 `ThemeMode`（`LoadFromIni`/`SetImportant` 内），单键写盘由 `_PersistSingleValue` 再规范化一次。

首次运行由 `_EnsureConfigFileExists()` 全量写入三组默认值（跳过 `GitHubToken`）；已存在的文件由 `_BackfillMissingCustomDefaults()` 只补缺失的 `[Custom]` 键——用哨兵值区分"键不存在"与"键存在但值为空"（`; __AFA_MISSING_KEY__`），避免把用户显式清空的配置重新写成默认值。

**帧率双写**：`Frame155`（文本值）与 `Frame`（旧版索引 1~7）由 `SetImportant`/`SaveToIni`/`_PersistSingleValue` 内部同步，调用方不要手动双写；读取顺序 Frame155 → 旧索引转换 → 默认值（`_ResolveFrame`）。

`TrackChange()` 在检测控件变更时同步将新值写入 Config 内存（确保切换标签页后编辑不丢失）。`SetImportant("Frame", value)` 内部自动同步 `Frame155`，调用方无需手动双写。

`UpdateSource`（`"1"` = 国内源默认，`"2"` = GitHub）为 v1.5.6+ 新增的 Important 配置项。三组设置分别通过 `GetHotkey`/`GetImportant`/`GetCustom` 懒加载，各自对应 `_DefaultHotkeys`/`_DefaultImportant`/`_DefaultCustom` 默认值 Map。

`Settings.ini` 的键大小写规范化**只作用于热键串取值**（`[Hotkeys]` 全部键 + `[Custom] SwitchHotkey`）：单个 ASCII 大写字母主键规范化为小写并于启动加载时原子写回（如 `A→a`、`+C→+c`），命名键（`Space`/`CapsLock`/`F1`）保持既有拼写，`CustomHotkeys.json` 不改。`VirtualNewkeyFormat` 只负责可读显示，必须保留修饰键间的 `+` 分隔符。

## 单例互斥体（single_instance.ahk）

命名互斥体 `ArknightsFrameAssistant-Singleton`，`Acquire()` 成功即本进程为唯一实例。判定规则：`CreateMutexW` 返回 NULL（如跨完整性级别被拒）或 `GetLastError = 183`（`ERROR_ALREADY_EXISTS`）都视为"已有实例"——`GetLastError` **必须紧跟 `CreateMutexW` 读取**（中间插入任何 API 调用都会覆盖它）。`DllCall` 拿到的句柄不会被 AHK 自动回收，`Release()` 里显式 `CloseHandle` 并清零（幂等）。

**有意把控制权交给新进程前必须先 `Release()`**（托盘「重启AFA」的 `Reload()`、非管理员 `*RunAs` 提权重启两条路径）：新进程会在旧进程尚未退出时启动并重新 `Acquire()`，不释放就会被误判为重复启动而弹窗退出。

日志时机：`Release()` 由 `Bootstrap` 在最早期调用，早于 `Logger.Init()`（此时无文件可写，冲突提示只能走 `OutputDebug`），因此只在 `Release` 路径记 `Logger.Info`；提权路径若 Logger 仍未初始化会安全降级到 DebugView。

## State 类已删除
原运行时字段已收归唯一 owner：`CurrentDelay`/`ClickDelay` → `TimingService`；`InLevel` → `LevelDetector.IsInLevel()`；`GameHasStarted`/`ReadyForPause`/`BlackScreenDetected` → `GameMonitor` 私有；`HoverOperate` → `HotkeyService`；`StartedByGameAutoStart` → `AppContext`；`GuiWindowName` 删除。

## EventBus 事件命名约定（新代码必须遵守）

命令用 `XxxRequested`，事实用 `XxxChanged`/`XxxStarted`/`XxxCompleted`/`XxxAvailable`；每个事件只有一个发布者，payload 字段以代码内事件声明与 `tools/event_contract_check.py` 校验为准。旧前缀名（`GuiUpdate*`、`Settings*`、`Update*`、`Set*`/`Unset*`）为兼容遗留，新代码不应继续使用。事件清单见 [reference.md](reference.md#eventbus-事件清单)。

## 游戏状态监控（game_monitor.ahk）

三合一监控，主轮询 `CheckGameStatus()` 每 400ms（进关检测期间 200ms）跑一次：

**① 自动退出**：`AutoExit` 为 `1` 时，所有受管客户端都退出（`GameClientRegistry.HasClients()`；枚举失败再兜底 `GameTarget.ProcessExists()`，避免误退出）且 `_GameHasStarted` 为真才 `ExitApp`。`AutoExit` **运行时读 INI 实际保存值**而不是内存工作副本——GUI 里改了没应用不能影响它；且从关到开的那一刻要重置 `_GameHasStarted`，否则应用设置后会立刻因"游戏曾运行过"的历史记录触发自动退出。

**② 自动开局暂停 / ③ 自动开局二倍速**：两者共用同一套进关检测状态机（黑屏 → Loading → 倍速按钮），任一开启即进入检测。**④ 按住开局暂停**（热键 `AutoBeginPauseHold`）复用同一套状态机的**后半段**：按下即直接进入「等待倍速按钮」（跳过黑屏/Loading），松手撤销。

- **黑屏**：17 点全屏采样（四角/四边/内部/中心各 5%、25%、50%、75%、95% 比例），纯黑 `0x000000` 容差 10，**允许 1 个点不命中**（游戏鼠标会遮住一个点），连续 4 个不命中即提前放弃。命中后挂一个 8 秒一次性超时（`_ScheduleTimeout(-8000)`）并把轮询压到 200ms。
- **Loading**：三条水平扫描线（右下 Loading 文字 / 底部中央 / 屏幕居中）先排除红 `0xA60000`、蓝 `0x0070a3` 两种进关按钮（命中即放弃本次检测），再要求三线全白 `0xFFFFFF`（容差 0）→ 进入等待倍速按钮阶段，延迟 2 秒调度 `ActionBeginPause`。
- **等待倍速按钮**：`ActionBeginPause` 起一个 `PauseWaitIntervalMs`(30ms) 的自排程定时器状态机，硬超时 `PauseWaitTimeoutMs`(8000ms)。**这里原本是 `while(true)` 忙等**（无 Sleep、无超时）：忙等期间主线程被占满、`HotIf` 求值全部排队，系统据此累计低级钩子超时并最终静默摘除键盘钩子（表现为所有热键失效）——改成"每拍只做一次小区域 `PixelSearch` 后立即返回"正是为了把主线程让出去。常规路径每拍遇到三种情况都会结束等待：游戏窗口消失、游戏已切出前台（与 `CheckGameStatus` 的前置条件一致，继续等等于对着遮挡窗口做像素判断，既可能凭空注入一次暂停也白占主线程）、超时。
- **按住开局暂停（Hold 路径）**：`HotkeyActions.ActionBeginPauseHold` 按下 → `GameMonitor.BeginPauseHold()`：置 `_ReadyForPause` 并起同一套状态机（不做黑屏/Loading 前置；`_HoldNoDeadline` 期间**不判超时**，以松手为界），松手经 `HoldGuard.RegisterTail` → `EndPauseHold()`。三条必须保持的语义：① 松手时若接管前常规路径**本就在等待**（`_HoldKeepNormalWait`），保留它继续等，否则立即 `_ResetPauseWait()` 取消；② 命中时 `forcedPause` 生效——忽略 ② 的开关、且**代理指挥也保持暂停**（常规路径此时会取消暂停）；③ 每拍用 `HoldGuard.IsHolding()` 兜底：按下与松开几乎同时到达时收尾回调来不及注册，靠按住周期状态取消，避免识别无限跑。绑定为滚轮时没有松开事件，改走"按一次触发 + 常规 8s 超时收尾"（`BeginPauseHold(false)`）。
- **代理指挥识别**：命中倍速按钮后先按需暂停，再**后置**做代理识别（`TakeOver1/2/3.png` + `*90` 容差；右侧边缘命中 **且**"手"图标也命中才算代理）——后置是为了压低暂停延迟。判为代理则取消暂停（**按住触发时例外：保持暂停**）；自动二倍速在非代理时盲切一次倍速（进关默认 1 倍速），代理作战沿用游戏自动节奏不干预。
- 所有像素/图像搜索走 `Safe*` 包装（窗口/桌面不可用时按未命中，不抛 `OSError`）。像素检测前临时 `SetThreadDpiAwarenessContext(-3)`，**必须在 `finally` 里还原**原上下文（该切换只为本段像素检测服务，不影响 GUI 主窗口的 DPI 基准）。

## 双源更新与自动降级

更新系统支持 GitHub API 和国内源（腾讯云 COS+CDN）两源，`UpdateSource` 选首选源，失败自动降级备选源（`token_invalid`/`rate_limited` 静默降级）。国内源用 CDN 静态 `version.json`（`version`/`downloadUrl`/`releases`），`releases` 格式与 GitHub API 一致，复用 changelog 缓存。发布时 Action（`.github/workflows/release-sync.yml`）自动同步 exe 和 version.json 到 COS。

**v1.8.1+ 双源 SHA-256 下载校验**：`expectedHash` 从版本检查结果一路透传到 `downloader`，下载完成后用 `_GetFileSha256`（分块流式 `CryptHashData`）校验，不匹配则删除文件并弹窗中止（防篡改）。GitHub 源从 asset 的 `digest` 字段（`sha256:<hex>`，正则限定 `"name":"AFA.exe"` asset）提取；国内源从 `version.json` 的 `sha256` 字段提取。`version.json` 的 `sha256` 由发布 Action 计算写入。

## 更新渠道

`UpdateChannel` 设置为 1（正式版）或 2（测试版），版本检查器据此选择检查 stable releases 还是包含 pre-release。GUI 通过下拉框切换，默认正式版。

## 配置文件

INI 格式，三个 Section：`[Hotkeys]`、`[Main]`、`[Custom]`。`GitHubToken` 使用 Windows DPAPI（`token_protector.ahk` 的 `TokenProtector` 类）按当前 Windows 用户加密，加密值存于 `[Main]` 的 `GitHubTokenProtected` 键（带 `dpapi:v1:` 前缀），读取经 `_ReadGitHubToken()` 解密。旧版明文 `GitHubToken` 键在启动时自动迁移为加密格式并删除明文（迁移失败会保留原配置并提示恢复写入权限）。

**迁移与解密失败的两条硬约束**：① 迁移必须"先 `IniWrite` 加密值 → 回读校验一致 → 再 `IniDelete` 明文"，中途失败不得丢数据；② `TokenStorageStatus = "decrypt_failed"` 时**禁止用空值覆盖**仍可能可恢复的原加密配置——`SaveToIni`/`SaveAllToIni`/`PrepareGitHubTokenForStorage` 三处都有该守卫，缺一处就会让用户一保存就永久失去 Token。状态取值 `ok`/`migration_failed`/`cleanup_failed`/`decrypt_failed`，提示文案由 `GetTokenStorageWarning()` 给出。

## 数据文件

`%AppData%\ArknightsFrameAssistant\PC\changelog.json` 存储从 GitHub Releases API 拉取的所有版本发布内容，每次版本检查时更新。由 `ReleaseRepository._SaveChangelogCache()` 写入，`ChangelogChecker` 读取。

## 随游戏自动启动（game_auto_start.ahk）

机制：开启 Windows **进程创建成功审核**（子类别 GUID `{0CCE922B-…}`）+ 注册按安全日志事件触发的计划任务，事件 4688 命中 `NewProcessName` 时以 `--game-autostart` 拉起 AFA。以下五条是"改了就不工作"的点：

- **事件订阅必须同时匹配当前用户 SID 与 SYSTEM SID**（`S-1-5-18`）：启动器可能在系统上下文拉起游戏，此时 4688 的 `SubjectUserSid` 是 SYSTEM，只匹配当前用户则任务永不命中。
- **路径要注册三个变体**：配置路径 / 盘符真实路径 / NT 设备路径。`GetFullPathNameW`、`GetLongPathNameW` **都不解析 reparse point**（junction/符号链接），而 4688 的 `NewProcessName` 是内核解析后的路径——故 `_ResolveFinalPath` 用 `GetFinalPathNameByHandleW`（`CreateFileW` 不带 `OPEN_REPARSE_POINT` 才解析到最终目标；`dwFlags=2` 取 NT 形式）。变体按原样去重，**大小写差异保留为独立变体**以覆盖事件记录的差异。
- **多路径必须在同一个 `Select` 内用 `or` 连接**，保持 `Triggers.Count == 1`（多 trigger 语义不同）。
- **仅错误 1450（`ERROR_NO_SYSTEM_RESOURCES`）做 250/750ms 两次退避重试**；审核在短事务内完成并在 `finally` 恢复令牌权限原状态。
- **`Disable()` 只删计划任务，不关审核**（有意保留）；任务按 SID 独立命名；主体用 SAM 兼容账户名（SID 仅用于事件过滤与任务隔离），注册用 `6=TASK_CREATE_OR_UPDATE` + `3=TASK_LOGON_INTERACTIVE_TOKEN` 且**不传用户名密码**。任务语义一致时不重写。
- **校准比较主体时以任务 XML（`Definition.XmlText`）中 `<UserId>` 的 SID 为准**：COM `Principal.UserId` 读回的是不带计算机名的裸用户名，用户名与计算机名相同时 `LookupAccountNameW` 会把它解析成机器域 SID（`SidTypeDomain`），导致每次启动都误报 `principal_user` 漂移并重写任务。XML 取不到 SID 时才回退到按账户名解析，回退路径对裸用户名先查 `计算机名\用户名`、查不到再查原名（兼容域账户），两次都只接受 `SidTypeUser`。

## cmd `chcp 65001` 批处理陷阱

（`self_replacer.ahk`）

cmd 按当前控制台代码页解析批处理文件，中文 Windows 默认 GBK。在**批处理内部**执行 `chcp 65001` 会触发 cmd 重读文件并**错位解析中文行**，报 "is not recognized" 乱码错误（如 `'�我'`）。**触发需同时满足**：行以多字节中文字符结尾（cmd 会把行尾换行符吞进上一个多字节字符）。

已实测规避方式：每行以 ASCII 结尾（如 `...`，与 `正在等待程序关闭...` 风格一致）、中文块前插 ASCII 分隔行、或把中文内容合并成单行。

彻底修复需权衡：在 cmd 命令行前置 chcp（`cmd /c "chcp 65001 >nul & call 批处理"`）会引入 `cmd /c "..." & ...` 命令行签名、增加杀软误报风险（本分支反误报优化所忌）；批处理改 GBK 编码则 update 日志变 GBK（LogExporter 按 UTF-8 读取会乱码）。本分支决定保留 `Run batchFile` + 内部 chcp，用 ASCII 行尾规避。

## GitHub Action 发布同步

`.github/workflows/release-sync.yml` 监听 Release 发布事件，将 `AFA.exe` 和 `version.json` 上传到 COS 并刷新 CDN。`.github/scripts/build_version_json.py` 构建含全量 releases 历史的 `version.json`，处理首次初始化（COS 上无文件时自动创建），支持 stable/beta 双通道独立 version.json。Action 需要 5 个 GitHub Secrets（`COS_SECRET_ID`/`COS_SECRET_KEY`/`COS_BUCKET`/`COS_REGION`/`CDN_DOMAIN`）。`release-sync.yml` 不在 `.gitignore` 中，会被 git 跟踪。发布时对 `AFA.exe` 计算 sha256 写入 `version.json`（`--sha256` 参数）；**GitHub Actions step outputs 大小写敏感**——输出键名须用小写 `sha256`，否则引用为空。
