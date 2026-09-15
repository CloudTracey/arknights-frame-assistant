# 测试清单：`game_audio_mute`

> 对应更改：新增「一键静音」快捷热键，按进程（WASAPI 音频会话）静音/取消静音游戏音频；只影响游戏自身音频流，不影响语音软件等其他程序。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.0.3`（本次改动未提升版本号） |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 26220` |
| 测试日期 | `2026-09-15` |

---

## 单元测试

### 功能点：热键行与默认值

- [x] **操作**：打开设置窗口 → 「快捷操作」标签页 → 查看列表末行
- [x] **预期**：出现「一键静音」行（位于「返回上级菜单」之后）
- [x] **操作**：使用不含 `MuteGame` 键的配置启动
- [x] **预期**：输入框为空，且日志中热键启用明细不含 `MuteGame`（实测数量 19、`MuteGame` 出现 0 次）
- [x] **操作**：在输入框绑定 `F8` 后保存/应用
- [x] **预期**：日志热键启用明细出现 `MuteGame=F8`，数量 20

### 功能点：静音模块核心行为（直接调用 `GameAudioMute`，不依赖 GUI）

- [x] **操作**：对「尚未播放任何声音的进程」调用 `Query(pid)`
- [x] **预期**：`success=1 / found=0`（无音频会话不误报），且不改变任何状态
- [x] **操作**：建立真实音频会话（播放无声 WAV）后 `Query(pid)`
- [x] **预期**：`found=1 / muted=0`
- [x] **操作**：`Toggle(pid)` 两次
- [x] **预期**：第一次 `muted=1 且 previous=0`；第二次 `muted=0 且 previous=1`（切换语义正确）
- [x] **操作**：`SetMute(pid, true)` / `SetMute(pid, false)`
- [x] **预期**：与随后的 `Query` 结果一致（写入后回读确认）
- [x] **操作**：`Query(0)` 传入非法 PID
- [x] **预期**：`success=0 / message=未指定目标进程`，不抛异常
- [x] **操作**：核对 `_GuidBuffer` 解析出的 16 字节
- [x] **预期**：与 GUID 字符串字节序一致（实测 `88FFB7BF 3972 C94F 8FA207C950BE9C6D`）

### 功能点：五语言文案

- [x] **操作**：按 zh-Hans / zh-Hant / ja-JP / ko-KR / en-US 依次解析本次新增的 7 个键
- [x] **预期**：全部命中对应语言译文（含 `静音失败：{1}` 的 `Format` 插值），无回退到中文原文的情况；`tools/i18n_check.py` PASS

---

## 集成测试

### 流程：热键 → 动作 → 游戏音频静音（真实游戏）

> 涉及模块：`base/game_audio_mute.ahk`、`base/hotkey_schema.ahk`、`core/hotkey/hotkey_actions.ahk`、`core/hotkey/hotkey_service.ahk`、`base/tray.ahk`

- [x] **前置**：游戏运行中（`Arknights.exe`，PID 47072）；`MuteGame=F8`
- [x] **操作**：按一次绑定键
- [x] **预期**：游戏音频静音，托盘提示「已静音游戏音频」
- [x] **操作**：再按一次
- [x] **预期**：恢复原状态，托盘提示「已取消静音游戏音频」
- [x] **操作**：`WheelUp` 等滚轮类热键路径
- [x] **预期**：与按键路径行为一致（`_WaitMuteHotkey` 对滚轮跳过 `PureKeyWait`），不抛异常
- [x] **操作**：动作层直调（源码版本）：`GameTarget` 绑定到持有真实音频会话的进程后调用 `HotkeyActions.ActionMuteGame("F8")`
- [x] **预期**：`Query` 状态按 `0→1→0` 变化；游戏中链路与真实热键路径共用同一函数

> 说明：真实按键路径（热键注册 → `_WrapAction` → `ActionMuteGame`）已在本地用同一实现重新打包的 exe 上真机验证：日志记录
> `[HotkeyActions] ActionMuteGame：pid=47072 会话数=1，结果=已静音` / `结果=已取消静音`（共 4 次触发）。
> 本 PR 的**源码版本**验证到「动作层直调 + 整程序启动」层级；真实按键整链路按 AGENTS.md「真实游戏联动验收由用户操作并反馈」的约定，请维护者在真机确认（见「测试结果」）。

##### 异常路径

- [x] **异常**：游戏未运行（`ResolveGamePid()` 返回 0）→ **预期**：托盘提示「未找到游戏进程，无法静音」，不抛异常
- [x] **异常**：游戏在运行但没有音频会话（用无音频会话的隐藏进程实测）→ **预期**：托盘提示「未找到游戏音频会话，无法静音」，不抛异常
- [x] **异常**：单个端点角色枚举/激活失败 → **预期**：`failed` 计数 + 日志记录，不中断整体流程（继续尝试下一个角色端点）

### 流程：整程序启动与静态检查（源码构建）

- [x] **操作**：运行 `test/scripts/smoke_test.ahk`
- [x] **预期**：退出码 0（含新模块；校验 id 唯一、`ActionBindings` 与 Schema 双向覆盖、`ActionCallbacks` 标志一致、分组 Map 一致、无顶层副作用）
- [x] **操作**：用隔离配置启动源码版本
- [x] **预期**：日志出现「启动流程完成」「热键已启用…MuteGame=F8…」，界面出现「一键静音」行
- [x] **操作**：运行 `tools/layer_check.py --baseline KNOWN_VIOLATIONS`、`tools/event_contract_check.py`、`tools/i18n_check.py`
- [x] **预期**：三者均 PASS（分层 0 违规；本次未新增任何事件）

---

## 回归测试

### 功能：快捷操作分组与热键注册

- [x] 验证：热键数量 19 → 20，明细中除新增 `MuteGame` 外其余 id/绑定不变
- [x] 验证：`Constants.QuickHotkeys` 与 `HotkeySchema` 分组一致（冒烟测试校验）

### 功能：关卡守卫与按键透传

- [x] 验证：`MuteGame` 的 `guarded=false`，动作不调用 `GuardInLevel`、不注入按键、不写 `KeyForward.InterceptedKeys`（静音属纯 Win32 调用，不参与帧时序）

### 功能：热键冲突检测与设置流程

- [x] 验证：新热键以普通 schema 条目进入 quick 组，自动参与既有冲突检测与保存/应用流程（未改 `HotkeyConflictValidator` / `SettingsService`）
- [x] 验证：`MuteGame` 未被误加入 `Constants.CustomNames` / `_DefaultCustom`（不是自定义设置项）

### 功能：GUI 布局

- [x] 验证：行标签右对齐到既有固定标签列（`bindLabelW` 按最长标签计算），「一键静音」不超宽；未改动列栅格与窗口高度（窗口高度由「常规作战」页决定，快捷操作页增加一行仍在可见区内）

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

> 待维护者真机确认项：真实按键 → 游戏静音（源码构建）的整链路触发（按 AGENTS.md 约定由用户操作）；五语言界面人工核对（本次未改动布局宽度，风险较低）。

## 问题反馈

### 问题1：无

- [x] 已解决
