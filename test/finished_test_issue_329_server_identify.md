# 测试清单：issue #329 官服误识别为 B服修复

> 对应更改：修复官服（`games\Arknights` 布局）被误识别为哔哩哔哩服。根因是 AHK v2 `Map` 枚举顺序为哈希序（非插入序），BILI 与 CN 共享 company/product 时兜底匹配优先级不可控。改动包括：`ServerProfile.Order` 显式顺序（CN 优先）、CN 增加 `games\Arknights` 扫描布局、`MigrateGamePaths` 误判残留自愈（GamePathBILI→GamePathCN）、无效路径保存**严格拒绝**（不再"确认后仍保存"）。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | v2.0.0 |
| AutoHotkey 版本 | v2.0.26 |
| Windows 版本 | Windows 11 25H2（沿用最近测试环境，如不同请更正） |
| 测试日期 | 2026-08-26 |

---

## 单元测试

### 功能点：误判残留自愈（Config 迁移）

> 注意：写入 `GamePathBILI` 的路径**必须是你设备上真实存在的官服路径**（如 `E:\Hypergryph Launcher\Arknights Game\Arknights.exe`）；不存在的路径不会被迁移（设计如此，仅对真实路径做区服判定）。

- [x] **前置**：备份 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`
- [x] **操作**：在 `Settings.ini` 的 `[Main]` 手工写入 `GamePathBILI=<你设备上真实存在的官服路径>`（且设备无真实 B服）后重启 AFA
- [x] **预期**：启动后 `GamePathBILI` 被清空、`GamePathCN` 被写入该路径；日志出现「误识别路径已迁移：GamePathBILI -> GamePathCN」；「已识别区服路径」显示 `CN: ...` 且**没有** BILI 行
- [x] **操作**：备份恢复后，把真实 BILI 路径写入 `GamePathBILI`（设备须真实存在 `Arknights bilibili` 目录）再重启
- [x] **预期**：BILI 行保留不被迁移

---

## 集成测试

### 流程：官服 games\Arknights 布局识别（issue #329 报告场景）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`GuiManager`

- [x] **前置**：官服安装于 `E:\Hypergryph Launcher\games\Arknights\Arknights.exe`（或盘上任意 `...\games\Arknights\Arknights.exe`）并已运行
- [x] **操作**：打开 AFA 设置 →「启动与退出」→ 点击「识别游戏路径」
- [x] **预期**：「当前运行客户端」显示「国服 (pid=…, hwnd=…)」；`Settings.ini` 写入 `GamePathCN=<该路径>`；「已识别区服路径」出现 `CN: ...` 且无 BILI 行
- [x] **操作**：官服前台时悬停 AFA 托盘图标
- [x] **预期**：显示「国服」
- [x] **操作**：查看日志 `logs\afa-*.log`
- [x] **预期**：出现「识别到 CN 游戏路径」/ 客户端集合变化含 `serverId=CN`，不再出现 BILI

### 流程：官服无进程扫描识别（新增 games\Arknights 扫描布局）

> 涉及模块：`ServerProfile`、`GameLauncher`

- [x] **前置**：官服未运行，但位于 `E:\Hypergryph Launcher\games\Arknights\Arknights.exe`
- [x] **操作**：打开设置 →「启动与退出」→ 点击「识别游戏路径」
- [x] **预期**：无需启动游戏即可识别到该路径并写入 `GamePathCN`

### 流程：BILI 识别回归（不受修复影响）

> 涉及模块：`ServerProfile`、`GameClientRegistry`

- [x] **前置**：BILI 客户端位于 `X:\Arknights bilibili\games\Arknights\Arknights.exe` 并已运行
- [x] **操作**：打开设置 →「启动与退出」→ 点击「识别游戏路径」
- [x] **预期**：「当前运行客户端」显示「哔哩哔哩服」；`Settings.ini` 写入 `GamePathBILI`，不误写 `GamePathCN`
- [x] **操作**：BILI 与官服同时运行，依次切换前台
- [x] **预期**：托盘区服名随前台切换（哔哩哔哩服 ↔ 国服）；BILI 前台时按键映射与官服互通（同一注册表根）

##### 异常路径

- [x] **异常**：手动填写不存在的路径并保存 → **预期**：弹出「游戏路径不存在」错误提示，**保存被严格拒绝**（中止落盘，需修正路径后才能保存）
- [x] **异常**：把已保存的「游戏路径」框内容改成不存在路径（如把 `Arknights.exe` 改成 `Arknights.e`）后点保存 → **预期**：同样弹错误提示并中止保存，`Settings.ini` 不变
- [x] **异常**：D盘/无游戏磁盘场景：所有常见扫描位置均无客户端 → **预期**：提示「未检测到游戏进程，且未在常见目录找到游戏路径」，不崩溃

---

## 回归测试

### 功能：旧版格式官服布局识别

- [x] 验证：`E:\Hypergryph Launcher\Arknights Game\Arknights\Arknights.exe`（含 "Arknights Game" 目录特征）运行/扫描均识别为国服，`GamePathCN` 正常

### 功能：JP/KR/EN 识别与路径展示

- [x] 验证：JP/KR/EN 安装目录识别不受影响；「已识别区服路径」按 `CN, BILI, JP, KR, EN` 顺序展示

### 功能：按键映射与随游戏自启

- [x] 验证：BILI/官服前台切换后热键映射正常（共享注册表）；自启任务仍为单 trigger 多路径

### 功能：诊断导出

- [x] 验证：诊断包 `diagnostics.txt` 中 `RegistryRootBILI` 与 `RegistryRootCN` 相同；客户端列表行 serverId 正确

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决

### 问题2：[问题描述]
- [ ] 已解决
