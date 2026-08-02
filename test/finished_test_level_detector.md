# 测试清单：`level_detector`

> 对应更改：新增关卡检测投票状态机（`LevelDetector`）——每秒对 6 个关卡内专属对象（费用图标 2 变体/退出按钮 7 变体/关卡内文本 2 变体/蓝堡 2 变体/敌人数 2 变体/暂停按钮 5 变体）做 ImageSearch 小模板匹配，命中 ≥2 个置位 `State.InLevel`、<2 复位；`GuardInLevel` 改为读 `State.InLevel`。模板已替换为 2560×1440 下的真实截图（20 张），搜索区域已按实际位置设置，统一提取到 `resources\` 子目录。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v1.6.2` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 25H2`（请确认） |
| 测试日期 | `2026-08-02` |

---

## 单元测试

本次更改不涉及可独立测试的单一功能（无新增 GUI 控件或配置项）。以下为机制级验证：

### 功能点：AFA 启动与模块加载

- [x] **操作**：启动 AFA（未编译脚本直接运行或 exe）
- [x] **预期**：正常启动，无语法错误弹窗（`LevelDetector` 类定义、`Objects` 数组、`FileExtractor` 路径引用均正常加载）
- [x] **操作**：查看日志目录 `%AppData%\ArknightsFrameAssistant\PC\logs\`
- [x] **预期**：普通日志（`afa-*.log`）无 `LevelDetector` 相关 Error/WARN；游戏窗口激活时屏幕中央显示 ToolTip（各对象 ✓/✗ + hitCount），进/出关卡时日志记录"关卡状态切换"

---

## 集成测试

### 流程：启动与投票机制冒烟

> 涉及模块：`level_detector.ahk`、`hotkey_actions.ahk`、`hotkey_control.ahk`

- [x] **前置**：AFA 启动，游戏处于任意界面
- [x] **操作**：查看日志确认投票轮询在跑
- [x] **预期**：游戏窗口激活时屏幕中央 ToolTip 每秒刷新各对象 ✓/✗ 与 hitCount N/6；进/出关卡时日志记录"关卡状态切换"，无 Error
- [x] **操作**：游戏窗口激活时按任一常规作战热键
- [x] **预期**：守卫读 `State.InLevel` 判定（无像素检测），按当前状态放行或拦截，日志正常记录

### 流程：进入关卡置位

> 涉及模块：`level_detector.ahk`、`hotkey_actions.ahk`、`file_extractor.ahk`

- [x] **前置**：模板已替换为真实截图，并确保已提取到 `%AppData%\ArknightsFrameAssistant\PC\resources\`（运行一次 AFA 触发 `FileExtractor.EnsureExtracted()`）
- [x] **操作**：游戏在主界面（非关卡）→ 开始进入关卡
- [x] **预期**：进入关卡后约 1s 内 `InLevel` 置位（日志"关卡状态切换：进入关卡"）
- [x] **操作**：关卡内依次按 14 个常规作战热键
- [x] **预期**：全部正常触发，无拦截日志

### 流程：退出关卡复位

> 涉及模块：`level_detector.ahk`、`hotkey_actions.ahk`

- [x] **前置**：已在关卡内（`InLevel=true`）
- [x] **操作**：正常通关 / 行动失败 / 中途主动退出
- [x] **预期**：退出关卡后约 1s 内 `InLevel` 复位（日志"退出关卡"），作战热键恢复拦截

### 流程：关卡外拦截 + 原键透传

> 涉及模块：`level_detector.ahk`、`hotkey_actions.ahk`（`KeyForward`）

- [x] **前置**：游戏处于主界面 / 准备界面 / 编队界面 / 基建 / 剧情界面
- [x] **操作**：依次按 14 个常规作战热键
- [x] **预期**：全部拦截 + 原键透传（游戏收到无 AFA 时的原生按键行为），日志有对应拦截记录

##### 异常路径

- [x] **异常**：编队/界面切换触发黑屏+Loading 场景 → **预期**：`InLevel` **不**误置位（6 个对象投票 <2，编队界面无关卡专属对象）

### 流程：失焦/切窗

> 涉及模块：`level_detector.ahk`

- [x] **前置**：已在关卡内（`InLevel=true`）
- [x] **操作**：Alt-Tab 切到其他窗口，再切回游戏
- [x] **预期**：切回后约 1s 内恢复正确 `InLevel`（回前台自愈；失焦期间不轮询）

### 流程：游戏进程退出复位

> 涉及模块：`level_detector.ahk`

- [x] **操作**：关闭游戏进程（游戏内退出或任务管理器结束）
- [x] **预期**：`LevelDetector.Poll` 检测到进程不存在 → `InLevel` 复位 `false`，AFA 不崩溃

##### 异常路径

- [x] **异常**：AppData 模板文件缺失 → **预期**：ImageSearch 返回 false，`InLevel` 恒 false，不崩溃、无 Error 弹窗
- [x] **异常**：游戏窗口突然关闭（`SafeWinGetClientPos` 失败）→ **预期**：轮询返回，不抛 `TargetError`，不崩溃

---

## 回归测试

### 功能：自动开局暂停（黑屏 → Loading → 暂停 → 代理识别）

- [x] 验证：正常进关卡，黑屏检测 → Loading 识别 → 自动暂停 → 代理作战识别整条链路正常

### 功能：守卫拦截透传（`KeyForward`）

- [x] 验证：关卡外按热键拦截后，down 补发 + 松开 up 补发正常；多键并发状态流正确

### 功能：热键注册与重建

- [x] 验证：切换标签页（常规作战 → 其他 → 常规作战）后，14 个守卫热键与 Up 变体正常重建，无残留、无重复注册报错

### 功能：快捷操作组 / 卫戍协议组（无守卫）

- [x] 验证：基建快速收取、肉鸽收取、跳过剧情、卫戍协议界面各热键正常（不受守卫改读状态影响）

---

## 追加测试：AutoExit 未应用即生效 bug 修复

> 对应更改：`game_monitor.ahk` 的 `CheckGameStatus` 自动退出/自动开局暂停判断改用 `Config.ReadImportantFromIni()`（读 INI 实际保存值）——`GetImportant` 读内存工作副本，GUI `TrackChange` 即时写内存导致勾选未应用即触发自动退出

### 流程：AutoExit 勾选未应用不触发退出

- [x] **前置**：游戏曾运行过（`State.GameHasStarted=true`），当前游戏进程已退出
- [x] **操作**：GUI 勾选"随游戏自动退出"，**不点击保存/应用**，等待数秒
- [x] **预期**：AFA **不**自动退出

### 流程：AutoExit 应用后不立即退出，待游戏下次退出再触发

- [x] **前置**：游戏曾运行过，当前进程已退出
- [x] **操作**：GUI 勾选"随游戏自动退出"并**保存/应用**，等待数秒
- [x] **预期**：AFA **不**立即退出（应用开启时重置 `GameHasStarted`）
- [x] **操作**：再次启动游戏 → 退出游戏进程
- [x] **预期**：AFA 随游戏退出正常触发

### 流程：AutoBeginPause 未应用不影响行为

- [x] **操作**：GUI 修改"自动开局暂停"开关但未应用
- [x] **预期**：黑屏/自动暂停行为与已保存值一致，不因未应用修改即时改变

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：AutoExit 勾选未应用即触发自动退出
- 现象：GUI 勾选"随游戏自动退出"未应用，AFA 立即随游戏进程退出
- 根因：`CheckGameStatus` 用 `GetImportant`（内存工作副本），GUI `TrackChange` 即时写内存导致未应用即生效
- 修复：改用 `ReadImportantFromIni` 读 INI 实际保存值（`AutoExit`/`AutoBeginPause` 两处）
- [x] 已解决
