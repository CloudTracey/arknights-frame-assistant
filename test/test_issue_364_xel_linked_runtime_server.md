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

- [x] **操作**：打开 AFA 设置 →「启动与退出」标签页，查看「当前运行客户端」
- [x] **预期**：游戏运行中时显示 `国服 (pid=…, hwnd=…)` 或 `哔哩哔哩服 (pid=…, hwnd=…)`；显示的区服与实际启动的客户端一致，不再出现两者互换

### 功能点：托盘区服名

- [x] **操作**：游戏前台时把鼠标悬停在 AFA 托盘图标上
- [x] **预期**：提示文本中的区服名与当前实际客户端一致（官服显示「国服」、B服显示「哔哩哔哩服」）

---

## 集成测试

### 流程：官服运行目录识别（issue #364 原始场景，**核心用例**）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`GuiManager`
>
> ⚠️ 本流程**只在「物理安装是 B服」的机器上成立**：此时官服作为非基准渠道，才会生成
> `...\<B服目录>\.xel-linked-runtime\...\Official\Arknights.exe` 这条带污染祖先目录的路径 ——
> 也就是本 bug 的触发条件。若本机物理安装是官服（官服直接跑物理 exe、不生成运行目录），
> 本流程无法复现，其识别结论改由「B服运行目录识别」流程 + 下列回归项覆盖。

- [ ] **前置**：XelLauncher 已开启「硬链接共享运行环境」；物理安装（Shared Root）为**官服**
      （本机布局示例：`F:\Program Files\Arknights bilibili\games\Arknights Game\`，
      注意启动器根目录名含 "Arknights bilibili" 正是本 bug 的触发条件）
- [ ] **前置**：用 XelLauncher 启动一次**官服**，确认游戏进程路径形如
      `...\.xel-linked-runtime\Arknights\<24位hex>\Official\Arknights.exe`
      （可在「任务管理器 → 详细信息 → 右键列头 → 添加“命令行/路径”」中核对）
- [ ] **操作**：打开 AFA 设置 →「启动与退出」→ 点击「识别游戏路径」
- [ ] **预期**：「当前运行客户端」显示 **国服**（修复前此处显示「哔哩哔哩服」）
- [x] **预期**：「已识别区服路径」中 `CN:` 指向该 `.xel-linked-runtime\…\Official\Arknights.exe` 路径
- [x] **操作**：查看日志 `%AppData%\ArknightsFrameAssistant\PC\logs\afa-*.log`
- [x] **预期**：出现 `绑定目标窗口 … serverId=CN exe=…\Official\Arknights.exe` 与
      `识别到 CN 游戏路径：…\Official\Arknights.exe`，**不再**出现该路径被判为 `serverId=BILI`
- [ ] **操作**：查看 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini` 的 `[Main]`
- [x] **预期**：`GamePathCN` 为该运行目录路径；官服运行目录**没有**被写进 `GamePathBILI`

### 流程：B服运行目录识别（反向用例）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`

- [x] **前置**：保持硬链接开启，用 XelLauncher 启动一次 **B服**
- [x] **操作**：在 AFA 设置中点击「识别游戏路径」
- [x] **预期**：「当前运行客户端」显示 **哔哩哔哩服**；`GamePathBILI` 指向
      `…\.xel-linked-runtime\…\Bilibili\Arknights.exe`（或该机实际的 B服路径）
- [x] **预期**：该 B服运行目录**没有**被写进 `GamePathCN`

### 流程：识别结果跨启动稳定（路径不漂移验证）

> 涉及模块：`ServerProfile`、`Config`

- [x] **前置**：完成上面两条流程，记录「已识别区服路径」中显示的完整路径
- [x] **操作**：完全退出 AFA 与游戏，重新用 XelLauncher 启动同一个服，再打开 AFA 并点「识别游戏路径」
- [x] **预期**：显示路径与上次**完全一致**（哈希段不变）；「当前运行客户端」区服名一致
- [x] **预期**：不弹出「路径不存在」提示，`Settings.ini` 中的路径未被清空重写

### 流程：传统切服（未开硬链接）不受影响

> 涉及模块：`ServerProfile`、`GameClientRegistry`
> ⚠️ **已知限制（非本次改动引入，2026-09-15 实机确认）**：传统切服模式下两个服是从**同一个物理
> 路径**启动的（XelLauncher 原地覆盖渠道差异文件），该路径只含官服目录特征 `Arknights Game`，
> 因此 `FromExePath` 必然返回 CN —— 而 `app.info`（两服同为 HyperGryph/Arknights）与注册表根
> （两服同根）都无法区分渠道。`ServerProfile` 按“安装位置”识别，路径不含渠道信息时无从判定，
> 故本流程的 B服 一项**当前不成立**。要支持该场景需另做渠道特征探测（实测该目录内 B服 为
> `PCGameSDK.dll` + `BLPlatform64`、官服为 `hgsdk.dll`），涉及热路径 IO，需单独评估后再决定。


- [ ] **前置**：在 XelLauncher 中**关闭**硬链接（走传统切服：在同一目录里覆盖渠道差异文件）
- [ ] **操作**：分别启动官服与 B服，各自在 AFA 设置里点「识别游戏路径」
- [ ] **预期**：官服显示「国服」（实机已确认）；B服 一项已由下方**追加测试**的渠道文件校正修复，复测见该节；路径均为物理安装目录（不含 `.xel-linked-runtime`）

### 流程：换服后 AFA 随游戏自启动

> 涉及模块：`GameAutoStartManager`、`GameLauncher`、`Config`

- [ ] **前置**：AFA 设置中「随明日方舟自动启动AFA」已开启；已按上面流程识别到两个服的路径
- [x] **操作**：完全退出 AFA 与游戏 → 用 XelLauncher 启动**另一个服**（与上次识别的服不同）
- [x] **预期**：AFA 随游戏自动启动（修复前此步失败，需手动打开 AFA）
- [x] **操作**：AFA 启动后查看日志
- [x] **预期**：日志中由本次启动的客户端路径识别出正确区服，没有出现区服互换

### 流程：旧误判残留自愈（升级场景）

> 涉及模块：`Config._ReconcileMisidentifiedPath`、`SettingsService`

- [ ] **前置**：先备份 `%AppData%\ArknightsFrameAssistant\PC\Settings.ini`；确认当前存在误判残留：
      `GamePathBILI` 指向 `.xel-linked-runtime\…\Official\Arknights.exe`
- [x] **操作**：重启 AFA，查看日志
- [x] **预期**：出现 `[Config] 误识别路径已迁移：GamePathBILI -> GamePathCN（路径：…）` —— 实测 17:46:44 命中（注入的残留为 `…\Official\Arknights.exe`）
- [x] **预期**：`Settings.ini` 中该路径从 `GamePathBILI` 移到 `GamePathCN`（若 `GamePathCN` 已有值则原键被清空） —— 实测 `GamePathCN` 已有值时原键被清空，符合说明

##### 异常路径

- [ ] **异常**：AFA 识别到的运行目录在保存时恰好**不存在**（例如刚被 XelLauncher 清理/重建中）→
      **预期**：按既有行为提示「路径不存在」并询问是否清除；确认后该键被清空，不崩溃、不影响其他区服记录
- [ ] **异常**：手动把「游戏路径」框填成运行目录下**非** `Arknights.exe` 的文件（如 `Other.exe`）后保存 →
      **预期**：弹出「游戏路径不正确」并严格拒绝保存（文件名校验先于区服识别，行为与改动前一致）

---

## 追加测试

> 对应更改：**传统切服的渠道文件校正** —— XelLauncher 关闭硬链接时两服共用同一物理目录，
> 切服只就地覆盖渠道差异文件，目录名恒为官服布局。原实现按「安装位置」识别必然判成 CN，
> 现按渠道特征文件校正：`hgsdk.dll` → 国服、`PCGameSDK.dll` + `BLPlatform64` → 哔哩哔哩服；
> 两侧特征都无法确认或同时命中时不猜测，维持目录特征判定。

### 功能点：渠道特征探测（自动验证，已执行）

- [x] **操作**：直接调用 `ServerProfile._DetectDeployedChannel` 与 `FromExePath` 观察判定
- [x] **预期**：官服特征（`hgsdk.dll`）→ `CN`；B服特征（`PCGameSDK.dll` + `BLPlatform64`）→ `BILI`
      —— 已在实机以目录联接镜像验证：官服目录原样 → `CN`；临时换成 B服 特征 → `BILI`（标记已还原）
- [x] **预期**：硬链接运行目录判定不受影响：`…\Official\` → `CN`、`…\Bilibili\` → `BILI`（同批验证通过）

### 流程：传统切服下识别为实际运行的渠道（**需实机复测**）

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`Config`

- [x] **前置**：在 XelLauncher 中**关闭**硬链接并切到 **B服**（物理安装目录内应为 B服 渠道文件：
      存在 `PCGameSDK.dll` 与 `BLPlatform64\`、不存在 `hgsdk.dll`）
- [x] **操作**：启动游戏，在 AFA 设置中点击「识别游戏路径」
- [x] **预期**：「当前运行客户端」显示 **哔哩哔哩服**（修复前显示「国服」）
- [ ] **预期**：`Settings.ini` 中该物理路径写入 `GamePathBILI`、`GamePathCN` 被清空
- [x] **操作**：切回**官服**并重新启动游戏后再次点「识别游戏路径」
- [x] **预期**：显示回 **国服** —— 实测 17:42:55 该物理路径绑定 `serverId=CN`（`GamePathCN` 已写入；`GamePathBILI` 仍在但内容正确，见下方问题记录）
- [ ] **操作**：查看日志
- [x] **预期**：出现 `[GameKeys] 前台区服切换：BILI` / `CN`，与实际运行的渠道一致 —— 实测 17:42:05 路径判为 BILI、17:42:55 判为 CN、17:43:32 运行目录判为 BILI

##### 异常路径（需实机复测）

- [x] **异常**：目录内渠道特征文件**都不存在**（游戏文件不完整）→
      **预期**：不猜测，回落目录特征判定（显示「国服」），不报错、不影响其他区服记录 —— 实测夹具（无任何渠道特征文件）→ `CN source=directory_hint`
- [x] **异常**：硬链接运行目录若被人为塞入另一渠道的特征文件 →
      **预期**：仍以渠道段目录名为准（运行目录判定优先于渠道文件），显示不变

---

## 回归测试

### 功能：非 XelLauncher 的物理安装识别

- [x] 验证：直接启动物理安装的官服（`…\games\Arknights Game\Arknights.exe` 或 `…\games\Arknights\Arknights.exe`），「识别游戏路径」显示「国服」，`GamePathCN` 正确 —— 实测 `E:\Hypergryph Launcher\games\Arknights Game\` 判为 CN
- [x] 验证：直接启动物理安装的 B服（`…\Arknights bilibili\games\Arknights\Arknights.exe`），显示「哔哩哔哩服」，`GamePathBILI` 正确
- [ ] 验证：路径均为物理安装目录，**不含** `.xel-linked-runtime`（确认改动未波及普通路径）

### 功能：其他区服识别与展示

- [x] 验证：JP/KR/EN/繁中服（若本机安装）识别结论不变；「已识别区服路径」仍按 `CN, BILI, TC, JP, KR, EN` 顺序展示 —— 实测 TC 行指向 `E:\GRYPHLINK\games\Arknights_TC\`（JP/KR/EN 本机未安装，未能实测）

### 功能：按键映射与热键

- [ ] 验证：官服 ↔ B服 切换前台后，热键功能正常（两服共享注册表根，改动不影响读键）
- [x] 验证：前台区服切换时日志出现 `[GameKeys] 前台区服切换：CN` / `BILI`，且按键映射日志正常输出

### 功能：诊断导出

- [x] 验证：导出诊断包后，`diagnostics.txt` 中 `Client1=…` 的 serverId 与实际客户端一致；`RegistryRootCN` 与 `RegistryRootBILI` 仍相同 —— 本项改为**直读同源字段**核实：`Client1` 的 serverId 见日志 `serverId=BILI` 与实际一致；`HKCU\Software\HyperGryph\Arknights` 存在（CN/BILI 同根，符合预期），未实际导出压缩包

---

## 测试结果

- [ ] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：传统切服下同一物理路径被同时记入 GamePathCN 与 GamePathBILI

- [ ] 已解决
- **现象**：17:42 会话日志中，物理安装路径 `E:\Hypergryph Launcher\games\Arknights Game\Arknights.exe`
  先被「运行中客户端识别」写入 `GamePathBILI`（当时目录内为 B服 渠道文件，判定 BILI 正确），
  随后被「目录扫描」写入 `GamePathCN`（该路径同时满足官服安装布局）。两个键指向同一路径。
- **影响**：随游戏自启任务的触发器会多出指向同一路径的冗余条目；硬链接模式下该条目指向的
  其实是另一个渠道的安装目录。不影响识别正确性，属记录冗余。
- **说明**：该行为在本次改动前即存在（两个键之间没有互斥校验），非本次引入。

### 问题2：[问题描述]
- [ ] 已解决
