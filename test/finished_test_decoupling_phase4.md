<!-- 可交由AI根据此模版生成测试清单以节约工作量 -->
# 测试清单：`decoupling_phase4`

> 对应更改：阶段 4「State 归位」——删除 `State` 类，字段收归 `LevelDetector`/`GameMonitor`/`TimingService`/`HotkeyController`/`AppContext`，`ActionBeginPause` 迁入 `GameMonitor`，相关 core 文件移入 `core/` 子目录。

## 测试环境
| 项目 | 信息 |
|------|------|
| AutoHotkey 版本 | v2.0.26 |
| Windows 版本 | 待确认 |
| 测试日期 | 2026-08-18 |

---

## 单元测试

### 功能点：State 已删除

- [x] **操作**：运行 `grep -rn "\bState\." src --include="*.ahk"`
- [x] **预期**：无输出（注释除外）
- [x] **操作**：运行 `python3 tools/layer_check.py --baseline KNOWN_VIOLATIONS`
- [x] **预期**：输出 `PASS`，且基线中不再包含 `[state]` 条目

### 功能点：帧率与点击延迟（TimingService）

- [x] **操作**：在设置中切换帧率（30/60/90/120/144/165/180/240+）并保存/应用
- [x] **预期**：游戏内过帧步进与延迟随帧率正确变化，无 `State` 相关报错
- [x] **操作**：修改「点击延迟」自定义项并保存
- [x] **预期**：暂停选中/技能/撤退等点击延迟生效

### 功能点：关卡守卫（LevelDetector.IsInLevel）

- [x] **操作**：进入关卡后使用常规作战热键
- [x] **预期**：热键正常放行；日志中关卡状态仍能正确切换
- [x] **操作**：在非关卡界面使用常规作战热键
- [x] **预期**：被关卡守卫拦截并透传原键

### 功能点：失焦悬停操作（HotkeyController）

- [x] **操作**：在「自定义」中关闭「游戏窗口未激活时允许鼠标悬停触发热键」并应用
- [x] **预期**：游戏失焦且鼠标悬停时键盘热键不触发
- [x] **操作**：重新开启该选项并应用
- [x] **预期**：失焦悬停时键盘热键恢复触发

### 功能点：游戏运行记录（GameMonitor.ResetRunRecord）

- [x] **操作**：运行游戏后退出游戏，且开启自动退出
- [x] **预期**：AFA 在游戏退出后自动退出；应用设置开启自动退出时不会因历史记录立即误退出

---

## 集成测试

### 流程：程序启动与 owner 初始化

> 涉及模块：`main.ahk`、`AppContext`、`TimingService`、`GameMonitor`

- [x] **前置**：无游戏进程或游戏未启动均可
- [x] **操作**：启动 AFA
- [x] **预期**：正常启动，无 `State` 类未定义、无 owner 初始化顺序报错
- [x] **操作**：检查日志
- [x] **预期**：启动流程正常，`AppContext`/`TimingService` 相关初始化无异常

### 流程：自动开局暂停（ActionBeginPause 迁入 GameMonitor）

> 涉及模块：`core/monitor/game_monitor.ahk`、`hotkey_actions.ahk`

- [x] **前置**：明日方舟游戏窗口已打开
- [x] **操作**：进入关卡，等待自动开局暂停
- [x] **预期**：黑屏检测 → Loading 识别 → 自动暂停流程正常，日志不再出现 `State.` 引用
- [x] **操作**：代理指挥关卡
- [x] **预期**：识别代理指挥后自动取消暂停，行为与改动前一致

### 流程：自动退出与游戏状态

> 涉及模块：`core/monitor/game_monitor.ahk`、`settings/saver.ahk`

- [x] **前置**：开启自动退出
- [x] **操作**：运行游戏后退出游戏
- [x] **预期**：AFA 自动退出
- [x] **操作**：在设置中开启自动退出时游戏未运行
- [x] **预期**：不会因旧运行记录立即退出

### 流程：随游戏自动启动（AppContext）

> 涉及模块：`core/launch/app_context.ahk`、`core/launch/game_auto_start.ahk`、`log_exporter.ahk`

- [x] **前置**：已配置随游戏自动启动
- [x] **操作**：通过 `--game-autostart` 启动 AFA
- [x] **预期**：AFA 识别启动来源并跳过校准，行为与改动前一致
- [x] **操作**：生成诊断压缩包
- [x] **预期**：诊断信息中 `StartedByGameAutoStart` 值正确

### 流程：按键绑定窗口判定（GuiWindowName 删除）

> 涉及模块：`key_bind.ahk`、`gui.ahk`

- [x] **操作**：打开设置窗口，点击热键输入框开始录制
- [x] **预期**：录制正常；切换窗口失去焦点时录制自动取消（使用 `GuiManager.MainGui.Hwnd` 判定）

---

## 回归测试

### 功能：原有热键与设置

- [x] 验证：三组热键互斥启用、热键总开关正常
- [x] 验证：设置保存/应用/取消/重置正常
- [x] 验证：更新检查/公告正常

### 功能：静态检查

- [x] 验证：`src/lib/` 内无顶层副作用
- [x] 验证：`test/scripts/smoke_test.ahk` include 路径可解析，运行退出码为 0

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决

### 问题2：[问题描述]
- [ ] 已解决
