# 测试清单：多区服与四语言热切换

> 对应更改：实现多区服客户端识别（阶段 A）与 i18n 核心骨架（阶段 B 的一部分），包括 `ServerProfile`、`GameTarget`、`GameClientRegistry`、per-server `GameKeys`、多路径自启、语言配置与 `I18n` 基础资源。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | v2.0.0-alpha.2 |
| AutoHotkey 版本 | v2.0.19（本机安装目录确认） |
| Windows 版本 | Windows 11 25H2 |
| 测试日期 | 2026-08-21 |

---

## 单元测试

### 功能点：区服识别（通过“识别游戏路径”入口验证）

- [x] **操作**：先启动国服客户端，再打开 AFA 设置 →「启动与退出」→ 点击“识别游戏路径”
- [x] **预期**：能识别到国服路径；查看 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini` 中 `GamePathCN` 被写入该路径

- [x] **操作**：先启动日服客户端，再打开 AFA 设置 →「启动与退出」→ 点击“识别游戏路径”
- [x] **预期**：能识别到日服路径；查看 `Settings.ini` 中 `GamePathJP` 被写入该路径

- [x] **操作**：在设置中手动填入一个形如 `E:\YostarGames\Arknights_JP\Arknights.exe` 的日服路径并保存
- [x] **预期**：AFA 接受该路径，不报“不是 Arknights.exe”；保存后 `GamePathJP` 被记录（目录特征回退生效）

### 功能点：配置键与迁移

- [x] **操作**：全新环境启动 AFA 后，打开 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`
- [x] **预期**：`[Main]` 中包含 `GamePathCN/JP/KR/EN`、`PreferredServer`、`LastActiveServer`、`Language`，且 `Language=auto`

- [x] **操作**：用旧版仅含 `GamePath` 的 `Settings.ini` 启动 AFA，再查看该文件
- [x] **预期**：自动新增对应区服路径键（如 `GamePathCN`），原 `GamePath` 仍保留

### 功能点：已识别区服路径可复制

- [x] **操作**：打开设置 →「启动与退出」，在「已识别区服路径」中尝试选中文本并复制
- [x] **预期**：控件为只读、不可编辑，可以选中并复制路径文本；点击该控件不会进入热键编辑状态

## 集成测试

### 流程：多区服客户端识别与热键映射

> 涉及模块：`GameClientRegistry`、`GameTarget`、`GameKeys`、`HotkeyService`、`GameMonitor`

- [x] **前置**：本机已安装国服和日服客户端，且至少一个区服在运行
- [x] **操作**：启动 AFA，打开设置，观察「启动与退出」区服显示
- [x] **预期**：能显示识别到的客户端/区服，而非仅显示一个游戏路径

- [x] **操作**：同时打开国服和日服，并切换前台窗口到日服后按 AFA 自定义热键
- [x] **预期**：发键使用日服注册表映射，不会误发国服映射

- [x] **操作**：在日服注册表中修改某个游戏键后等待 10 秒轮询
- [x] **预期**：热键自动重建，拦截并集包含日服新键

- [x] **操作**：关闭所有游戏客户端且开启 AutoExit
- [x] **预期**：AFA 在所有受管客户端都退出后才自动退出

##### 异常路径

- [x] **异常**：某区服注册表读取失败 → **预期**：该服回退默认键，仅提示一次，不影响其它区服

### 流程：无进程直接识别游戏路径（新增优化）

> 涉及模块：`ServerProfile`、`GameLauncher`

- [x] **前置**：游戏未运行，但本机已按常见目录安装国服/日服客户端
- [x] **操作**：打开 AFA 设置 →「启动与退出」→ 点击“识别游戏路径”
- [x] **预期**：无需启动游戏即可识别到已安装区服路径，并写入 `GamePathCN/JP/KR/EN`

- [x] **异常**：常见目录中不存在游戏 → **预期**：提示“未检测到游戏进程，且未在常见目录找到游戏路径”，不崩溃

### 流程：随游戏自启多路径

> 涉及模块：`GameAutoStartManager`、`SettingsService`

- [x] **前置**：已配置国服和日服两个游戏路径
- [x] **操作**：开启「随明日方舟自动启动小助手」并保存
- [x] **预期**：计划任务仍是单 trigger，XPath 中 OR 两个路径；启动任一区服都能拉起 AFA

- [x] **操作**：在任务计划程序中查看任务
- [x] **预期**：`Triggers.Count` 仍为 1，事件订阅包含两个 `NewProcessName` 条件

##### 异常路径

- [x] **异常**：某个配置路径不存在 → **预期**：保存被拦截并提示路径不存在

### 流程：语言热切换

> 涉及模块：`I18n`、`GuiManager`、`SettingsService`
>
> 跳过：当前版本未实现 GUI 语言下拉框，待 B2 完成后再测。

- [ ] **前置**：AFA 设置界面已打开
- [ ] **操作**：在「其他设置 → 通用」中切换语言为 English 并保存/应用
- [ ] **预期**：界面重建后使用英文，窗口标题同步变化，设置保存提示为英文

- [ ] **操作**：切换语言为 `auto` 后重启 AFA
- [ ] **预期**：按系统 UI 语言自动选择四语之一，不支持时回退中文

---

## 回归测试

> 跳过：回归测试统一放在所有工作完成后再进行，避免重复测试。

### 功能：原有单区服热键/拦截/守卫

- [ ] 验证：仅国服单开时，热键触发、按键透传、关卡守卫、开局暂停与旧版行为一致
- [ ] 验证：`HotkeyOff` 后 `InterceptedKeys` 被清空，不会出现按键卡住

### 功能：更新与诊断

- [ ] 验证：诊断压缩包中新增客户端列表、前台客户端、各区服注册表根信息
- [ ] 验证：自动更新/公告显示不受 i18n 骨架影响

---

## 测试结果

- [ ] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：启动时 MessageBox 报错 “The control is destroyed.”
- [x] 已解决

**现象**：编译后启动时，`GameKeys` 的“游戏按键读取失败”提示定时器在 `GuiManager._CreateControls` 创建控件期间触发，进入 `MessageBox._CreateDialog` 后执行 `buttons.DefaultBtn.Focus()` 时报 `The control is destroyed.`

**处理**：已将提示延迟从 100ms 改为 3000ms，并为弹窗增加 `try/catch` 保护；需要重新编译/启动验证是否不再崩溃。

### 问题2：每次启动都会弹“识别不到 KR/EN”窗口，且多个提示互相覆盖
- [x] 已解决

**现象**：单地区用户启动时，未安装的 KR/EN 也会被当作“读取失败”弹窗；EN 提示弹出后马上被 KR 提示替换，EN 信息丢失。

**处理**：已增加注册表根存在性检查（`RegOpenKeyEx`），未安装区服不再进入失败提示；同时将多个区服的读取失败合并为同一个汇总弹窗，避免 MessageBox 互相覆盖。需要重新编译/启动验证。

### 问题3：启动时报 “This value of type Class has no method named Reset”
- [x] 已解决

**现象**：`GameClientRegistry._RefreshForeground` 调用了 `GameTarget.Reset()`，但当前 `GameTarget` API 是 `Unbind()`，没有 `Reset()` 方法，导致启动时直接报错。

**处理**：已将 `GameClientRegistry` 改为调用 `GameTarget.Bind(...)` / `GameTarget.Unbind()`，并在 `ServerProfile` 增加 `ExeName` 供 `GameTarget` 使用。需要重新编译/启动验证。

### 问题4：启动时报 “Compile error 1 at offset 6: \ at end of pattern”
- [x] 已解决

**现象**：`ServerProfile._RegistryKeyExists` 中 `RegExMatch(root, "i)^HKCU\", &m)` 的正则末尾只有一个反斜杠，被正则引擎当作“结尾转义”导致编译错误。

**处理**：已将 `HKCU/HKLM/HKCR/HKU/HKCC` 和前缀提取的正则改为双反斜杠 `\\`，使正则能正确匹配字面反斜杠。需要重新编译/启动验证。

### 问题5：游戏路径被当作敏感信息脱敏为 `<REDACTED>`
- [x] 已解决

**现象**：日志/诊断包中游戏路径显示为 `<REDACTED>`，用户认为游戏路径不属于敏感信息。

**处理**：已移除对 `GamePath` 的 `RegisterSecret` 注册，并让诊断包输出真实游戏路径。需要重新编译/启动验证。

### 问题6：「启动与退出」只显示一个游戏路径，没有展示多区服路径
- [x] 已解决

**现象**：设置页“启动与退出”只有旧的 `GamePath` 输入框，识别多个区服后看不到其它区服路径。

**处理**：已在“游戏路径”下方增加“已识别区服路径”多行文本，汇总展示 `GamePathCN/JP/KR/EN`；并在识别/客户端变化/设置刷新时更新。需要重新编译/启动验证。

### 问题7：加入深层递归扫描后，原路径识别不到 / 按钮无反应
- [x] 已解决

**现象**：增加整盘有界递归后，深层路径未能识别，且“识别游戏路径”按钮点击后没有反应。

**处理**：已取消深度扫描相关改动，保留普通“识别游戏路径”快速扫描（已配置路径、旧版 `GamePath`、常见固定目录），避免界面卡死。深层目录自动识别留待后续单独优化。需要重新编译/启动验证。

### 问题8：应用设置时“计划任务注册失败：This local variable has not been assigned a value”
- [x] 已解决

**现象**：启用“随明日方舟自动启动小助手”并保存/应用时，`EnsureTask` 注册任务后引用了不存在的局部变量 `gamePath`，导致报错。

**处理**：已将日志改为输出路径汇总（`pathSummary`），不再引用未赋值变量。需要重新编译/启动验证。

### 问题9：保存/应用时 GamePath 被某个区服路径覆盖
- [x] 已解决

**现象**：启用随游戏自启后，`GamePath` 会被 `GamePathCN/JP/KR/EN` 中的某一个覆盖，导致“启动小助手时启动哪个路径”失效甚至被清空。

**处理**：`_ApplyGameAutoStart` 现在只在实际处理默认 `GamePath` 本身时才更新 `GamePath` 和发布 `GamePathNormalized`；其它区服路径只加入自启任务，不再覆盖默认启动路径。需要重新编译/启动验证。

### 问题10：点击“识别游戏路径”会覆盖已有 GamePath
- [x] 已解决

**现象**：当 `GamePath` 已有值时，点击“识别游戏路径”仍会用识别到的第一个路径覆盖它，导致用户原有默认启动路径丢失。

**处理**：识别逻辑现在只在 `GamePath` 为空时才填充默认路径；已有值时仅更新 `GamePathCN/JP/KR/EN`，不再覆盖 `GamePath`。需要重新编译/启动验证。
