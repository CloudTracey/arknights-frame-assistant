# 关键设计：GUI 与主题

> AGENTS.md 参考资料分册。AGENTS.md 只保留必须遵守的铁律，本文件保留完整机制、历史与理由。

## 布局链与几何契约（gui.ahk `_CreateControls`）

手工硬编码布局，控件的 `y+NN` 相对"**前一个控件的底部**"（不是 `Section`）——因此**创建顺序本身就是布局契约**，插行/换序会让后续所有行的位置漂移。

关键数字与规则：

- **列栅格**：绑定的 Edit 固定在 `colX+155`（左列 155 / 右列 `ColWidth`+155 = 515），标签右缘固定 `colX+135` 右对齐、宽出向左延伸。
- **帧率行**标签按**实测宽度**重定宽（`Max(90, 实测宽)` 且 `+2px` 安全余量），右缘仍固定 135——en/ko 等长文案不换行。
- **自动暂停开关 / 二倍速开关**（已迁至「特殊操作」页）：复选框 `x` `GuiXMargin`，行文本左对齐同列，按键 Edit 用 `x+20` 紧随文本右侧（随各语言文本长度自然右移，不再固定列）。
- **关卡守卫开关**：上移占原「开局自动暂停」行位，左缘沿用该行旧列 `auxRowX`(404)，并用 `Min(auxRowX, 708 - 实测宽)` 钳制，防超长文案越出右缘；快捷操作页的「放弃行动」复选框同列同位（`auxRowY` 由 `GuiFrame` 的 y 推出）。
- **特殊操作页**：单列 5 行，首行 `y48`，行距 33；两处「横线 + 文本」分区头与「其他设置」页同款（`x` `GuiXMargin` `w` `GuiWidth-60` `h1 BackgroundBorder Center Section` + `xs+40 y+-9 Center cMuted` 文本，靠 `_SetOverlayZ(txt, 0)` 让文本截断线身）；第二区横线在上一区末行下方 48px。
- **帧率提示语的锚点是「关卡守卫」复选框**（迁移后本行最后一个控件）：其底部决定所有页面的底部基准 `_BottomBaseY`，进而决定窗口高度与底部按钮位置。
- 「游戏路径」行标签上限 `zhW+29`（中文基准宽 +29px），**不得越过 `x131` 分隔线**；各语言的标签/编辑框列位置一致。
- 提示文本右缘固定在内容区右缘 `x690`，宽度不随语言变化（超宽裁剪，须按语言人工验证）。
- 卫戍协议页分两列用 **`Floor` 而非 `Ceil`**：奇数项时右列要比左列**多**一行，否则末行提示语会与左列末行重叠。自定义按键页固定 12 行预建（两列 × 6，AHK 控件无法运行时创建/销毁）。
- 三个标签页末尾各有一行 **零高度的"空白占位"控件**（`y+-10 h0`）：它本身不显示，作用是充当下一行（底部提示语）的定位锚点——**不要当作垃圾代码删除**。同理，行内 `y+NN` 依赖的行序也不能随意调换。
- **标签页设置的两个 Hidden 表单变量（`vTabOrder`/`vHiddenTabs`）必须放在布局链之外**，否则破坏"自定义"页左列 `y+10` 的相对定位。
- 顶部标签创建期按**实际可见数**等分（`LayoutTopTabs()`）而不是固定 `TabWidth`，否则首显前窗口宽度按 `TabWidth × 标签数` 计算会导致顶部溢出、整窗变宽。

## 标签页管理器的重绘与命中规则

- **必须 `Redraw()`**：AHK 是延迟重绘，可见标签数变化后不加会在旧宽度上绘制，出现错位/缺字残影。
- **指示线无条件重设宽度并重绘**——按"宽度未变则跳过"会在标签数变化时留下零宽指示线。
- 位置/尺寸相同就不要 `Move`；可见性相同就不要赋值；`SetFont` 只在颜色与 `TabFontState` 记录不一致时执行——这些都是为了压掉闪烁。`TabFontState` 必须是**空 Map 起步**，保证首次 `_SetTabFontOnce` 总会 `SetFont`（键缺失视为无记录）。
- 眼睛图标码点与"闭眼字形不可用"见 [Segoe MDL2 Assets 图标码点](#segoe-mdl2-assets-图标码点)。
- `RegisterTabManagerMouseHandlers` **须同时监听 `WM_LBUTTONDOWN`(0x0201) 与 `WM_LBUTTONDBLCLK`(0x0203)**：窗口类带 `CS_DBLCLKS` 时双击的第二次按下发 0x0203，只听 0x0201 会漏掉该次点击。
- 行内偏移：拖动手柄 `+9`、标签 `+40`、眼睛图标 `+201`；行的 Z 序为 背景 < 高亮 < 文字与命中控件（只调 Z 序，不动 HWND/位置/尺寸，拖动与眼睛点击依赖它们）。
- 统计可见功能标签数（判断能否隐藏）**须读 `tabItem.Visible`（工作态）而非 `IsTabVisible()`（已应用快照）**，否则未应用时的保护不生效；`MouseGetPos` 返回**物理像素**，行坐标是**逻辑像素**，拖拽换算不可省。

**`_ShowControls` 组成员关系**：自定义按键的 12 行控件**不进** `_ShowControls` 组（行显隐只由 `_RefreshCustomHotkeyRows` 按条目数控制，进组会被全量置可见、切页时闪一下），且该刷新方法**必须受当前标签页门控**——它挂在 `_UpdateTabUI` 末尾对每个标签页都执行，无条件置可见会让行在 `_HideAllControls` 之后又被显示（控件串页）。

## 脏状态与窗口重建

`GuiManager` 维护 `_InitialValues` 快照和 `IsModified` 标志。`CaptureInitialSnapshot()` 在设置加载/保存/应用后保存所有控件当前值，`TrackChange(key)` 在控件变更时将当前值与快照对比，同时将新值同步写入 Config 内存（热键控件和 SwitchHotkey 已由 `KeyBinder.EndChange` 提前写入，`TrackChange` 负责其余控件）。

**语言切换会重建窗口**（`_OnSettingsSaved`/`_OnSettingsApplied` 的 `_LanguageChanged` 分支），该分支必须在 `Rebuild()` 之后同样执行 `SetIsModifiedFalse()` + `CaptureInitialSnapshot()`——否则保存成功后脏标志残留，重开窗口会误报"修改尚未保存或应用"并点亮保存/应用按钮。

**`SettingsChanged` 下发的单键变更必须同步快照**：该事件一律由 `SettingsService.UpdatePersistedValue` 发布（写 INI → 更新内存 → 发事件），即"值已持久化"。若只写回控件而不把 `_InitialValues[key]` 前移到新值，快照会停在窗口打开时的旧值——用户随后**第一次**手动改回旧值恰好与快照相等，`TrackChange` 判为"未修改"，保存/应用不亮（第二次点击才被识别）。修法：`_OnSettingsChanged` = `_ApplySettingsChanged`（写回控件）+ `_SyncInitialValue(key)`（快照对齐）。典型触发者：快捷键切换 `AutoBeginPause`/`AutoBeginSpeed`、自动识别游戏路径写 `GamePath`。

## GUI 脏值对比

`UpdateSaveButtonState()` 根据 `IsModified` 和 `HasHotkeyConflicts` 决定保存/应用按钮状态。`RefreshHotkeyConflicts()` 调用 `HotkeyConflictValidator` 进行增量字体标红（仅更新冲突状态变化的控件，使用 `_PrevConflictedControls` 做 diff）。

`SwitchTab()` 保留内存修改及主题预览；显式取消由 `SettingsService.Cancel()` 重载配置。

**自定义按键页**：行控件命名 `CustomHotkey{i}Key/Gear`（删除功能在编辑窗口内），`TrackChange` 对 `CustomHotkey*Key` 委托 `TrackCustomHotkeysChange`。

新增可修改控件时需在 `CaptureInitialSnapshot` 中添加对应 key，并在控件事件中调用 `TrackChange`。

## 主题生命周期与预览

（`theme.ahk` + `settings_service.ahk`）

`[Main] ThemeMode=auto|light|dark` 默认 auto；`SettingsService.Initialize()` 仅在缺键时原子补回 auto，已有非法值按 auto 读取、正常保存时规范化；INI 行位置不固定，节名必须是 Main。

**规范化单一入口**：规则与合法值集合只在 `Constants.NormalizeThemeMode`/`Constants.ThemeModes`（Config 读写与 Theme 均调用它，base 内不得反向引用 Theme）。

`Theme.Preview` 仅更新显示，保存成功与取消经 `Theme.Confirm` 同步；预览优先于已保存模式，按键重置及切页不结束预览。

**主题随主提交落盘**：`ThemeMode` 与其余设置一起由 `SaveAllToIni()` 提交，不再单独延后；`CustomHotkeys.json` 写入失败时随 Settings.ini 一起回滚，避免主题先于其他设置生效。`Theme.Confirm` 只在整次保存/应用成功后调用。

颜色变化**预览（未保存）时只重绘**，不重建窗口、不重建热键组；保存/应用仍走常规设置流程（`HotkeyService._HandleSettingsSavedOrApplied()` 对任何保存/应用/重置都无条件 `EnableByTab()` 重建热键，与主题是否变化无关）。

### Theme 类 API

`base/theme.ahk` 的 `Theme` 类是配色与窗口资源的唯一 owner：

- `Init()` 读取 `ThemeMode`；`Color(role)` 返回语义色（如 `cError`/`cText`）。
- `Resolve(saved, preview, appsUseLightTheme, highContrast)` 决定实际模式（预览优先于已保存、高对比度优先）；`Normalize()` 是 `Constants.NormalizeThemeMode` 的薄封装。
- 控件经 `Theme.Add(gui, kind, options)` / `Theme.SetFont` 登记；窗口经 `Theme.Attach(gui)` 登记、`Theme.Destroy(gui)` 注销。
- `Preview(mode)` 只更新显示，`Confirm(mode)` 同步已保存模式。
- 标题栏经 `SetWindowAttribute()`（`DwmSetWindowAttribute`）设置，属性版本门槛见 [`docs/win_docs/theme_api_compatibility.md`](../win_docs/theme_api_compatibility.md)。

## 深色绘制与 Win32 边界

（`theme.ahk`）

系统跟随读 `AppsUseLightTheme`，`WM_SETTINGCHANGE`/`WM_THEMECHANGED`/`WM_SYSCOLORCHANGE` 通知用一次性计时器合并，高对比度优先；DWM 必须检查 HRESULT（负值即失败），不能只依赖 try，属性版本门槛、结构体与释放关系见 [`docs/win_docs/theme_api_compatibility.md`](../win_docs/theme_api_compatibility.md)。

Edit 仅接管深色非客户区边框，保留原生光标、选区与滚动；浅色和高对比度交还原生绘制，带滚动条 Edit 保留系统视觉主题。

主窗口保留 `WS_EX_COMPOSITED`：重叠控件必须维护背景→高亮→文字的 Z 序，顶部与左侧强调线、「其他设置」分类的横线标题对（`sep*` + `sep*Txt`）与状态栏指示块（`SepLine`，与末尾 1×1 空白占位重叠）经 `_SetOverlayZ` 置顶；透明 Text 的 `BackgroundTrans` 与 `WS_EX_TRANSPARENT` 配合。窗口标题栏仅由 Theme 管理。

## 主题日志与验证

Theme 生命周期与低频模式变化使用现有 Logger；绘制故障按操作去重并延后写入（`_WarnOnce` 入队 + 一次性定时器 flush），不逐帧或逐次鼠标移动记录。主题逻辑改动须验证 `Theme.Resolve`/`Normalize` 与 `Constants.NormalizeThemeMode` 的判定一致（纯逻辑，不建窗、不读注册表），通过不等同于 GUI 验收。

`SafeWinGetClientPos(&ww,&wh)` 窗口不存在时返回 false（不抛 `TargetError`）；`SafePixelSearch`/`SafeImageSearch` 把 `PixelSearch`/`ImageSearch` 内部的 GDI `OSError`（搜索区域落在可见桌面外、副屏拔掉、窗口移出屏幕、锁屏/RDP 断开）按"未命中"处理并 **60 秒节流**记 Warn——失败时单次轮询会产生十余个搜索调用，逐次记 Warn 会刷屏、并反复把最近日志抄进 critical 文件。`ImageSearch` 在 AHK v2 无独立 Options 参数，容差/缩放前缀拼在 `ImageFile` 字符串内（如 `"*90 " path`），`ValueError`（图库加载失败）同样按未命中处理，资源缺失不应弹框打断监控。

**抓屏必须走屏幕 DC**：`SafeCaptureClientRect()` 用 `GetDC(NULL)` + 客户区屏幕坐标 `BitBlt`，**不能用 `GetDC(hwnd)`**——DX/Unity 画面不经过窗口 GDI DC，窗口 DC 抓到的是黑屏或旧帧（`PixelSearch` 同为屏幕合成路径）。返回 BGRA 4 字节、自顶向下位图；调用方需自行切到 per-monitor DPI aware（与 `SafeWinGetClientPos` 同坐标系），并保证目标窗口即 `GameTarget`、客户区 `(0,0)` 对应位图 `(0,0)`；失败返回 false。

## key_bind.ahk 的 WM_LBUTTONDOWN 处理

`OnMessage(0x0201, WM_LBUTTONDOWN)` 是进程级回调，会在所有 GUI 的 Edit 控件点击时触发。为防止非设置窗口的 Edit 控件误触发按键录制，回调开头有父窗口检查：`if (KeyBinder.ControlObj.Gui.Hwnd != GuiManager.MainGui.Hwnd) return`。

新增 Edit 控件且不需要按键录制功能时，确保其父窗口不是 `GuiManager.MainGui`。点击非 Edit 区域时自动聚焦取消按钮（`GuiManager.FocusCancelButton()`），取消普通 Edit 控件的选中状态。

## Alt+F4 始终退出

通过 `GuiManager.Start()` 中的 `HotIf` + `Hotkey("!F4", ...)` 动态注册拦截设置窗口的 Alt+F4，始终彻底退出 AFA。标题栏 X 按钮仍由 `ExitOnWindowClose` 设置控制（关闭窗口 or 退出）。

## AHK v2 GUI 布局要点

`xs`/`ys` 引用**最近**的 `Section`（叠加布局中会追到前一个分类的 Section 导致偏移，每组首控件应用绝对坐标如 `x160 y45`）。Text 的 `Center` 仅水平居中，文字要填满控件需去掉固定高度自适应（`hp`）而非依赖 Center。

## 自定义按键编辑窗口（custom_key_editor.ahk）

独立顶层 `Gui`（**不是** `MainGui`）——`KeyBinder` 的 WM_LBUTTONDOWN 父窗口检查据此自动豁免按键录制。单编辑窗口：再次打开直接切换目标行，未保存的修改丢弃。

**打开期间常驻一个 8ms 拾取轮询**（`SetTimer` + `ToolTip` 显示光标处 0-1 比例坐标）与一个 `HotIf` 条件的 `LButton` 热键（无 `~`，条件命中即吞掉该次点击完成拾取，未命中则正常透传；**不要求游戏前台**，条件只对 LButton 按压求值，不在热键判定热路径预算内）。两条身份约束：`HotIf` 条件对象与 `SetTimer` 的函数对象都必须是**唯一实例**（静态属性缓存），否则注销不到、定时器永不停歇。关闭时**先置空 `GuiObj` 再 `Theme.Destroy`**，避免销毁瞬间轮询/条件回调访问已销毁 Gui 的 `Hwnd`（`Gui has no window`）。

把关：`_OnSave` 校验命名（≤50 字符、禁引号/反斜杠/控制字符，与存储文件的读取约束一致）与「功能 + 坐标」（`CustomScriptEngine.Validate`），不合法弹窗拒绝且窗口保持打开。

## 底部状态栏（status_bar.ahk）

`StatusBarHints` 在全部控件之后创建（保证位于窗口最底）：悬停在已登记控件上时显示该控件说明，未悬停时每 `RotateIntervalMs`（10s）随机轮播引导文案，首次打开窗口显示时段问候（进程内仅一次）。说明**以中文原文为键**，显示时才 `I18n.T`（可含 `{1}`，由 `Register` 的 `argsProvider` 实时求值）；`_Hints` 表**以控件 HWND 为键**——AHK 控件对象无法运行时销毁重建，HWND 才稳定。

三条易踩的耦合：① `SetTimer` 的启停必须用**同一函数对象**（`_RotateCallback`），否则定时器永不停歇；② `Init` 的时序是"先 `Register` 后 `Init`"，**故 `Init` 绝不清空 `_Hints`**，窗口重建的清理由 `Reset()` 负责；③ 双缓冲（`WS_EX_COMPOSITED`）下系统按实际 Z 序合成，指示块 `SepLine` 与末尾 1×1 白色占位 Text 重叠，必须显式 `_SetOverlayZ` 置顶，否则白点会浮在指示块上。`OnMessage(0x0200, ...)` 是进程级回调，与 `TabManager` 的同号回调按注册顺序共存，只注册一次。

## "其他设置"页面结构

左侧 Text 导航项（`NavItems`）+ 右侧各分类项内容叠加，经 `_SwitchOtherCategory` 切换 Visible。`OtherCategories` Map（分类名→[控件组, 导航索引]）统一管理，新增分类只需加一行。导航切换有 `force` 参数（标签页切换强制显示、导航点击不传以守卫重复点击）。关于页是纯展示页，保存/应用按钮仍按全局脏状态与冲突状态决定。

## 更新源下拉框

"更新"分类中新增"更新源"下拉框（国内源/GitHub，默认国内源）。切换时 `_OnUpdateSourceChange()` 联动 Token 复选框与输入框两者的 `Enabled` 状态——选国内源时两者灰掉，选 GitHub 时恢复；提示文字保持启用（不随源置灰）。

## Frame155 双写机制

帧率存储有两个 INI 键 — `Frame155` 存文本值（如 "90"、"180"、"240+"），`Frame` 存旧版索引（1~7，180 映射为 6）。新版优先读取 Frame155，回退读 Frame 旧序号并转换。保存时双写两个键，`MigrateFrameRate()` 在启动时自动将旧序号迁移到 Frame155。新增帧率时需同步更新 3 处：`Constants.FrameOptions`（下拉框选项）、`Constants.FrameTextToOldIndex`（文本→旧序号）、`Constants.FrameOldIndexToText`（旧序号→文本）。

## GUI 控件统一管理

对于批量重复的控件组（如过帧延迟字段、导航分类），优先使用列表/Map 集中定义再循环遍历（如 `FrameSkipDelayKeys`、`OtherCategories`），避免单个 try 块的 OR 链，便于扩展。

## 顶部标签页管理器（gui.ahk）

`TabItems` 数组描述六个标签（`keyBind`/`quick`/`strongHoldProtocol`/`customKeys`/`specialOps`/`other`），`CanHide` 控制可否隐藏（`other` 不可隐藏；`customKeys` 与 `specialOps` 为管理型标签页可隐藏，隐藏仅失去编辑入口、已绑定按键照常按其类型生效，切到这两页也不改变当前热键组）。

`TabOrder`/`HiddenTabs` 两个 Important 配置项存顺序与隐藏列表，通过两个 **Hidden Edit 表单变量**（`vTabOrder`/`vHiddenTabs`）与 `MainGui["TabOrder"]` 交互——必须放布局链之外（如 `sepCustom` 前），否则破坏自定义页左列 `y+10` 相对定位。

`AppliedTabSettings` 存已应用快照，`IsTabVisible()` 优先读快照、`tabItem.Visible` 是工作态（统计当前可见性直接遍历 `tabItem.Visible`）。眼睛图标统一 `U+E890`（蓝=显示/灰=隐藏），禁止隐藏最后一个功能标签时弹窗。`LastActiveTab` 只记录功能标签页（排除 `other`、`customKeys` 与 `specialOps`；`_UpdateTopTabBar` 的 `isOther` 分支据此决定「其他设置」页上的 ✓/✗ 标记）。

## Segoe MDL2 Assets 图标码点

`U+E890`=View（眼睛，可靠）；`U+E8F4`=NewFolder（**不是闭眼**）；`U+E9CE` 在部分系统字形缺失会显示问号。选图标码点前用像素渲染实测确认，不要凭记忆推断。

`game_monitor.ahk`/`core/hotkey/hotkey_actions.ahk` 用 `SetThreadDpiAwarenessContext(-3)` 是局部临时切换（像素检测用），不影响 GUI 主窗口 DPI 基准。

## AHK DPI 与坐标换算

AHK v2 是 **system DPI aware**（非 per-monitor，官方文档明确"not marked as per-monitor DPI-aware"）。`A_ScreenDPI`=主屏 DPI 是正确基准，系统对副屏做 bitmap scaling 并统一坐标——多屏不同缩放下用 `A_ScreenDPI` 换算即可，不要用 `GetDpiForWindow`。

`MouseGetPos` 在 `CoordMode "Mouse","Client"` 下返回**物理像素**，而 GUI `Move()` 用**逻辑像素**（DPI 缩放），两者换算：`物理像素 * 96 / A_ScreenDPI`。同理标签管理器里的 `TabManagerRowStartY`/`RowHeight` 是逻辑像素，拖拽命中判定必须先换算，否则 150% 等缩放下拖拽位置偏移。

## AHK Text 控件运行时改背景色不可靠

`Opt("Background" color)` 对已创建 Text 控件改背景色，文档明确"the control might choose to ignore it"——高亮能显示但取消高亮不刷新，`Sleep -1`/`Redraw()` 均无法绕过。

需要运行时切换背景时用**双控件叠加**（固定背景层 + 高亮层，通过 `Visible` 切换），并将高亮层加入命中测试（`GetTabManagerHit`）。注意 `_ShowControls` 会把组内所有控件设为可见（含高亮层），需在分类切换后重绘重置。

## 动态对齐 vs 绝对坐标

GUI 中右列对齐左列时，用 `GetPos` 动态读取左列控件实际 y 存入类成员（如 `TabManagerTitleY`），而非硬编码绝对坐标——AHK 的 `y+10` 相对"前一个控件底部"（非 Section），绝对坐标估算易随字体/布局漂移。控件尺寸/垂直偏移（`y+4` 等）在各子控件间应统一，否则视觉高度不齐。
