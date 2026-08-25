# 测试清单：bilibili 服支持

> 对应更改：为多区服支持补充哔哩哔哩渠道（serverId=`BILI`）。BILI 与 CN 共享 company/product（`HyperGryph\Arknights`）→ 同一注册表根 `HKCU\Software\HyperGryph\Arknights`、游戏内按键设置互通；仅靠安装目录特征（`Arknights bilibili`，布局 `games\Arknights\Arknights.exe`）区分。改动包括：`ServerProfile` 新增 BILI 元数据与 `ScanPaths`、`FromExePath` 改为目录特征先于 app.info、`GamePathBILI` 配置键、三处硬编码区服列表改为 `ServerProfile.Ids()`、四语言显示名。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | v2.0.0-beta.2 |
| AutoHotkey 版本 | v2.0.26 |
| Windows 版本 | Windows 11 25H2（沿用最近测试清单测试环境，如不同请更正） |
| 测试日期 | 2026-08-25 |

---

## 单元测试

### 功能点：BILI 配置键

- [x] **操作**：全新环境（删除 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini` 后）启动 AFA，查看 `Settings.ini` 的 `[Main]` 段
- [x] **预期**：包含 `GamePathBILI=`（空值），且已有 `GamePathCN/JP/KR/EN`、`PreferredServer`、`LastActiveServer`、`Language`

### 功能点：BILI 注册表根（诊断包验证）

- [x] **操作**：打开 AFA 任意界面，导出诊断压缩包（或查看设置关于页的导出诊断入口），打开包内 `diagnostics.txt`
- [x] **预期**：包含 `RegistryRootBILI=HKCU\Software\HyperGryph\Arknights`，且与 `RegistryRootCN` 完全相同

### 功能点：已识别区服路径展示

- [x] **操作**：已配置 `GamePathBILI`（任一有效路径）后打开设置 →「启动与退出」，查看「已识别区服路径」
- [x] **预期**：出现一行 `BILI: <路径>`，且 CN/JP/KR/EN 各行仍正常显示
- [x] **操作**：点击该只读文本框
- [x] **预期**：可选中复制，不会进入热键编辑状态

---

## 集成测试

### 流程：BILI 客户端运行中识别

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`GuiManager`

- [x] **前置**：本机安装 BILI 客户端（形如 `X:\Arknights bilibili\games\Arknights\Arknights.exe`）并已运行
- [x] **操作**：启动 AFA，打开设置 →「启动与退出」，点击「识别游戏路径」
- [x] **预期**：「当前运行客户端」显示「哔哩哔哩服 (pid=…, hwnd=…)」；`Settings.ini` 的 `GamePathBILI` 被写入该路径
- [x] **操作**：鼠标悬停 AFA 托盘图标（BILI 客户端为前台时）
- [x] **预期**：托盘悬浮提示显示「哔哩哔哩服」
- [x] **操作**：查看日志（`%AppData%\ArknightsFrameAssistant\PC\logs\afa-*.log`）
- [x] **预期**：出现区服识别日志（如「识别到 BILI 游戏路径」/ 客户端集合变化含 serverId=BILI）

### 流程：BILI 与 CN 并存、按键互通

> 涉及模块：`GameClientRegistry`、`GameKeys`、`HotkeyService`

- [x] **前置**：CN 官服客户端与 BILI 客户端均已安装并运行
- [x] **操作**：依次把前台窗口切换到 BILI 与 CN，观察托盘悬浮提示
- [x] **预期**：托盘区服名随前台切换（哔哩哔哩服 / 国服），不会互相串台
- [x] **操作**：BILI 前台时，在游戏设置中修改某个游戏内按键（如技能键），等待 10 秒轮询后使用该功能的 AFA 热键
- [x] **预期**：AFA 使用与 CN 相同的按键映射（同一个注册表根），修改后热键自动重建并生效；在 CN 前台时映射同样为修改后的值（互通）

- [x] **操作**：BILI 前台时按下 AFA 自定义热键（如一键技能/撤退）
- [x] **预期**：发键行为正确，不会误用其它区服映射（BILI 与 CN 绑定的映射等价，功能正常执行）

### 流程：无进程识别 BILI 路径（新增扫描布局）

> 涉及模块：`ServerProfile`、`GameLauncher`

- [x] **前置**：BILI 客户端未运行，但安装在 `X:\Arknights bilibili\games\Arknights\Arknights.exe`（盘符根、`YostarGames\` 或 `Hypergryph Launcher\` 任一常见布局均可；若无真实安装可临时新建同名目录+占位 exe 文件验证扫描逻辑）
- [x] **操作**：打开 AFA 设置 →「启动与退出」→ 点击「识别游戏路径」
- [x] **预期**：无需启动游戏即可识别到 BILI 路径，写入 `GamePathBILI`，「已识别区服路径」出现 BILI 行

### 流程：随游戏自启包含 BILI 路径

> 涉及模块：`GameAutoStartManager`、`SettingsService`

- [x] **前置**：`GamePathBILI` 已配置（与已有 CN/JP 等路径并存）
- [x] **操作**：开启「启动明日方舟时自动启动小助手（以下路径均可触发）」并保存
- [x] **预期**：保存成功；在任务计划程序中查看任务（`ArknightsFrameAssistant-AutoStartWithGame-{SID}`）
- [x] **预期**：`Triggers.Count` 仍为 1，事件订阅的 `NewProcessName` 条件包含 BILI 完整路径（与其它路径为 `or` 连接）
- [x] **操作**：关闭 AFA 后单独启动 BILI 客户端
- [x] **预期**：AFA 被自动拉起（且为 `--game-autostart` 触发路径）

##### 异常路径

- [x] **异常**：仅安装 BILI 客户端、未安装 CN 官服客户端 → **预期**：BILI 识别正常、按键读取正常（共享 CN 注册表根，不弹「按键读取失败」警告）
- [x] **异常**：把 `GamePathBILI` 改成不存在的路径并保存 → **预期**：弹出「游戏路径不存在」确认提示；选择「否」则保存中止
- [x] **异常**：BILI 安装目录被重命名（目录特征失效）后运行客户端 → **预期**：app.info 兜底识别为 CN（与 BILI 语义等价：共享注册表根与按键设置），不崩溃、无异常弹窗

---

## 回归测试

### 功能：CN 官服识别与按键

- [x] 验证：CN 官服在默认布局（`Arknights Game`）下仍识别为「国服」，`GamePathCN` 正常写入；`ServerProfile.FromExePath` 目录特征优先调整不影响 CN 结论

### 功能：JP/KR/EN 识别

- [x] 验证：日服/韩服/国际服安装目录识别不受影响（`Arknights_JP/KR/EN` 特征仍生效）

### 功能：随游戏自启多路径

- [x] 验证：未新增 BILI 路径时，自启任务行为与改动前一致（单 trigger、多路径 or 连接）

### 功能：热键拦截正则

- [x] 验证：BILI 与 CN 绑定按键相同（同一注册表），拦截正则不会因 BILI 出现重复条目；热键注册/触发无异常

### 功能：多语言显示

- [x] 验证：切换 zh-Hant / ja-JP / ko-KR / en-US 后，「当前运行客户端」中 BILI 显示名分别为「嗶哩嗶哩服 / ビリビリサーバー / 빌리빌리 서버 / Bilibili Server」，无乱码、无缺键回退中文

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决

### 问题2：[问题描述]
- [ ] 已解决
