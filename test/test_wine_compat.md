# 测试清单：`wine_compat`

> 对应更改：新增 `base/environment.ahk` 统一探测运行环境（`Environment.IsWine`、`Environment.HasTouchInjection`）；Wine 下跳过 Windows 计划任务校准与触控注入初始化，热键动作回退为简单鼠标注入；`touch_injection.ahk` 恢复上游实现。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.2.0` |
| AutoHotkey 版本 | `v2.0.31` |
| Windows 版本 | `Wine 10.0.22000`（非 Windows 实机：Proton-CachyOS `cachyos-11.0-20261015-slr` + KDE Plasma 6 Wayland，Linux 7.3.0-1-mainline） |
| 测试日期 | `2026-11-05` |

---

## 单元测试

### 功能点：Wine 环境识别

- [x] **前置**：在 Wine 前缀中运行 AFA（`WINEPREFIX` 与游戏一致）。
- [x] **操作**：启动 AFA。
- [x] **预期**：不出现「关闭随游戏自动启动失败 / 计划任务删除失败」对话框，配置可正常保存（计划任务校准被跳过）。

### 功能点：触控注入能力探测

- [x] **前置**：Wine 环境的 user32 不含 `InjectTouchInput`。
- [x] **操作**：启动 AFA。
- [x] **预期**：不抛 `Call to nonexistent function`、进程不退出；启动日志出现 `热键已重建，数量=23`、`启动流程完成`。

### 功能点：Wine 下常规热键

- [x] **前置**：游戏运行中，AFA 已启动。
- [x] **操作**：按下 F（暂停）、Space（松开暂停）、D（倍速）。
- [x] **预期**：AFA 日志依次记录 `ActionPressPause 执行`、`ActionReleasePause 执行`、`ActionGameSpeed 执行`，按键透传正常，无异常弹窗。

---

## 集成测试

### 流程：Wine 下触控回退注入（暂停选中）

> 涉及模块：`base/environment.ahk`、`core/hotkey/hotkey_actions.ahk`（InjectTap/_InjectMouseTap）、`core/hotkey/hotkey_service.ahk`

- [x] **前置**：游戏运行于大厅（Wine），AFA 已绑定目标窗口；光标位于大厅可点击控件上。
- [x] **操作**：按下 W（暂停选中）。
- [x] **预期**：AFA 日志 `ActionPauseSelect 执行，key=w`；三连击中的中间一击准确落在游戏客户区坐标（实测点击「档案」按钮后档案面板打开）。

### 流程：Wine 下目标窗口绑定与热键重建

- [x] **前置**：游戏运行中（Wine），AFA 启动。
- [x] **操作**：切换游戏前台/后台。
- [x] **预期**：日志出现 `绑定目标窗口 hwnd=... exe=...\Arknights.exe`；`客户端集合变化，当前数量=1`；热键数量 23。

### 流程：Wine 下计划任务跳过

- [x] **前置**：Wine 环境（无 `Schedule.Service`）。
- [x] **操作**：启动 AFA，并在设置中保存一次配置。
- [x] **预期**：无 `0x80004001` 弹窗，设置保存成功。

##### 异常路径

- [ ] **异常**：Wine 下触控注入不可用且鼠标注入失败（如游戏窗口丢失）→ **预期**：记录 `LastError` 并跳过本次注入，不崩溃（本次未构造该场景，留待后续验证）。

---

## 回归测试

### 功能：Windows 下原触控注入路径

- [ ] 验证：Windows 实机上 `Environment.HasTouchInjection = true`，`touch_injection.ahk` 走原 `InjectTouchInput` 路径，热键功能与改动前一致（本次无 Windows 实机，仅静态确认分支不进入）。

### 功能：关卡守卫与关卡内热键

- [ ] 验证：Wine 下 `LevelDetector` 依赖 `BitBlt` 抓屏，抓屏全黑导致永远判定「不在关卡」，需在设置中关闭「仅在关卡内启用」开关；关闭后关卡内热键（暂停选中/技能/撤退）正常（本次已在非关卡界面验证回退注入链路，关卡内待人工复测）。

---

## 测试结果

- [ ] 全部通过
- [x] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：Wine 下每次重启弹出「检测到上次异常退出」对话框，需手动关闭后才完成热键注册
- [ ] 已解决

### 问题2：Wine 下偶发 `gui.ahk:151` 与 `ForegroundClientChanged` 回调异常（`This local variable has not been assigned a value.`）
- [ ] 已解决

> 说明：问题 1、2 均为 Wine 环境既有 GUI/事件行为，本次改动未修改 `ui/gui.ahk`，重启后热键与注入功能最终均可用。
