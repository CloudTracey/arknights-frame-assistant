# 测试清单：XelLauncher 硬链接运行目录的区服识别

> 对应更改：修复 issue #364 —— XelLauncher 开启「硬链接共享运行环境」后，官服运行目录
> （`...\.xel-linked-runtime\...\Official\Arknights.exe`）因祖先目录名含 "Arknights bilibili"
> 被误判为 B服，导致官服/B服识别互换、换服后 AFA 不自启动。现按运行目录的**渠道段目录名**
> 权威判定（`Official`→国服、`Bilibili`→哔哩哔哩服），未知布局仍回落原有识别链。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | v2.1.0-beta.1 |
| AutoHotkey 版本 | v2.0.26 |
| Windows 版本 | Windows 11 25H2（与 issue #364 报告环境一致；如不同请更正） |
| 测试日期 | 2026-09-15 |

---

## 单元测试

### 功能点：「当前运行客户端」区服名显示

- [ ] **操作**：打开 AFA 设置 →「启动与退出」标签页，查看「当前运行客户端」
- [ ] **预期**：游戏运行中时显示 `国服 (pid=…, hwnd=…)` 或 `哔哩哔哩服 (pid=…, hwnd=…)`；显示的区服与实际启动的客户端一致，不再出现两者互换

### 功能点：托盘区服名

- [ ] **操作**：游戏前台时把鼠标悬停在 AFA 托盘图标上
- [ ] **预期**：提示文本中的区服名与当前实际客户端一致（官服显示「国服」、B服显示「哔哩哔哩服」）

---

## 集成测试

### 流程：官服运行目录识别（issue #364 原始场景，**核心用例**）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`GuiManager`

- [ ] **前置**：XelLauncher 已开启「硬链接共享运行环境」；物理安装（Shared Root）为**官服**
      （本机布局示例：`F:\Program Files\Arknights bilibili\games\Arknights Game\`，
      注意启动器根目录名含 "Arknights bilibili" 正是本 bug 的触发条件）
- [ ] **前置**：用 XelLauncher 启动一次**官服**，确认游戏进程路径形如
      `...\.xel-linked-runtime\Arknights\<24位hex>\Official\Arknights.exe`
      （可在「任务管理器 → 详细信息 → 右键列头 → 添加“命令行/路径”」中核对）
- [ ] **操作**：打开 AFA 设置 →「启动与退出」→ 点击「识别游戏路径」
- [ ] **预期**：「当前运行客户端」显示 **国服**（修复前此处显示「哔哩哔哩服」）
- [ ] **预期**：「已识别区服路径」中 `CN:` 指向该 `.xel-linked-runtime\…\Official\Arknights.exe` 路径
- [ ] **操作**：查看日志 `%AppData%\ArknightsFrameAssistant\PC\logs\afa-*.log`
- [ ] **预期**：出现 `绑定目标窗口 … serverId=CN exe=…\Official\Arknights.exe` 与
      `识别到 CN 游戏路径：…\Official\Arknights.exe`，**不再**出现该路径被判为 `serverId=BILI`
- [ ] **操作**：查看 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini` 的 `[Main]`
- [ ] **预期**：`GamePathCN` 为该运行目录路径；官服运行目录**没有**被写进 `GamePathBILI`

### 流程：B服运行目录识别（反向用例）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`

- [ ] **前置**：保持硬链接开启，用 XelLauncher 启动一次 **B服**
- [ ] **操作**：在 AFA 设置中点击「识别游戏路径」
- [ ] **预期**：「当前运行客户端」显示 **哔哩哔哩服**；`GamePathBILI` 指向
      `…\.xel-linked-runtime\…\Bilibili\Arknights.exe`（或该机实际的 B服路径）
- [ ] **预期**：该 B服运行目录**没有**被写进 `GamePathCN`

### 流程：识别结果跨启动稳定（路径不漂移验证）

> 涉及模块：`ServerProfile`、`Config`

- [ ] **前置**：完成上面两条流程，记录「已识别区服路径」中显示的完整路径
- [ ] **操作**：完全退出 AFA 与游戏，重新用 XelLauncher 启动同一个服，再打开 AFA 并点「识别游戏路径」
- [ ] **预期**：显示路径与上次**完全一致**（哈希段不变）；「当前运行客户端」区服名一致
- [ ] **预期**：不弹出「路径不存在」提示，`Settings.ini` 中的路径未被清空重写

### 流程：传统切服（未开硬链接）不受影响

> 涉及模块：`ServerProfile`、`GameClientRegistry`

- [ ] **前置**：在 XelLauncher 中**关闭**硬链接（走传统切服：在同一目录里覆盖渠道差异文件）
- [ ] **操作**：分别启动官服与 B服，各自在 AFA 设置里点「识别游戏路径」
- [ ] **预期**：官服显示「国服」、B服显示「哔哩哔哩服」；路径均为物理安装目录（不含 `.xel-linked-runtime`）

### 流程：换服后 AFA 随游戏自启动

> 涉及模块：`GameAutoStartManager`、`GameLauncher`、`Config`

- [ ] **前置**：AFA 设置中「随明日方舟自动启动AFA」已开启；已按上面流程识别到两个服的路径
- [ ] **操作**：完全退出 AFA 与游戏 → 用 XelLauncher 启动**另一个服**（与上次识别的服不同）
- [ ] **预期**：AFA 随游戏自动启动（修复前此步失败，需手动打开 AFA）
- [ ] **操作**：AFA 启动后查看日志
- [ ] **预期**：日志中由本次启动的客户端路径识别出正确区服，没有出现区服互换

### 流程：旧误判残留自愈（升级场景）

> 涉及模块：`Config._ReconcileMisidentifiedPath`、`SettingsService`

- [ ] **前置**：先备份 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`；确认当前存在误判残留：
      `GamePathBILI` 指向 `.xel-linked-runtime\…\Official\Arknights.exe`
- [ ] **操作**：重启 AFA，查看日志
- [ ] **预期**：出现 `[Config] 误识别路径已迁移：GamePathBILI -> GamePathCN（路径：…）`
- [ ] **预期**：`Settings.ini` 中该路径从 `GamePathBILI` 移到 `GamePathCN`（若 `GamePathCN` 已有值则原键被清空）

##### 异常路径

- [ ] **异常**：AFA 识别到的运行目录在保存时恰好**不存在**（例如刚被 XelLauncher 清理/重建中）→
      **预期**：按既有行为提示「路径不存在」并询问是否清除；确认后该键被清空，不崩溃、不影响其他区服记录
- [ ] **异常**：手动把「游戏路径」框填成运行目录下**非** `Arknights.exe` 的文件（如 `Other.exe`）后保存 →
      **预期**：弹出「游戏路径不正确」并严格拒绝保存（文件名校验先于区服识别，行为与改动前一致）

---

## 回归测试

### 功能：非 XelLauncher 的物理安装识别

- [ ] 验证：直接启动物理安装的官服（`…\games\Arknights Game\Arknights.exe` 或 `…\games\Arknights\Arknights.exe`），「识别游戏路径」显示「国服」，`GamePathCN` 正确
- [ ] 验证：直接启动物理安装的 B服（`…\Arknights bilibili\games\Arknights\Arknights.exe`），显示「哔哩哔哩服」，`GamePathBILI` 正确
- [ ] 验证：路径均为物理安装目录，**不含** `.xel-linked-runtime`（确认改动未波及普通路径）

### 功能：其他区服识别与展示

- [ ] 验证：JP/KR/EN/繁中服（若本机安装）识别结论不变；「已识别区服路径」仍按 `CN, BILI, TC, JP, KR, EN` 顺序展示

### 功能：按键映射与热键

- [ ] 验证：官服 ↔ B服 切换前台后，热键功能正常（两服共享注册表根，改动不影响读键）
- [ ] 验证：前台区服切换时日志出现 `[GameKeys] 前台区服切换：CN` / `BILI`，且按键映射日志正常输出

### 功能：诊断导出

- [ ] 验证：导出诊断包后，`diagnostics.txt` 中 `Client1=…` 的 serverId 与实际客户端一致；`RegistryRootCN` 与 `RegistryRootBILI` 仍相同

---

## 测试结果

- [ ] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决

### 问题2：[问题描述]
- [ ] 已解决
