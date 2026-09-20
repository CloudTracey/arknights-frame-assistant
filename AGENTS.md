# AGENTS.md

This file provides guidance to AI coding agents (DeepSeek Harness / dsh, etc.) when working with code in this repository.

> **本文件只放「每轮任务都必须遵守的约束」。** 机制细节、历史沿革、参数取舍与陷阱解释在 [`docs/design/`](docs/design/README.md)（分册索引），**改到对应模块时再读**。
> 判断标准：这条内容「不知道就不会去查」吗？是 → 写进下方[铁律速查](#铁律速查新代码必须遵守)；否 → 写进分册。

## 项目概述

明日方舟帧操小助手（ArknightsFrameAssistant, AFA）— 优化明日方舟 PC 端体验的 Windows 工具。基于 **AutoHotkey v2** 开发，提供全按键自定义、过帧操作、卫戍协议一键操作等功能。仅对明日方舟进程生效。

## 构建与开发

- **语言**: AutoHotkey v2　|　**编辑器**: VS Code + AHK++ 扩展　|　**入口文件**: `src/main.ahk`
- **离线文档（优先于模型内置知识）**：AHK v2 官方文档在 `docs/ahk_docs/`（优先读 `docs/ahk_docs/lib/`），Windows API 文档在 `docs/win_docs/`。内置 AHK 知识可能过时或不完整。
- **不用 AHK 执行/编译 AFA**：默认不编译或启动 AFA；只有用户明确要求构建时才使用已验证的本地 AutoHotkey/Ahk2Exe 工具。GUI、提权、计划任务和真实游戏联动的验收由用户操作并反馈。
- **验收分工**：运行时与 GUI 验收以手工测试为主，Python 静态门禁检查**不能**代替运行时验收。每次完成行为修改后，调用 `test-checklist` skill 生成测试清单并逐项引导用户验证；清单放 `test/` 目录，格式参考 `test/template/test_template.md`。
- **改动前先跑静态门禁**（命令与适用场景见 [reference.md 工具表](docs/design/reference.md#静态检查工具)）：`layer_check.py`（跨模块引用/include 顺序）、`event_contract_check.py`（事件契约）、`i18n_check.py`（文案与语言资源）。
- **用 AHK 脚本做测试时的错误捕获**（否则只能拿到弹窗、拿不到结果），三层缺一不可：
  1. 脚本首行 `#ErrorStdOut "UTF-8"` —— `OnError` **抓不到加载期错误**（缺 `#Include`、include 路径写错、语法错误都会绕过它直接弹窗），该指令把这类错误送 stderr。依据 `docs/ahk_docs/lib/OnError.htm` 原文"It cannot be called for a load-time error"。
  2. `OnError` 全局回调 —— 运行时错误先写文件（或 `FileAppend("...", "*")` 写 stdout）再 **`return 1`** 抑制默认错误弹窗（返回 `0`/空串仍会弹窗；`ExitApp` 亦可，但要确保先写完）。
  3. 主流程 `try/catch` 兜住自身逻辑异常。
  运行与取错：`AutoHotkey64.exe /ErrorStdOut "脚本.ahk" > out.txt 2> err.txt`（`/ErrorStdOut` 命令行开关与指令等价但对编译后的 exe 无效；stderr 即错误文本，WSL 侧可直接读取；AHK 非控制台程序，stdout/stderr 必须靠重定向或管道捕获）。只想校验能否加载而不执行时加 `/Validate`（见 `docs/ahk_docs/lib/_ErrorStdOut.htm`、`docs/ahk_docs/Scripts.htm#ErrorStdOut`）。
- **不使用 worktree 开发**；提前查看 `.gitignore` 确认哪些更改不需要 commit（`CONTEXT.md`、`docs/adr`、`docs/architecture`、`docs/plan` 是本地文件，勿当作共享文档编辑）。
- **Git 操作全由用户自行进行**：用户没要求就不要 commit、不要 push、不创建 PR、不创建或改变 branch。用户要求提交时，对 diff 详细分类并分开提交，标题与描述通顺易懂。
- **翻译前先从 `docs/i18n/glossary.md` 取游戏术语官方译法**，再动手翻译。

## 架构概览

> **当前架构约束**（新代码必须遵守）：
> 1. 四层单向依赖 `bootstrap → ui → core → base`；core 不得引用 ui，base 不得引用 core/ui。
> 2. 所有 `.ahk` 只定义、零顶层副作用；启动由 `main.ahk` 显式 `App.Bootstrap()` 执行。
> 3. 事件命名统一 `XxxRequested`（命令）/ `XxxChanged`/`Started`/`Completed`（事实）；事件契约由 `tools/event_contract_check.py` 静态校验。
> 4. 配置写入只经 `SettingsService`；热键元数据只来自 `base/hotkey_schema.ahk`；`State` 类已删除，字段归唯一 owner。

**启动流程**（`main.ahk` 的 `App.Bootstrap()`）：环境初始化 → 单例识别 → 非管理员 `*RunAs` 提权重启 → `Logger.Init()` → 各域 `Init()` → `SettingsService.Initialize()` 加载配置 → 随游戏自启校准 → 资源提取 → `GameKeys.Init()` → `HotkeyService.HotkeyOn()` → `HookHealth.Start()` → GUI 初始化 → 发布 `AppStartCompleted` → `GameMonitor.Start()` → Legacy 事件收尾。
**三条顺序依赖**：`GameKeys.Init()` 必须在 `HotkeyOn()` **之前**；`HookHealth.Start()` 必须在 `HotkeyOn()` **之后**；`SingleInstance.Release()` 必须先于 `*RunAs` 重启。完整流程（含行号与每个调用）见 [module_responsibilities.md](docs/design/module_responsibilities.md#启动流程当前实现)。

**模块职责**（58 个 `.ahk` 的完整表）见 [module_responsibilities.md](docs/design/module_responsibilities.md#模块职责)。改某个模块前先查它，勿凭猜测扩写。

## 铁律速查（新代码必须遵守）

> 每条都是「不知道就会写出 bug」的硬约束。**规则名本身是链接**，点进去是该条的完整解释。

### AHK 语言与 API

| 约束 | 说明 |
|------|------|
| [写 AHK 代码前先扫一遍陷阱分册](docs/design/ahk_v2_pitfalls.md) | 以下是最易踩的几条；完整清单在分册内 |
| [删除前必须判存在](docs/design/ahk_v2_pitfalls.md#filedeletemapdeletehasownprop) | `FileDelete`/`Map.Delete` 对不存在目标**抛异常**，先 `FileExist`/`Has`；普通对象属性用 `HasOwnProp`，Map 键才用 `Has` |
| [判空用 `StrLen(v) = 0`](docs/design/ahk_v2_pitfalls.md#ahk-数值比较陷阱) | **不要用 `= ""`** 参与数值真值判断：两侧都是字符串时按字典序比较（`"0" != ""` 为真）；判数字用 `IsNumber`；字符串排序用 `StrCompare` |
| [不要写 `1..5`](docs/design/ahk_v2_pitfalls.md#ahk-v2-没有范围运算符) | v2 无 `..` 范围运算符，**编译不报错**但运行时报 `Float has no property named "5"`。用 `loop 5` 或数组字面量 |
| [箭头函数只支持单表达式](docs/design/ahk_v2_pitfalls.md#ahk-箭头函数限制与函数名引用) | `(p) => expr` 不支持 `{ }` 语句块，多行逻辑用嵌套函数闭包 |
| [Map 里的 `Fn:` 是函数对象](docs/design/ahk_v2_pitfalls.md#ahk-箭头函数限制与函数名引用) | 直接 `Fn(x)` 调用；对函数对象套 `Func(fn)` 是死代码，空 `catch` 还会掩盖真实异常 |
| [`SetTimer Func, 0` 是解除](docs/design/ahk_v2_pitfalls.md#settimer-func-0-是解除定时器) | 取消待触发回调、**不调用函数**；与 `SetTimer Func, -8000`（一次性调用）含义不同 |
| [回调按函数对象身份匹配](docs/design/ahk_v2_pitfalls.md#回调定时器热键按函数对象身份匹配) | `SetTimer` 启动/取消须用同一函数对象（缓存 `ObjBindMethod` 到静态属性），否则取消失效、定时器永不停歇；`HotIf`/`Hotkey` 同理须用唯一条件对象 |
| [下拉框 `.Value` 用索引、控件无 `Destroy()`](docs/design/ahk_v2_pitfalls.md#dropdownlistvalue-陷阱) | `DropDownList.Value` 始终 1-based（`AltSubmit` 只影响 `Gui.Submit()` 返回值）；[控件对象无 `Destroy()`](docs/design/ahk_v2_pitfalls.md#ahk-控件无-destroy)，Text 改 `.Value` 不会自动重新量宽 |
| [`File.Read` 只接受 1 参数](docs/design/ahk_v2_pitfalls.md#fileread-只接受-1-参数) | 二参形式抛 `Too many parameters`；读字节用 `File.RawRead(&Buffer, Bytes)` |

### 热键、注入与游戏交互

| 约束 | 说明 |
|------|------|
| [`{Blind}` 透传/注入](docs/design/key_designs_hotkey.md#send-的-capslock-与修饰键副作用) | `Send` 默认改写 CapsLock 并释放-重注入物理按住的修饰键。`GameKeys.SendDown/SendUp/Tap` 与 `KeyForward` 透传一律 `Send "{Blind}{...}"`；**不用**全局 `SetStoreCapsLockMode False` |
| [帧开头轮询推论](docs/design/key_designs_hotkey.md#明日方舟-pc-端按键识别帧开头状态轮询) | 游戏每帧开头轮询一次按键。AFA 注入某键 down 后、游戏下一帧轮询前，**不允许任何同键 up 到达游戏**（含透传补发），否则本次按下整次丢失 |
| [递归抑制须键级作用域](docs/design/key_designs_hotkey.md#send-注入会触发热键) | 回调内 Send 同键必须加防递归标志，且用 `Map(pureKey→true)` 而非全局布尔（全局布尔会让第二个键的物理 up 被误挡→卡键） |
| [`InjectedPressKeys` 抑制补发](docs/design/key_designs_hotkey.md#注入按下状态标记-gamekeysinjectedpresskeys) | 注入动作自管该键完整按下（down→up），`ActionUpForward` 见标记即抑制补发 up |
| [中断保护二选一](docs/design/key_designs_hotkey.md#线程抢占风险已修复) | 互斥语义不可混用：**只有过帧三件套用 `Critical`**（帧数精确性依赖完全不可中断）；需"防定时器抖动但放行其他热键"用 `Thread "NoTimers"` |
| [勿恢复热键洪峰告警](docs/design/key_designs_hotkey.md#热键频率阈值) | `A_HotkeyInterval := 0` 是**永久关闭**该告警（不是调高上限），代价已接受——不得擅自恢复 |
| [勿硬编码游戏窗口判定](docs/design/key_designs_hotkey.md#多区服与热路径预算) | 禁止在热键/监控路径直接写 `"ahk_exe Arknights.exe"`，宽松回退集中在 `GameTarget`；热键路径只允许 O(1) 查表 + 最多 2 次轻量 Win32 调用 |
| [勿依赖 Map 枚举顺序](docs/design/key_designs_hotkey.md#map-枚举顺序陷阱) | AHK v2 Map 枚举是哈希序；涉及"谁优先命中"的遍历必须走 `ServerProfile.Order` 显式顺序（否则官服布局被误判为 B服，issue #329） |
| [守卫位置函数用 `SafeWinGetClientPos`](docs/design/key_designs_hotkey.md#常规作战关卡守卫与按键透传) | 窗口关闭时返回 false 而非抛 `TargetError` |

### 配置、日志与 i18n

| 约束 | 说明 |
|------|------|
| [配置写入只经 `SettingsService`](docs/design/key_designs_base.md#config-读写分离与工作副本) | 运行时读配置用 `Read*FromIni()`（不碰内存工作副本），GUI 显示用 `Get*()` 工作副本；`Set*()` 仅写内存 |
| [新增热键/配置项四处同步](docs/design/key_designs_base.md#constants-类) | `HotkeySchema.Items`（带 `nameKey`）、`Constants.CustomNames`、`Config._DefaultCustom`、四张 locale 表；漏了会导致设置无法保存 |
| [主题规范化单一入口](docs/design/key_designs_ui.md#主题生命周期与预览) | 合法值集合与规则只在 `Constants.NormalizeThemeMode`/`Constants.ThemeModes`，勿在别处再写一份 switch |
| [文案键 = 中文原文](docs/design/i18n.md) | 新增用户可见文案即以中文原文为键，同步 zh-Hant / ja-JP / ko-KR / en-US 四表；日志/调试/内部异常**保持中文不译** |
| [大资源表拆 `Data2`](docs/design/i18n.md#资源编译内置-map) | AHK 单条静态 `Map(...)` 约 19KB 解析上限，勿把 `Data2` 合并回单表 |
| [布局/文案改动须五语言人工验证](docs/design/i18n.md#布局文案改动后须五语言人工验证) | 按 `test/test_i18n_four_language_regression.md` 逐语言核对换行/截断/对齐；优先"测量真实宽度"而非估算值 |
| [`Logger.Debug` 恒持久化](docs/design/key_designs_base.md#logger-日志系统) | 无条件写盘（不受开关控制）；`DebugEnabled` 仅控制实时调试控制台 |

### 调试与诊断

| 约束 | 说明 |
|------|------|
| [不能用环境变量注入构造测试条件](docs/design/key_designs_base.md) | AFA 非管理员时 `*RunAs` 提权会**重建干净环境块**，`$env:X='1'` 全部丢失。需特定变量时先在已提权会话设好再启动；**测试结论必须能自证前提成立** |
| [输入链冲突判据 = 症状，不是来源](docs/design/key_designs_base.md#键盘钩子健康探针) | Windows 无 API 枚举其它进程的低级钩子。用「物理按下未触发热键」+ `HookStarvationCount` 两个事实计数判读 |
| [`#Warn All, Off` 抑制了全部警告](docs/design/ahk_v2_pitfalls.md) | 调试异常行为时不会看到警告输出，需手动排查 |

## 代码规范

**以 [CONTRIBUTING.md](CONTRIBUTING.md) 为准**（完整版含注释规范示例）。AGENTS.md 只重申最容易跑偏的三条：

- 命名：函数/方法/全局变量/静态变量大驼峰 `CheckVersion()`，局部变量小驼峰 `gameProcess`，常量全大写 `MAX_RETRY`
- Commit 遵循 Conventional Commits `feat(scope): subject`，subject 用中文；scope 与模块文件名一致（如 `game_keys`）。**测试清单例外**：scope 用 `test`、类型用 `docs`（如 `docs(test):`）
- 分支命名 `feat/描述`、`fix/描述`、`ui/描述` 等；PR 目标分支为 `develop`（非 main）

## 版本号

- **AFA**：在 `src/lib/base/version.ahk` 的 `Version.Number` 中定义，版本检查器通过 GitHub API 或国内源 CDN 对比此值与远程 release tag/version.json
- **AHK**：当前为 v2.0.26，无需向用户确认
- **Windows**：跟随测试环境，自行获取，无需向用户确认
