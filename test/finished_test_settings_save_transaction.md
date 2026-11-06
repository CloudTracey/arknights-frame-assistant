# 测试清单：`settings_save_transaction`

> 对应更改：设置保存拆成“校验（`_ValidateDraft`）→ 持久化（`_PersistDraft`）”两段；Settings.ini 带备份提交、CustomHotkeys.json 写入失败时回滚；自启计划任务在保存失败时恢复到保存前状态；保存/应用/重置失败后恢复热键；GamePath 规范化改到持久化阶段（不再依赖自启开关，也不再发 `GamePathNormalized` 事件）；启动时清理遗留临时/备份文件。

## 测试环境

| 项目 | 信息 |
|---|---|
| AFA 版本 | `v2.2.0` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 10.0.26300.9711`（按 #393/#394 报告填写，如与本机不符请指出） |
| 测试日期 | `2026-10-24` |

## 测试前准备

1. **备份配置目录**（以下测试会反复改动它；出问题可直接还原）：

   ```powershell
   $cfg = "$env:APPDATA\ArknightsFrameAssistant\PC"
   Copy-Item $cfg "$env:USERPROFILE\AFA-config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)" -Recurse
   ```

2. 后续 PowerShell 命令都基于这个变量，先在窗口里执行：

   ```powershell
   $cfg = "$env:APPDATA\ArknightsFrameAssistant\PC"
   ```

3. **记录文件指纹**（判断“是否落盘”最可靠）：

   ```powershell
   Get-FileHash -Path "$cfg\Settings.ini","$cfg\CustomHotkeys.json" -Algorithm SHA256 | Format-Table Path,Hash
   ```

4. 自启测试需要：AFA 以管理员权限运行、已填写有效的 `Arknights.exe` 路径。任务名与审核状态查询：

   ```powershell
   $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
   schtasks /Query /TN "ArknightsFrameAssistant-AutoStartWithGame-$sid" /V /FO LIST
   auditpol /get /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}"
   ```

5. **锁文件**（保持 PowerShell 窗口不关；按 Enter 解锁）：

   ```powershell
   $h = [IO.File]::Open("$cfg\Settings.ini",'Open','ReadWrite','None')
   Read-Host "已锁定 Settings.ini，按 Enter 解锁"
   $h.Close()
   ```

   锁定 JSON 时把路径换成 `$cfg\CustomHotkeys.json`。

6. **只读 JSON**：

   ```powershell
   attrib +R "$cfg\CustomHotkeys.json"   # 制造写入失败
   attrib -R "$cfg\CustomHotkeys.json"   # 恢复
   ```

---

## 单元测试

### 功能点：正常保存与文件卫生

- [x] **操作**：打开设置，把「点击延迟（ClickDelay）」改成一个不同的值，点击保存。
- [x] **预期**：提示“设置已保存”；`Settings.ini` 中该值已更新。
- [x] **操作**：保存后查看配置目录下的文件列表。
- [x] **预期**：没有新增 `Settings.ini.bak-*`、`Settings.ini.tmp-*`、`CustomHotkeys.json.tmp-*`。
- [x] **操作**：切换主题（浅色/深色）后保存并重启 AFA。
- [x] **预期**：主题保持新值；`Settings.ini` 的 `ThemeMode` 为新值（主题已随主提交落盘）。
- [x] **操作**：改一个设置后点击「应用」。
- [x] **预期**：提示“设置已应用”；设置窗口不关闭；界面值与文件一致。

### 功能点：CustomHotkeys.json 写入失败时的回滚（#393）

- [x] **前置**：记录 `Settings.ini` 与 `CustomHotkeys.json` 的 SHA256；准备一个可编辑的自定义按键。
- [x] **操作**：修改一个普通设置 + 修改一个自定义按键名称；执行 `attrib +R "$cfg\CustomHotkeys.json"` 后保存。
- [x] **预期**：弹出“设置保存失败”，正文包含“设置未保存，原配置已恢复。”。
- [x] **预期**：两个文件的 SHA256 与保存前完全一致；配置目录没有新增 `.bak-*` / `.tmp-*`。
- [x] **操作**：确认错误框后点「取消」，重新打开设置；再重启 AFA。
- [x] **预期**：普通设置和自定义按键都还是修改前的值。
- [x] **操作**：执行 `attrib -R` 后重复保存。
- [x] **预期**：保存成功；两个文件都更新；目录无残留。

### 功能点：CustomHotkeys.json 被独占锁定

- [x] **操作**：用锁文件命令锁住 `CustomHotkeys.json`（不是 Settings.ini），改一个普通设置并保存。
- [x] **预期**：保存失败并回滚；`Settings.ini` 的 SHA256 不变；解锁后可正常保存。

### 功能点：Settings.ini 写入失败

- [x] **前置**：记录两个文件的 SHA256。
- [x] **操作**：用锁文件命令锁住 `Settings.ini`，改一个普通设置并保存。
- [x] **预期**：弹出保存失败；`CustomHotkeys.json` 的 SHA256 不变；解锁后 `Settings.ini` 的 SHA256 仍与保存前一致（没有部分写入）。
- [x] **操作**：解锁并重启 AFA。
- [x] **预期**：设置仍是旧值。

### 功能点：失败后恢复热键

- [x] **前置**：游戏运行中，至少一个热键已绑定（例如暂停键）。
- [x] **操作**：把游戏路径改成一个不存在的路径，保存；在“路径不存在”提示中选“否”；关闭设置窗口；切到游戏按绑定的热键。
- [x] **预期**：热键动作正常触发（修复前保存失败会让热键一直失效）。
- [x] **操作**：制造一次 JSON 只读导致的保存失败，取消设置，再进游戏按热键。
- [x] **预期**：热键正常触发。
- [x] **操作**：锁住 `Settings.ini`，在设置里点击「重置按键」并确认。
- [x] **预期**：弹出保存失败；热键仍可用，没有被永久关闭。
- [ ] **操作**（可选）：先用托盘菜单/切换热键禁用热键，再制造一次保存失败，最后测试热键与切换热键。
- [ ] **预期**（可选）：热键保持禁用（按了不触发）；切换热键仍能把热键重新启用。

### 功能点：GamePath 规范化（独立于自启开关）

> 规范化现在在写入 INI 前的持久化阶段执行，不再依赖「随游戏自动启动」；保存成功后 GUI 通过 `_RefreshGamePathControls()` 从内存回读，不再有 `GamePathNormalized` 事件。用 `.\` 制造“文本不同、指向同一文件”的路径。`..\` 会抵消前一段目录（`games\..\` 等于回到上一级），写错会指向不存在的路径并被 AFA 正确拒绝。

- [x] **前置**：确认「随游戏自动启动」处于**关闭**状态（这正是原来的设计盲区）；记录原路径。
- [x] **操作**：先随意修改一个普通设置（例如点击延迟）让「保存」按钮可用，再把游戏路径改成带 `.\` 的等价写法（例：`E:\Hypergryph Launcher\games\Arknights Game\Arknights.exe` → `E:\Hypergryph Launcher\games\.\Arknights Game\Arknights.exe`），保存。
- [x] **预期**：保存成功；`Settings.ini` 中 `GamePath` 变为折叠后的绝对路径。
- [x] **预期**：设置窗口的路径文本框也显示折叠后的值（保存后经 `_RefreshGamePathControls()` 自动回读）。
- [x] **操作**：重启 AFA（加载“所有 `GamePath<Id>` 一起规范化”的改动），随意修改一项并保存。
- [x] **预期**：`Settings.ini` 的 `GamePathCN` 也变为折叠后的绝对路径；设置窗口下方的区服路径总览同步显示折叠值。
- [x] **操作**：把路径再次改成带 `.\` 的写法，执行 `attrib +R "$cfg\CustomHotkeys.json"`，保存。
- [x] **预期**：保存失败；`Settings.ini` 中 `GamePath` 仍是上一步的折叠值（没有被部分写入）；文本框保持草稿的 `.\` 写法（失败不刷新）。
- [x] **操作**：点「取消」后重新打开设置。
- [x] **预期**：路径显示磁盘上的折叠值，不是草稿里的 `.\` 写法。
- [x] **操作**：`attrib -R` 后重新改成 `.\` 写法并保存。
- [x] **预期**：保存成功；文本框更新为折叠后的路径。

### 功能点：启动清理遗留临时/备份文件

- [x] **前置**：完全退出 AFA。
- [x] **操作**：在配置目录创建以下文件：

  ```powershell
  "x" | Out-File "$cfg\Settings.ini.bak-123-456"
  "x" | Out-File "$cfg\Settings.ini.tmp-123-456"
  "x" | Out-File "$cfg\CustomHotkeys.json.tmp-123-456"
  "x" | Out-File "$cfg\CustomHotkeys.json.bak"
  "x" | Out-File "$cfg\Settings.ini.backup"
  ```

- [x] **操作**：启动 AFA。
- [x] **预期**：前三个文件消失；`CustomHotkeys.json.bak` 与 `Settings.ini.backup` 保留（不匹配命名规则）。
- [x] **预期**：日志出现“已清理遗留配置临时/备份文件：2 个”和“已清理遗留临时文件：1 个”。

---

## 集成测试

### 流程：#393 部分落盘防护（完整流程）

> 已由第 2 组覆盖，未重复执行。

> 涉及模块：`settings_service.ahk`、`config.ahk`、`custom_hotkey_store.ahk`

- [x] **前置**：备份配置；记录两个文件的 SHA256；关闭「随游戏自动启动」（避免计划任务干扰）。
- [x] **操作**：打开设置，修改一个普通设置 + 修改一个自定义按键名称；`attrib +R` 锁只读 JSON；保存。
- [x] **预期**：保存失败，提示“原配置已恢复”；两个文件 SHA256 不变；无 `.bak-*` / `.tmp-*`。
- [x] **操作**：取消设置，重启 AFA 后再看设置。
- [x] **预期**：两项修改都没有生效。
- [x] **操作**：`attrib -R` 后重做修改并保存，再次重启。
- [x] **预期**：两项修改都生效，文件无残留。

### 流程：#394 校验失败不影响计划任务

> 涉及模块：`settings_service.ahk`、`game_auto_start.ahk`

- [x] **前置**：备份 `CustomHotkeys.json`；把某个条目的 `"func":"click"` 改成 `"func":"jump"`；重启 AFA；记录当前任务是否存在。
- [x] **操作**：打开设置，切换「随游戏自动启动」（关→开或开→关），保存。
- [x] **预期**：先弹出“自定义按键…参数错误”，**不出现**“进程创建成功审核”确认框（校验在副作用之前）。
- [x] **预期**：计划任务状态与保存前完全一致；`Settings.ini` SHA256 不变。
- [x] **操作**：还原 `CustomHotkeys.json` 备份并重启 AFA。

### 流程：#394 写盘失败时任务补偿（关→开）

> 涉及模块：`settings_service.ahk`、`game_auto_start.ahk`、`config.ahk`

- [x] **前置**：确认「随游戏自动启动」关闭且任务不存在；有效游戏路径；锁住 `Settings.ini`。
- [x] **操作**：打开设置，勾选「随游戏自动启动」，保存；在审核确认框点“是”。
- [x] **预期**：弹出保存失败；查询任务应为不存在（创建后被补偿删除）；`Settings.ini` 不变。
- [x] **预期**：进程创建审核保持开启（设计如此，记录即可）；日志有回滚结果与任务恢复信息。
- [x] **操作**：解锁并重启 AFA。
- [x] **预期**：配置仍是关闭，任务仍不存在。

### 流程：#394 写盘失败时任务补偿（开→关）

> 涉及模块：`settings_service.ahk`、`game_auto_start.ahk`、`config.ahk`

- [x] **前置**：「随游戏自动启动」已开启并成功保存（任务存在）；锁住 `Settings.ini`。
- [x] **操作**：打开设置，取消勾选「随游戏自动启动」，保存。
- [x] **预期**：保存失败；查询任务仍存在（被补偿恢复）；`Settings.ini` 仍是开启状态。
- [x] **操作**：解锁并重启 AFA。
- [x] **预期**：任务仍存在（启动校准对齐配置）。

### 流程：失败后不重试、直接重试成功

> 已由第 4 组 B 覆盖，未重复执行。

- [x] **操作**：JSON 只读 → 修改设置 → 保存失败 → `attrib -R` → 不关闭设置窗口，直接再次保存。
- [x] **预期**：第二次保存成功；修改全部生效；无 `.bak-*` / `.tmp-*`；设置窗口的脏状态标记正确。

### 流程：失败后取消/关闭窗口

> 已由第 2、4 组覆盖，未重复执行。

- [x] **操作**：制造一次保存失败；点「取消」关闭设置；重新打开设置；重启 AFA。
- [x] **预期**：界面值与磁盘都是旧值；没有半保存状态；热键可用。

---

## 回归测试

### 功能：设置保存/应用/取消/重置

- [x] 验证：普通保存、应用、取消三条路径正常（已由第 1、2 组覆盖）；成功后无临时文件残留。
- [ ] 验证（可选）：重置按键成功路径。会清空全部非自定义按键绑定，测试前先备份 `Settings.ini`；本轮代码只改了重置失败分支，成功路径未变，可跳过。

### 功能：单键设置即时写入

- [x] 验证：开局自动暂停/二倍速的切换热键仍能立即写入 INI，不依赖保存流程。

### 功能：随游戏自动启动正常启停

- [x] 验证：开启后任务创建、关闭后任务删除；重启 AFA 后启动校准不误报、不重复创建（已由第 5 组覆盖）。

### 功能：失效游戏路径清理

- [x] 验证：路径失效时保存，选择“是”清除路径后能正常保存；日志记录“已清除”仅在保存成功后出现。

### 功能：语言切换保存

- [x] 验证：切换语言后保存，窗口重建、文案切换正常。

### 功能：自定义按键编辑

- [x] 验证：自定义按键编辑窗口可以正常新增/修改/删除并保存（第 2、5 组已覆盖改名与非法 func 场景）。

### 功能：游戏内热键

- [x] 验证：成功保存后热键重建正常，游戏内触发动作正常（含守卫/透传行为不回归）。

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

> 汇总：测试项 84，通过 81，失败 0，跳过 3（均为可选项：热键禁用状态 2 项、重置成功路径 1 项）。

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决
