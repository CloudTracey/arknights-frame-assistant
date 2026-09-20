# 关键设计：热键、注入与游戏识别

> AGENTS.md 参考资料分册。AGENTS.md 只保留其中**必须遵守的铁律**（[铁律速查](../../AGENTS.md#铁律速查新代码必须遵守)），本文件保留完整机制、历史与理由。
> 涉及本域改动时读本文件；纯查「能不能这么写」看 AGENTS.md 铁律速查即可。

## 多区服与热路径预算

`GameTarget` 是“目标游戏窗口”的唯一 owner，禁止在热键/监控路径再直接写 `ahk_exe Arknights.exe`（宽松回退集中在 `GameTarget`）。热键触发路径只允许 O(1) 内存查表 + 最多 2 次轻量 Win32 调用（`GetForegroundWindow` / `GetWindowThreadProcessId`）；`ProcessGetPath`、WMI、`RegRead`、`PixelSearch`、文件 IO 一律走定时器慢路径。`GameClientRegistry` 维护 PID→区服缓存并由 `GameMonitor` 400ms 轮询刷新；`GameKeys` 按前台区服取映射，拦截正则为所有已安装区服并集。

### 区服识别要点

- **BILI（哔哩哔哩渠道，serverId=`BILI`）与 CN 共享 company/product（`HyperGryph\Arknights`）→ 注册表根与游戏内按键设置完全相同**，仅安装目录特征（`Arknights bilibili`，布局 `games\Arknights\Arknights.exe`，见 `ServerProfile.ScanPaths`）可与 CN 区分。
- **CN 官服自身也有 `games\Arknights\Arknights.exe` 布局**（如 `E:\Hypergryph Launcher\games\Arknights\Arknights.exe`）。
- **TC（繁中服，serverId=`TC`）的运营方为 Gryphline，company/product = `Gryphline\Arknights_TC`**（取自游戏本体 `Arknights_Data\app.info`，实测对应 Unity persistentDataPath `AppData\LocalLow\Gryphline\Arknights_TC`）。
  - `Company` **必须**保持 app.info 的拼写 `Gryphline`、不可沿用启动器的全大写——实测本机 `HKCU\Software` 下 `Gryphline`（游戏：`Arknights_TC`/`sdk_data`）与 `GRYPHLINK`（启动器：`Launcher`）两个键**并存**，且注册表查找**精确拼写优先**：`…\GRYPHLINK\Arknights_TC` 读不到、`…\Gryphline\Arknights_TC` 可读，拼错等价于把 TC 判成未安装。
  - TC 客户端未改键前只写 `KEYBOARD_SETTING_DISPLAY_*`、没有 `KEYBOARD_SETTING_V2_*`；`GameKeys` 的已知键回退会读到 DISPLAY 并解析出 0 条映射 → 用默认按键且不弹「读取失败」警告，**属预期**。
  - 安装布局为 `…\GRYPHLINK\games\Arknights_TC\`。

### 扫描范围限制（所有区服共有）

`_FindServerPath` 的 `parent` 只在**每个固定盘的根目录**下匹配，故扫描只覆盖 `<盘符>:\GRYPHLINK\games\Arknights_TC\`；启动器装在更深层级如 `D:\Tools\GRYPHLINK\` 时扫不到。且**整盘有界递归曾在多区服版本试过后回退**：深层路径仍未识别且「识别游戏路径」界面卡死，见 `test/test_multi_server_and_i18n.md` 问题7。该情形靠启动一次游戏由进程路径识别，或手动填「游戏路径」后由启动迁移写入 `GamePath<Id>`。

### Map 枚举顺序陷阱

**AHK v2 `Map` 的 for 枚举顺序是哈希序而非插入序**（实测 `Profiles` 枚举为 `BILI→CN→EN→JP→KR`）：涉及“谁优先命中”的遍历（app.info / 注册表兜底匹配）**必须走 `ServerProfile.Order` 显式顺序**（CN 在 BILI 之前，否则官服 `games\Arknights` 布局会被误判为 B服，issue #329）；切勿依赖 `Map` 插入顺序或用 `for k,v in Profiles` 推导优先级。

### 新增区服需同步

新增区服需同步：`ServerProfile.Profiles` **与 `ServerProfile.Order`**、`Config._DefaultImportant`/`Constants.ImportantNames`（`GamePath<Id>` 持久化键）与四个 locale 表的显示名，并避免在调用点硬编码区服 id 列表（统一用 `ServerProfile.Ids()`）。

## 热键注册与拦截

用 `HotIf(HotkeyContext)` 回调（`core/hotkey/hotkey_service.ahk` 顶部）限制热键作用域：

- 鼠标键/滚轮（LButton/RButton/MButton/XButton1/2/Wheel*）返回 `IsMouseInClient()`（悬停在游戏窗口上才触发，修复窗口外任务栏/桌面点击被吞）。
- 键盘键返回 `WinActive("ahk_exe Arknights.exe")` **或** `IsMouseInClient()`（#213：游戏失焦时鼠标悬停游戏窗口也能操作，动作层负责激活游戏；该失焦悬停路径受「自定义」页开关 `HotkeyService.GetHoverOperate()` 门控，保存/应用后生效，关闭后键盘键仅活动窗口触发，鼠标键/滚轮不受影响）。

**动作包装**（#213，`_WrapAction` 于 `_RegisterOne` 注册时套用）：主热键与 OnUp 型动作执行前 `WinActivate` 游戏 + `WinWaitActive`（超时 500ms 则跳过动作，避免按键发往非游戏窗口），激活后不恢复原窗口（焦点留在游戏）；守卫补发 Up 变体（`ActionUpForward`）与 SwitchKey 切换键**不包装**。

拦截正则通过 `GameKeys.GetInterceptPattern()` 动态生成——从注册表读取所有游戏按键 + `Escape|RButton|MButton`。AFA 热键绑定的按键若匹配拦截正则，不加 `~` 前缀（阻止原键传递到游戏），否则加 `~` 前缀（透传）。用户自定义游戏按键后，轮询检测到注册表变更自动重建热键，拦截列表随之更新。

**热键分组**：三组热键：CombatHotkeys（常规作战）、QuickHotkeys（快捷操作）、StrongHoldHotkeys（卫戍协议）。按标签页启用对应组，组间互斥。自定义按键按「按键类型」并入既有组（global 任何标签下注册、combat/quick 并入常规组、strongHold 并入卫戍组）；「自定义按键」标签页为管理型（不切换热键组）。`ActionCallbacks` 数据化（`{Fn, Guarded}`）声明守卫标志，为守卫拦截键注册 Up 变体补发透传。

## 常规作战关卡守卫与按键透传

常规作战 14 个功能经 `GuardInLevel(actionName, ThisHotkey)` 守卫——关卡内放行、关卡外拦截。拦截时由 `KeyForward` 类透传原键：

- `ForwardOriginalKey()` 补发 key down 并记录 `InterceptedKeys` 标志（带 `~` 前缀的键本就透传不补发；Up 型热键只补发 key up；滚轮发完整事件）。
- `ActionUpForward()` 为 Up 变体回调——**补发 key up**（对未按下的键是无害 no-op）：AHK Send 对物理按住的修饰键会“释放-重注入”，被拦截（无 `~`）的修饰键物理 up 也被吞。
- **Up 变体放行依据**是 `KeyForward.DownHandled`（运行时标记，`GuardInLevel` 在主热键触发时记录，无论守卫放行/拦截）——仅 down 被 AFA 处理过才放行补发 up；游戏外主热键不触发（down 透传）则不放行，物理 up 正常透传（打字不受影响）。
- `SuppressUp` 标志（**键级 Map**，按 pureKey 记录，非全局布尔）防 Send 注入的 up 被钩子重新捕获触发 Up 变体导致无限递归。
- 键名规范化：`PureKeyName` 保留左右修饰键（`<SHIFT`→`lshift`、`>SHIFT`→`rshift`）且统一大小写（防 `a/A` 拼写不一致漏发 Up），`InterceptedKeys` 关闭大小写敏感。
- `_RegisterOne()` 为守卫拦截键（非滚轮）注册 `X Up` 变体（类静态方法引用需 `.Bind(KeyForward)`），`DisableGroup()` 同规则注销。
- 失焦边界（按住修饰键 Alt+Tab 切走再松开）已由 DownHandled 机制解决。
- 守卫判定读 `LevelDetector.IsInLevel()`（无像素检测、无 DPI 切换）。
- 拦截日志用 Info 级别（同一按住周期经 `InterceptedKeys` 去重，避免 key repeat 刷屏）；**滚轮无 down/up 状态不写 `InterceptedKeys`，另按 100ms 时间窗节流 `KeyForward.ShouldLogGuard()`**——无极/高分辨率滚轮每次独立滚动都走拦截路径，若逐条落盘会形成每档位一次文件 IO 的洪峰，刷爆日志轨。
- 位置函数统一用 `SafeWinGetClientPos(&ww,&wh)`（窗口关闭返回 false 而非抛 TargetError）。

## 明日方舟 PC 端按键识别：帧开头状态轮询

游戏在每一画面帧的开头执行一次按键状态轮询，因此按下某键时游戏不会立刻判定为按下，必须按住到下一画面帧的开头才判定为按下；若在同一画面帧内按下又松开，下一帧开头轮询到的是松开状态，本次按下整次丢失。帧时长与游戏内帧率设置绑定（帧率设置 60 → 单帧约 16ms、120 → 约 8ms；`Constants.Delay*`/`TimingService` 按帧率换算延迟），且画面帧率会波动——游戏掉帧时单帧时长同步变长。

**推论（热键/注入层必须遵守）**：AFA 注入某键 down 之后、游戏下一帧轮询之前，不允许任何同键 up 到达游戏（含透传补发），否则注入的按下被整次吞掉。

## Send 的 CapsLock 与修饰键副作用

默认 `SetStoreCapsLockMode On` 下 `Send "{e Down}"` 会临时关闭 CapsLock（发送后恢复）；非 Blind Send 对物理按住的修饰键做“释放-重注入”（默认 Send 等价 `{Blind}{Ctrl up}x{Ctrl down}`；`^space::Send "{Ctrl up}"` 会把物理按住的 Ctrl 压回去）——注入事件被按“小写/无修饰”翻译，大写锁定开启或按住 Shift 时被拦截键的透传输入变成小写（密码输入场景干扰）。

修复：`GameKeys.SendDown/SendUp/Tap` 与 `KeyForward` 透传（Down/Up/滚轮）一律 `Send "{Blind}{...}"`——Blind 不改写 CapsLock、不释放物理按住的修饰键，注入即物理状态忠实镜像。**不用**全局 `SetStoreCapsLockMode False`：影响所有 Send 且不解决 Shift 释放-重注入。

## 注入按下状态标记 `GameKeys.InjectedPressKeys`

（“游戏内技能键 = AFA 热键键名时同帧丢按键”修复）

`GameKeys.SendDown` 记录该键“注入 down 已发、注入 up 未发”（规范化键名→发送时刻，TTL 1s 防动作异常中断后的陈旧标记误抑制后续透传），`SendUp` **先清标记再发送**——注入 up 自身若被钩子捕获触发 Up 变体（SendEvent 降级路径）时标记已清除仍会补发，不会在游戏内卡键。

`KeyForward.ActionUpForward` 检测标记存在即**抑制补发**（物理 up 仍被无 `~` 的 Up 变体吞掉）：注入动作自管该键的完整按下（down→up），补发 up 是与注入 down 同帧的孤儿事件，会让游戏帧轮询只读到 up 使注入按下丢失；未注入的键（SwitchView、关卡外透传）无标记，Up 补发与 DownHandled 失焦卡键修复不受影响。

键名与 `PureKeyName` 同规范（`StrLower(GetKeyName(...))`），CaseSense=false；定义于 `game_keys.ahk`（注入 owner），经 `MarkInjectedPress`/`UnmarkInjectedPress` 供裸 Send 的 ESC 路径（`ActionPressPause`/`_FrameSkip`/`ActionBack`）复用。

## 关卡检测与守卫判定

（`level_detector.ahk` + `core/hotkey/hotkey_actions.ahk`）

关卡检测使用 `LevelDetector` 投票状态机——每 333ms 对 3 个关卡内专属对象（关卡内文本/退出按钮/暂停按钮）做 PixelSearch 颜色检测（区域用相对比例定位，低分辨率时文本容差放宽到 20；v1.7.2 起默认容差 3→5/10、关卡内文本识别线加宽，以误识别率为代价适应更多窗口/屏幕配置），命中 ≥2 个置位私有 `InLevel`、<2 复位。

`GuardInLevel` 读 `LevelDetector.IsInLevel()` 判定（无瞬时像素检测）。`ActionCeaseOperations`（放弃行动）只发 `battleLeftPopup`、`ActionBack`（返回上级菜单）只发 ESC——两者功能分离于 v1.6.1；`BackCeaseOperations`（Important 配置项，默认关闭）开启后 `ActionBack` 在 ESC 后补发 `battleLeftPopup`，还原旧版"放弃行动"行为。

`InLevelGuard`（Important 配置项，默认开启）控制 `GuardInLevel` 守卫开关——关闭（`InLevelGuard=0`）后 `LevelDetector` 停止轮询并强制 `InLevel=true`，守卫直接放行（零 I/O）；开启后恢复 333ms 轮询。

### 线程抢占风险（已修复）

`LevelDetector` 的 SetTimer 轮询与热键回调同为 priority 0，AHK 单线程下新线程会中断当前线程（`misc/Threads.htm#Interrupt`）——Poll 的 PixelSearch（每次最多 16 色）会随机插入时序敏感动作的 `USleep` 忙等，拉长实际间隔（5~50ms）导致过帧波动（一次过两帧/不过帧）。

修复：时序敏感动作的 Send/Touch 序列加中断保护（单次 `Tap` 动作无需）——**过帧三件套（16/33/166ms）保留 `Critical`/`Critical "Off"`**（帧数精确性依赖完全不可中断，连热键也不放行）；**暂停选中/技能/撤退、一键技能/撤退、视角切换 v1.9.4 起改用 `Thread "NoTimers"`/`Thread "NoTimers", false`**（只挡定时器轮询，放行其他热键——动作中可即时响应倍速等热键；`Critical` 会连热键一起挡掉，故非过帧动作不再用）；`USleep` 到期时记录 overshoot 诊断日志（`current-target` 换算毫秒，≥1ms 时 `Logger.Debug`）便于观察中断。

## GameKeys 类

负责游戏按键的动态识别。核心流程：`Init()` 首次读取注册表并启动 10s 定时器 → `_OnPoll()` 定时比对 hex，有变更则重新解析 JSON → 更新 `_Bindings` → 调用 `HotkeyService.EnableByTab()` 重建热键。每 10 秒轮询注册表检测变更，自动重建热键。

数据来源：从 `HKCU\Software\HyperGryph\Arknights` 读取 `KEYBOARD_SETTING_V2_h*`（REG_BINARY→hex→JSON），将 Unity KeyId 映射为 AHK 键名（区服差异见[多区服与热路径预算](#多区服与热路径预算)）。**六层 fallback 防御**（精确→小写→numX→alphaX→char*→单字符），读取失败回退默认值并弹警告。

`SendDown`/`SendUp`/`Tap(gameFunc)` 三个方法封装了查表+Send 逻辑，接受注册表中的 function 名（如 `"releaseSkill"`），内部转换为用户实际绑定的 AHK 键名，供 `core/hotkey/hotkey_actions.ahk` 调用。`GetInterceptPattern()` 动态生成热键拦截正则。

游戏内绑定的鼠标键（自定义名 `mouseLeft/Right/Middle/Forward/Back` → `LButton/RButton/MButton/XButton2/XButton1`，标准 Unity `Mouse0-4`）同样映射进 `_Bindings` 参与拦截正则。注册表键名前缀匹配 `KEYBOARD_SETTING_V` 应对游戏版本更新。ESC 和 LButton 不经过 GameKeys（不可重新绑定的系统级按键）。

## Send 注入会触发热键

AHK 的 Send 命令注入的按键事件默认会被自身钩子捕获并触发热键。Up 变体回调用 Send 补发 key up 时，若放行条件不含递归抑制，注入的 up 会再次触发 Up 变体 → 无限循环补发 → 系统键盘状态被轰炸、按键完全失灵。

回调内"Send 同键"的机制必须加防递归标志（如 `KeyForward.SuppressUp`，**须键级作用域**——用 `Map(pureKey→true)` 而非全局布尔，全局布尔会在多键同松时让第二个键的物理 Up 落在第一个键补发窗口内被误挡，`HotkeyContext` 条件失败→物理 up 被吞→卡键）。

## AHK 线程优先级 vs Critical/NoTimers

（`core/hotkey/hotkey_actions.ahk`）

AHK 优先级规则是"**新线程优先级低于当前线程才不能中断**"，且低优先级事件按下会被**直接丢弃（not buffered）**而非排队（`misc/Threads.htm#Priority`）——"提高热键优先级、降低定时器优先级"的方案有静默丢键风险（动作快结束时按的低优先级热键会整个丢失），AHK 文档明确 Critical 因能缓冲事件而优于 Priority。

`Thread "NoTimers"` 是"只挡定时器、放行热键"的精确工具（`Thread.htm`："similar to Critical except that it only prevents interruptions from timers"），线程级设置、无需改热键注册。选用原则：需"防定时器轮询抖动、但允许其他热键中断"时用 `Thread "NoTimers"` 代替 Critical；需"完全不可中断"（帧数精确）时保留 Critical。

## 明日方舟按键限制

游戏设置禁止将 Ctrl 绑定为游戏内按键，故 Ctrl 不命中拦截正则——纯 Ctrl 热键的卡键路径无法在真实环境复现/测试。

## 热键冲突实时检测

`HotkeyConflictValidator.FindAll()` 在 CombatHotkeys+QuickHotkeys 组和 StrongHoldHotkeys 组内分别检测重复（组间不互检）；自定义按键按「按键类型」并入两组（global 始终生效故并入两组，combat/quick 入常规组、strongHold 入卫戍组），同对冲突跨组去重。

`GuiManager.RefreshHotkeyConflicts()` 用增量字体更新——仅对新进入冲突的控件使用主题语义色 `cError`、离开冲突的恢复 `cText`，避免全页闪烁。`UpdateSaveButtonState()` 据 `IsModified && !HasHotkeyConflicts` 决定按钮启用。`key_bind.ahk` 的 `NotifyBindingChanged` 发布 `HotkeyBindingsChanged` 触发刷新。切换标签页不丢弃修改，冲突状态跨标签页保持。

## 热键频率阈值

AHK v2 用内置变量 `A_MaxHotkeysPerInterval`（默认 66 热键/2000ms）而非 v1 的 `#MaxHotkeysPerInterval` 指令；被拦截的游戏键每个按键触发 down+up 两个热键，极速连打 WASD 等易超默认值弹警告框，`main.ahk` 已设 200。

**#279 起同时设 `A_HotkeyInterval := 0`**：高分辨率/无级滚轮可轻松超过 200 次/2000ms，触发警告弹窗与系统“嘟嘟”提示音；设 0 的含义是**永久关闭该洪峰告警**（不是调高上限）。已接受的代价：未来若出现“热键自触发循环”将不再有告警兜底，需另行评估热键注册/InputLevel 加固，**不得擅自恢复该告警**。

## FrameSkip 自定义延迟

三档过帧延迟（16ms/33ms/166ms）可通过"自定义"分类中的"过帧档位1/2/3" Edit 控件自定义。延迟值存为 `FrameSkip*Delay` 自定义配置项，Action 函数通过 `Config.GetCustom()` 读取。`GuiManager` 维护 `FrameSkipDelayKeys` 列表和 `FrameSkipLabels` Map，`_UpdateFrameSkipLabels()` 在保存/应用后动态更新"常规作战"标签页的过帧行文本。

## FileInstall 嵌入资源

编译时通过 `FileInstall` 将 `logo.ico`、`resources/images/TakeOverButton_*.png`（三张代理作战按钮截图）和关卡检测模板（保留备用，PixelSearch 方案不依赖）打包进 exe，运行时由 `FileExtractor.EnsureExtracted()` **统一提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\` 子目录**（避免散落根目录）。`logo.ico` 使用文件大小校验（`FileGetSize`）判断是否需要重新提取以防止旧版本残留。新增需要嵌入的资源时遵循此模式，在 `FileExtractor` 类中添加路径和提取逻辑。
