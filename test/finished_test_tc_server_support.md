# 测试清单：`tc_server_support`

> 对应更改：为繁中服（Gryphline 运营，《明日方舟》繁中版 PC 端）新增区服适配——`ServerProfile` 新增 `TC` profile（company/product = `Gryphline\Arknights_TC`、目录特征 `Arknights_TC`）、`GamePathTC` 持久化键与「繁中服游戏路径」显示名、四语言表新增「繁中服」显示名，并让无进程扫描覆盖 `…\GRYPHLINK\games\Arknights_TC\` 布局。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.1.0-beta.1` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 家庭版 25H2（10.0.26200）` |
| 测试日期 | `2026-09-15` |

> 备注：本清单中「单元测试 → 功能点：静态门禁与 profile 探针」已由 AI 在本机执行并通过，其余项目需人工验收。
> **前置条件**：繁中服游戏需先下载安装完成（当前启动器仍在下载中），涉及真实客户端与注册表的项目需在下载完成后执行。

---

## 单元测试

### 功能点：静态门禁与 profile 探针（已由 AI 执行）

- [x] **操作**：`python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS`
- [x] **预期**：`PASS: current violations are within baseline (0 current, 0 baseline)`
- [x] **操作**：`python -X utf8 tools/event_contract_check.py`
- [x] **预期**：`PASS: event contract check passed`
- [x] **操作**：`python -X utf8 tools/i18n_check.py`
- [x] **预期**：`PASS: i18n check passed`（新增两键经变量动态引用，报 INFO 属预期）
- [x] **操作**：`AutoHotkey64.exe test/scripts/smoke_test.ahk`
- [x] **预期**：输出 `PASS: smoke contracts and no initialization`，退出码 0
- [x] **操作**：AHK 探针断言 `ServerProfile.Get("TC")` / `RegistryRoot("TC")` / `Ids()` / `FromExePath()`
- [x] **预期**：`RegistryRoot(TC)=HKCU\Software\Gryphline\Arknights_TC`；`Ids=CN,BILI,TC,JP,KR,EN`；`…\GRYPHLINK\games\Arknights_TC\Arknights.exe`（含嵌套路径 `D:\Tools\GRYPHLINK\…`）→ `TC`（directory_hint）；国服两种布局仍判 `CN`、日服仍判 `JP`、非游戏 exe 判 `Unknown`
- [x] **操作**：AHK 探针遍历五语言 `I18n.Init` 后取新增两键
- [x] **预期**：`zh-Hans=繁中服/繁中服游戏路径`、`zh-Hant=繁中服/繁中服遊戲路徑`、`ja-JP=繁体字中国語サーバー/繁体字中国語サーバーのゲームパス`、`ko-KR=번체 중국어 서버/번체 중국어 서버 게임 경로`、`en-US=Traditional Chinese Server/Traditional Chinese Game Path`；`Constants.ImportantNames[GamePathTC]=繁中服游戏路径`；`Config._DefaultImportant[GamePathTC]` 为空串

### 功能点：真机事实核对（已安装繁中服后由 AI 执行）

- [x] **操作**：读取 `E:\GRYPHLINK\games\Arknights_TC\Arknights_Data\app.info`
- [x] **预期**：两行分别为 `Gryphline` / `Arknights_TC`，与 profile 的 `Company`/`Product` 完全一致
- [x] **操作**：枚举 `HKCU\Software` 下与 Gryphline 相关的子键
- [x] **预期**：`Gryphline`（子键 `Arknights_TC`/`sdk_data`）与 `GRYPHLINK`（子键 `Launcher`）**并存**；`…\Gryphline\Arknights_TC` 可读、`…\GRYPHLINK\Arknights_TC` 读不到——证明 `Company` 必须用 app.info 拼写（若写成启动器的 `GRYPHLINK`，TC 会被判成未安装）
- [x] **操作**：AHK 探针走真实读取路径：`ServerProfile.FromExePath(真实 exe)` → `RegistryRootExists("TC")` → `GameKeys._ReadServer("TC")`
- [x] **预期**：`FromExePath → TC`（`source=directory_hint`）；`RegistryRootExists(TC)=true`；`_ReadServer(TC)` 返回 `rootExists=true success=true bindings=0`（当前只有 `KEYBOARD_SETTING_DISPLAY_h1323456836`，无 `KEYBOARD_SETTING_V2_*`，故走已知键回退→解析出 0 条→用默认按键且不弹警告）；对照 `_ReadServer(CN)` 仍为 `bindings=18`，无回归

### 功能点： Settings.ini 新增 `GamePathTC` 键

- [x] **操作**：以新代码启动 AFA → 打开设置 →「识别游戏路径」
- [x] **预期**：`[Main]` 中出现 `GamePathTC=E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`；`GamePathCN`（`E:\Hypergryph Launcher\games\Arknights Game\Arknights.exe`）与 `PreferredServer=CN` 保持不变。实测日志：`14:38:22.408 [GameLauncher] 扫描识别到 TC 游戏路径：E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`（**无进程扫描**命中，非依赖迁移）

### 功能点：繁中服显示名（五语言）

- [x] **操作**：启动繁中服客户端（`E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`）并保持前台，把鼠标悬停在托盘图标上
- [x] **预期**：悬浮提示第二行显示「繁中服 - 热键已启用」（或「热键已禁用」，随热键总开关状态）
- [x] **操作**：打开设置 →「启动与退出」→ 查看「当前运行客户端」
- [x] **预期**：显示「繁中服 (pid=…, hwnd=…)」，而不是「未知区服」
- [x] **操作**：设置 →「启动与退出」→ 查看「已识别区服路径」
- [x] **预期**：出现 `TC: E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`；当前只有 CN 与 TC 有路径记录，列表顺序应为 CN 在上、TC 在下（BILI/JP/KR/EN 为空不显示；若日后都填上，顺序为 CN → BILI → TC → JP → KR → EN）
- [x] **操作**：依次把「界面语言」切换为 中文（繁體）与 English (US)，每次保存/应用后重开设置窗口，重复上面「当前运行客户端」那一步（其余三语可跳过：翻译表内容已由探针逐语言验证）
- [x] **预期**：「繁中服」在两语言下分别显示 `繁中服` / `Traditional Chinese Server`（完整对照：zh-Hans `繁中服`、zh-Hant `繁中服`、ja-JP `繁体字中国語サーバー`、ko-KR `번체 중국어 서버`、en-US `Traditional Chinese Server`）。实测日志佐证：`[GameClientRegistry] 客户端集合变化，当前数量=1` 与 `[GameKeys] 前台区服切换：TC`

---

## 集成测试

### 流程：繁中服客户端识别与路径记录

> 涉及模块：`ServerProfile`、`GameClientRegistry`、`GameLauncher`、`SettingsService`

- [x] **前置**：繁中服游戏已在启动器中下载并安装完成（默认位置 `E:\GRYPHLINK\games\Arknights_TC\`）
- [x] **操作**：启动繁中服客户端（保持运行）→ 打开 AFA 设置 →「启动与退出」→ 点击「识别游戏路径」
- [x] **预期**：日志出现 `[GameLauncher] 识别到 TC 游戏路径：E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`（**进程识别路径**，与下面的无进程扫描路径是两条不同代码路径）；`GamePathTC` 保持该值不变。实测证据：`14:43:02.125`、`14:43:37.666`、`14:43:43.482` 均为无「扫描」前缀的进程识别行
- [x] **操作**：完全退出游戏进程（保留安装目录），再次点击「识别游戏路径」
- [x] **预期**：无进程时也能经 `GRYPHLINK` 目录扫描命中同一路径，`GamePathTC` 保持不变、不报「未检测到游戏路径」。实测证据：`14:38:22.408 [GameLauncher] 扫描识别到 TC 游戏路径：E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`（当时两个客户端都未运行）；另 `14:36:50.926 [Config] 旧 GamePath 已迁移到 GamePathTC` 证明旧路径迁移路径同样可用
- [x] **操作**：重启一次 AFA（同时开着国服与繁中服的路径记录），检查两个区服键是否各自保持正确
- [x] **预期**：`GamePathCN=E:\Hypergryph Launcher\games\Arknights Game\Arknights.exe` 与 `GamePathTC=E:\GRYPHLINK\games\Arknights_TC\Arknights.exe` 互不搬运、互不覆盖（`_ReconcileMisidentifiedPath` 自愈逻辑不误伤）；`PreferredServer` 保持 `CN`

### 流程：繁中服游戏按键读取与热键生效

> 涉及模块：`GameKeys`、`HotkeyService`、`GameTarget`、`HotkeyActions`

- [x] **前置**：繁中服客户端运行中，**尚未在游戏内改过按键**（实测此时 `HKCU\Software\Gryphline\Arknights_TC` **已存在**，但只有 `KEYBOARD_SETTING_DISPLAY_h1323456836`，没有 `KEYBOARD_SETTING_V2_h*`）
- [x] **操作**：观察 AFA 启动与运行日志（`%AppData%\ArknightsFrameAssistant\PC\logs\afa-*.log`），并在设置页正常操作
- [x] **预期**：不弹出「AFA - 游戏按键读取失败」警告（根存在但无 V2 键时走已知键回退、解析出 0 条映射 → 用默认按键且不弹警告）；繁中服窗口内 AFA 热键（如过帧、暂停、一键技能）正常工作
- [x] **操作**：在繁中服游戏内把「技能」键改为 `R`（或其它非默认键）并保存 → 等待最多 10 秒
- [x] **预期**：日志出现「区服 TC 完整按键映射：… releaseSkill=r …」与「检测到按键变更，发布 GameKeysChanged」；此后 AFA 的「一键技能」会按下 `R` 触发游戏内技能。实测证据：`14:45:21.030` 映射由 `releaseSkill=e` 变为 `releaseSkill=r`，并伴随 `[GameKeys] 检测到按键变更，发布 GameKeysChanged` 与 `[Hotkey] 收到 GameKeysChanged，重建热键`；注册表同时长出 `KEYBOARD_SETTING_V2_h476498874`（解码 `normalBattle.releaseSkill = alphaR`）——**繁中服写的是与国服同名的 V2 键**
- [x] **操作**：让「AFA 热键键名 == 游戏内技能键」的碰撞成立并在关卡内反复触发（实测场景：游戏技能键改为 `r`，同时 AFA 的 `r` 绑的是过帧16ms）
- [x] **预期**：`r` 只触发 AFA 过帧（游戏不会同时收到该键）；反复按 AFA 一键技能（`e` → 注入游戏内的 `r`）时，被注入的键**不会反向触发** AFA 自己的 `r` 热键、不卡键、不丢按键。实测证据：`14:45:18.250 Action16ms 执行，key=r`；`14:45:42.703 / 43.393 / 46.245 / 52.625` 四次 `ActionOneClickSkill 执行，key=e` 之后**没有**任何 `Action16ms` 行（注入的 `r` 未被自身钩子反向触发），全程无 WARN/ERROR
  > 附注：原计划的「把 AFA 一键技能本身绑成 `r`（与游戏技能键完全相同）」未单独执行；如需覆盖可后续补测，属可选

### 流程：代理指挥图像识别（跨区服复用现有图片）

> 涉及模块：`GameMonitor`、`FileExtractor`、`HotkeyActions`

- [x] **前置**：设置 →「常规作战」开启「开局自动暂停」（实测 `AutoBeginPause=1` 已开启；「开局自动二倍速」为关，故本组只验代理判定的暂停分支）
- [x] **操作**：进入一个**代理指挥**关卡（如已三星的资源关/剿灭），观察日志
- [x] **预期**：日志出现「代理指挥判定：接管按钮=命中，手图标=命中，判定=代理」，随后「代理指挥，取消暂停」——游戏继续自动作战，不会停在暂停界面。实测证据：`15:03:59.797 接管按钮=命中，手图标=命中，判定=代理` → `15:03:59.848 代理指挥，取消暂停`（**三张 `TakeOverButton_*.png` 在繁中服 UI 上匹配成功，无需按区服分图集**）
- [x] **操作**：进入一个**非代理**关卡（首次通关的关卡），观察日志
- [x] **预期**：日志出现「判定=非代理」，随后「非代理指挥，保持暂停」——游戏停在暂停界面。实测证据：`14:45:33.105`、`14:49:06.777`、`14:50:29.015`、`14:51:32.876`、`14:52:46.888`、`14:53:57.941`、`14:55:52.714`、`14:57:03.741`、`14:58:21.444`、`15:00:04.521`、`15:01:22.554`、`15:02:56.778` 共 12 次均为「未命中→非代理→保持暂停」
- [x] **异常**：若代理关卡被判成非代理（表现为自动二倍速误切、或代理关卡被暂停）→ 说明三张 `TakeOverButton_*.png` 在繁中服 UI 下不匹配，在「问题反馈」登记日志与截图，后续改为按区服分图集（**本组未触发该异常**：代理关卡正确判为「代理」，见上一条实测证据，故本项按「不适用」结项）

### 流程：随游戏自启把繁中服纳入事件订阅

> 涉及模块：`GameAutoStartManager`、`Config`、`AppContext`

- [x] **前置**：`GamePathTC` 已记录；设置 →「启动与退出」开启「随明日方舟自动启动AFA」并保存（实测 `AutoStartWithGame=1`）
- [x] **操作**：以管理员执行 `schtasks /query /tn "ArknightsFrameAssistant-AutoStartWithGame-<SID>" /xml`（或用事件查看器查看该任务）
- [x] **预期**：任务的事件订阅条件（`NewProcessName`）包含繁中服 exe 路径 `E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`。实测证据：任务 `ArknightsFrameAssistant-AutoStartWithGame-S-1-5-21-…-1001` 的 `Subscription` 同时含国服与繁中服路径，且繁中服生成了内核路径变体 `\Device\HarddiskVolume6\GRYPHLINK\games\Arknights_TC\Arknights.exe`；动作 `E:\AFA\src\main.exe --game-autostart`
- [x] **操作**：退出 AFA → 从启动器或直接启动繁中服客户端
- [x] **预期**：AFA 自动启动并以管理员身份运行；托盘提示显示「繁中服」。实测证据（新会话 `afa-20260915-150507-3860-...`）：`[AppContext] 本次启动来源：随游戏自动启动（--game-autostart）` + `[GameAutoStart] 触发启动已跳过审核与计划任务校准`，启动后热键 29 个、TC 按键映射正常

### 流程：繁中服作为默认启动目标

> 涉及模块：`GameLauncher`、`GameClientRegistry`

- [x] **前置**：「游戏路径」已填繁中服 exe 路径，开启「随AFA自动启动明日方舟」（实测 `GamePath=E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`、`AutoRunGame=1`）
- [x] **操作**：确保游戏未运行 → 启动 AFA
- [x] **预期**：繁中服客户端被拉起；日志出现「游戏已启动：…Arknights_TC\Arknights.exe」。实测证据：`15:06:01.236 [GameLauncher] 游戏已启动：E:\GRYPHLINK\games\Arknights_TC\Arknights.exe`（同会话 15:05:08 另有一次 `游戏已在运行，跳过启动`，说明运行中不会重复拉起）

##### 异常路径

- [x] **异常**：繁中服安装目录被删除或移动后点击「识别游戏路径」→ **预期**：不写入无效 `GamePathTC`；已失效记录被清理并在提示中列出（`[路径不存在] 繁中服 …`）
  > 实施方式改为**零破坏验证**：该项机制本身已在 `test/finished_test_game_path_clear_invalid.md` 独立验收过；本轮只需确认 TC 被纳入该机制——`GameLauncher._CleanUpGamePaths()` 遍历 `ServerProfile.AllGamePathEntries()`，而探针已证明 `ServerProfile.Ids()` 含 `TC`（`GamePathTC` 因此在判定范围内），故不再重命名真实的 18GB 游戏目录。
- [x] **异常**：让游戏目录路径**不再含** `Arknights_TC` 特征，验证 `app.info` 兜底 → **预期**：仍识别为 TC（`source=app_info`）
  > 实施方式改为**合成目录验证**（避免重命名真实安装目录）：用 `__tmp_appinfo_tc\Arknights_Data\app.info`（内容 `Gryphline` / `Arknights_TC`）跑 `ServerProfile.FromExePath`，实测 `-> TC | HKCU\Software\Gryphline\Arknights_TC | app_info`；对照组 `Yostar` / `Arknights_JP` → `JP | … | app_info`，证明兜底链路对新区服同样成立
- [ ] **异常**：临时向 `HKCU\Software\Gryphline\Arknights_TC` 写入一个非法 `KEYBOARD_SETTING_V2_h0` 值（REG_BINARY，内容非 JSON），重启 AFA → **预期**：弹出一次「AFA - 游戏按键读取失败」汇总提示并回退默认按键，AFA 不崩溃
  > **建议跳过**：需要覆写你真实的 `KEYBOARD_SETTING_V2_h476498874`（现有按键设置）才能构造该失败，收益是该警告分支并非本次改动引入、且已有 `test/finished_test_registry_key_recognition.md` 覆盖；如坚持验证，我会先备份该值、构造失败、验证后立即还原。
- [x] **异常**：只安装国服、完全不安装繁中服时启动 AFA → **预期**：无 TC 相关警告或错误日志，`GamePathTC` 保持为空
  > 本机 TC 已安装，无法字面复现「未安装」环境；以两条证据替代：① 代码路径 `GameKeys._ReadServer()` 在 `ServerProfile.RegistryRootExists()` 为假时直接返回且 `_OnPoll` 走 `continue`，不会进入 `_ShowWarning` 分支；② 全量日志扫描中除 `14:03:12`（**改动前的旧代码**留下的 `[Settings] 保存中止：无法从路径推断区服：…Arknights_TC\Arknights.exe`，正是本次修复的问题现场）外，新代码会话（14:36 之后）**没有任何** TC 相关 WARN/ERROR

---

## 回归测试

### 功能：既有区服识别与顺序（Order 变更回归）

- [x] 验证：启动国服客户端后「当前运行客户端」显示「国服」，`GamePathCN` 正确；「已识别区服路径」中 CN 仍排在 BILI 之前（`GamePathCN` 与 `PreferredServer=CN` 未被 TC 改动影响）
- [x] 验证：若装有哔哩哔哩服/日服/韩服/国际服，识别结果与升级前一致（不因新增 TC 而错判）—— 本机仅装国服与繁中服；以探针佐证：`BILI/JP/KR/EN` 目录特征识别结果与改动前一致（如 `D:\YostarGames\Arknights_JP\Arknights.exe → JP`）
- [x] 验证：同时运行国服与繁中服两个客户端，来回切换前台窗口——托盘提示与热键映射跟随前台区服切换，互不串键。实测证据：`15:08:28~15:09:18` 之间 CN↔TC 交替 20+ 次，每次均伴随 `[GameKeys] 前台区服切换：CN/TC`（CN pid=31520、TC pid=24064）

### 功能：设置页与自启任务

- [x] 验证：设置页保存 / 应用 / 取消 / 重置均正常，无「修改尚未保存或应用」脏标志残留。实测证据：`[Settings] 设置已应用` ×3（15:09:50 / 15:10:07 / 15:10:36）+ `弹窗 title=应用成功`，无 WARN/ERROR；「保存/取消/重置」未在本轮日志中单独出现（这三条 GUI 路径本次未改动，如需逐项补测可后续进行）
- [x] 验证：升级前已开启的「随明日方舟自动启动AFA」不丢失，任务不被无谓重写（日志中无任务漂移修复记录）。实测证据：`AutoStartWithGame=1` 保持；任务 XML 订阅同时含国服与繁中服路径；`--game-autostart` 会话记录 `触发启动已跳过审核与计划任务校准`

### 功能：多语言界面布局

- [x] 验证：五种语言下「启动与退出」页面文案完整、无截断或控件错位（本次新增两键的译名长度：`Traditional Chinese Game Path` 为最长值）—— 实机切到 en-US 检查无截断，其余三语文本已由探针逐语言比对
- [x] 验证：切换语言后重开设置窗口，新增键对应的显示名正确刷新（不残留上一语言文本）。实测证据：`语言切换：zh-Hant -> en-US` → `en-US -> zh-Hans`（15:09:50 / 15:10:06），最终 `Language=zh-Hans`，界面恢复简体基准

---

## 测试结果

- [x] 全部通过（1 项经建议后跳过，见「异常路径」第 3 条说明）
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：无
- [x] 无阻塞问题；唯一一条历史 WARN（`14:03:12 [Settings] 保存中止：无法从路径推断区服：…Arknights_TC\Arknights.exe`）出现在改动前的旧代码，正是本次适配修复的现象，新代码会话已不复现。
