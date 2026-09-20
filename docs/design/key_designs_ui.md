# 关键设计：GUI 与主题

> AGENTS.md 参考资料分册。AGENTS.md 只保留必须遵守的铁律，本文件保留完整机制、历史与理由。

## GUI 脏值对比

`GuiManager` 维护 `_InitialValues` 快照和 `IsModified` 标志。`CaptureInitialSnapshot()` 在设置加载/保存/应用后保存所有控件当前值，`TrackChange(key)` 在控件变更时将当前值与快照对比，同时将新值同步写入 Config 内存（热键控件和 SwitchHotkey 已由 `KeyBinder.EndChange` 提前写入，`TrackChange` 负责其余控件）。

`UpdateSaveButtonState()` 根据 `IsModified` 和 `HasHotkeyConflicts` 决定保存/应用按钮状态。`RefreshHotkeyConflicts()` 调用 `HotkeyConflictValidator` 进行增量字体标红（仅更新冲突状态变化的控件，使用 `_PrevConflictedControls` 做 diff）。

`SwitchTab()` 保留内存修改及主题预览；显式取消由 `SettingsService.Cancel()` 重载配置。

**自定义按键页**：12 行预建（两列 × 6 行）（显隐 + 重写值实现增删，AHK 控件无法运行时移除）、行控件命名 `CustomHotkey{i}Key/Gear`（删除功能在编辑窗口内）、`TrackChange` 对 `CustomHotkey*Key` 委托 `TrackCustomHotkeysChange`。

新增可修改控件时需在 `CaptureInitialSnapshot` 中添加对应 key，并在控件事件中调用 `TrackChange`。

**语言切换会重建窗口**（`_OnSettingsSaved`/`_OnSettingsApplied` 的 `_LanguageChanged` 分支），该分支必须在 `Rebuild()` 之后同样执行 `SetIsModifiedFalse()` + `CaptureInitialSnapshot()`——否则保存成功后脏标志残留，重开窗口会误报"修改尚未保存或应用"并点亮保存/应用按钮。

## 主题生命周期与预览

（`theme.ahk` + `settings_service.ahk`）

`[Main] ThemeMode=auto|light|dark` 默认 auto；`SettingsService.Initialize()` 仅在缺键时原子补回 auto，已有非法值按 auto 读取、正常保存时规范化；INI 行位置不固定，节名必须是 Main。

**规范化单一入口**：规则与合法值集合只在 `Constants.NormalizeThemeMode`/`Constants.ThemeModes`（Config 读写与 Theme 均调用它，base 内不得反向引用 Theme）。

`Theme.Preview` 仅更新显示，保存成功与取消经 `Theme.Confirm` 同步；预览优先于已保存模式，按键重置及切页不结束预览。

**主题最后落盘**：`SaveAllToIni()` 前把 `ThemeMode` 还原为已保存值，等 Settings.ini 与 `CustomHotkeys.json` 都写成功后才经 `_PersistSingleValue` 单独提交，避免自定义按键文件保存失败时提前提交主题。

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

Theme 生命周期与低频模式变化使用现有 Logger；绘制故障按操作去重并延后写入（`_WarnOnce` 入队 + 一次性定时器 flush），不逐帧或逐次鼠标移动记录。主题逻辑改动运行 `test/scripts/theme_test.ahk`（`Theme.Resolve`/`Normalize` 与 `Constants.NormalizeThemeMode` 纯逻辑 + 二者一致性断言，不建窗、不读注册表），再跑 `test/scripts/smoke_test.ahk`（全模块 include、零顶层副作用），通过不等同于 GUI 验收。

## key_bind.ahk 的 WM_LBUTTONDOWN 处理

`OnMessage(0x0201, WM_LBUTTONDOWN)` 是进程级回调，会在所有 GUI 的 Edit 控件点击时触发。为防止非设置窗口的 Edit 控件误触发按键录制，回调开头有父窗口检查：`if (KeyBinder.ControlObj.Gui.Hwnd != GuiManager.MainGui.Hwnd) return`。

新增 Edit 控件且不需要按键录制功能时，确保其父窗口不是 `GuiManager.MainGui`。点击非 Edit 区域时自动聚焦取消按钮（`GuiManager.FocusCancelButton()`），取消普通 Edit 控件的选中状态。

## Alt+F4 始终退出

通过 `GuiManager.Start()` 中的 `HotIf` + `Hotkey("!F4", ...)` 动态注册拦截设置窗口的 Alt+F4，始终彻底退出 AFA。标题栏 X 按钮仍由 `ExitOnWindowClose` 设置控制（关闭窗口 or 退出）。

## AHK v2 GUI 布局要点

`xs`/`ys` 引用**最近**的 `Section`（叠加布局中会追到前一个分类的 Section 导致偏移，每组首控件应用绝对坐标如 `x160 y45`）。Text 的 `Center` 仅水平居中，文字要填满控件需去掉固定高度自适应（`hp`）而非依赖 Center。

## "其他设置"页面结构

左侧 Text 导航项（`NavItems`）+ 右侧各分类项内容叠加，经 `_SwitchOtherCategory` 切换 Visible。`OtherCategories` Map（分类名→[控件组, 导航索引]）统一管理，新增分类只需加一行。导航切换有 `force` 参数（标签页切换强制显示、导航点击不传以守卫重复点击）。关于页是纯展示页，保存/应用按钮仍按全局脏状态与冲突状态决定。

## 更新源下拉框

"更新"分类中新增"更新源"下拉框（国内源/GitHub，默认国内源）。切换时 `_OnUpdateSourceChange()` 联动 Token 复选框与输入框两者的 `Enabled` 状态——选国内源时两者灰掉，选 GitHub 时恢复；提示文字保持启用（不随源置灰）。

## Frame155 双写机制

帧率存储有两个 INI 键 — `Frame155` 存文本值（如 "90"、"180"、"240+"），`Frame` 存旧版索引（1~7，180 映射为 6）。新版优先读取 Frame155，回退读 Frame 旧序号并转换。保存时双写两个键，`MigrateFrameRate()` 在启动时自动将旧序号迁移到 Frame155。新增帧率时需同步更新 3 处：`Constants.FrameOptions`（下拉框选项）、`Constants.FrameTextToOldIndex`（文本→旧序号）、`Constants.FrameOldIndexToText`（旧序号→文本）。

## GUI 控件统一管理

对于批量重复的控件组（如过帧延迟字段、导航分类），优先使用列表/Map 集中定义再循环遍历（如 `FrameSkipDelayKeys`、`OtherCategories`），避免单个 try 块的 OR 链，便于扩展。

## 顶部标签页管理器（gui.ahk）

`TabItems` 数组描述五个标签（`keyBind`/`quick`/`strongHoldProtocol`/`customKeys`/`other`），`CanHide` 控制可否隐藏（`other` 不可隐藏；`customKeys` 为管理型标签页可隐藏，隐藏仅失去编辑入口、已绑定按键照常按其类型生效）。

`TabOrder`/`HiddenTabs` 两个 Important 配置项存顺序与隐藏列表，通过两个 **Hidden Edit 表单变量**（`vTabOrder`/`vHiddenTabs`）与 `MainGui["TabOrder"]` 交互——必须放布局链之外（如 `sepCustom` 前），否则破坏自定义页左列 `y+10` 相对定位。

`AppliedTabSettings` 存已应用快照，`IsTabVisible()` 优先读快照、`tabItem.Visible` 是工作态（统计当前可见性直接遍历 `tabItem.Visible`）。眼睛图标统一 `U+E890`（蓝=显示/灰=隐藏），禁止隐藏最后一个功能标签时弹窗。`LastActiveTab` 只记录功能标签页（排除 `other` 与 `customKeys`）。

## Segoe MDL2 Assets 图标码点

`U+E890`=View（眼睛，可靠）；`U+E8F4`=NewFolder（**不是闭眼**）；`U+E9CE` 在部分系统字形缺失会显示问号。选图标码点前用像素渲染实测确认，不要凭记忆推断。

`game_monitor.ahk`/`core/hotkey/hotkey_actions.ahk` 用 `SetThreadDpiAwarenessContext(-3)` 是局部临时切换（像素检测用），不影响 GUI 主窗口 DPI 基准。

## AHK DPI 与坐标换算

AHK v2 是 **system DPI aware**（非 per-monitor，官方文档明确"not marked as per-monitor DPI-aware"）。`A_ScreenDPI`=主屏 DPI 是正确基准，系统对副屏做 bitmap scaling 并统一坐标——多屏不同缩放下用 `A_ScreenDPI` 换算即可，不要用 `GetDpiForWindow`。

`MouseGetPos` 在 `CoordMode "Mouse","Client"` 下返回**物理像素**，而 GUI `Move()` 用**逻辑像素**（DPI 缩放），两者换算：`物理像素 * 96 / A_ScreenDPI`。

## AHK Text 控件运行时改背景色不可靠

`Opt("Background" color)` 对已创建 Text 控件改背景色，文档明确"the control might choose to ignore it"——高亮能显示但取消高亮不刷新，`Sleep -1`/`Redraw()` 均无法绕过。

需要运行时切换背景时用**双控件叠加**（固定背景层 + 高亮层，通过 `Visible` 切换），并将高亮层加入命中测试（`GetTabManagerHit`）。注意 `_ShowControls` 会把组内所有控件设为可见（含高亮层），需在分类切换后重绘重置。

## 动态对齐 vs 绝对坐标

GUI 中右列对齐左列时，用 `GetPos` 动态读取左列控件实际 y 存入类成员（如 `TabManagerTitleY`），而非硬编码绝对坐标——AHK 的 `y+10` 相对"前一个控件底部"（非 Section），绝对坐标估算易随字体/布局漂移。控件尺寸/垂直偏移（`y+4` 等）在各子控件间应统一，否则视觉高度不齐。
