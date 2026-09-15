# 深色模式 API 兼容性

本文仅说明当前深色模式使用的 Windows 接口、版本要求和回退行为，对应 `src/lib/base/theme.ahk`。不包含通用窗口布局、双缓冲机制或日志规范。


## 1. 深色模式判定

- `ThemeMode=auto|light|dark`；临时预览优先于已保存模式，高对比度优先于普通深色模式。
- 跟随系统时，通过 AHK `RegRead` 读取 `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` 的 `AppsUseLightTheme`：0表示深色，其他值按浅色处理；缺键或读取失败使用浅色默认值。此注册表约定不是让 Win32 控件自动变深色的接口。
- 使用 `SystemParametersInfoW(SPI_GETHIGHCONTRAST)` 查询高对比度；查询失败保留上次结果。高对比度启用时，颜色由 `GetSysColor` 获取，并停止普通深色自绘路径。
- `WM_SETTINGCHANGE`、`WM_THEMECHANGED` 和 `WM_SYSCOLORCHANGE` 通知触发合并刷新，不修改 Windows 的全局主题设置。

## 2. 深色标题栏

标题栏统一通过 `DwmSetWindowAttribute` 设置。函数本身最低支持 Windows Vista，但属性有单独的版本要求。

| 属性 | 官方支持起点 | 当前处理 |
|---|---|---|
| `DWMWA_USE_IMMERSIVE_DARK_MODE`（20） | Windows 11 build 22000 | 根据深色状态设置；Windows 10仅作能力尝试，失败保留系统标题栏 |
| `DWMWA_CAPTION_COLOR`（35） | Windows 11 build 22000 | 设置与窗口背景一致的标题栏颜色；更早版本跳过；高对比度使用 `0xFFFFFFFF` 恢复系统默认 |

两个属性的数据均为4字节。返回值是 **HRESULT**，负值表示失败；只有捕获异常并不足以识别 API 调用失败。标题栏接口不负责窗口内部控件的深色绘制。

来源：[DwmSetWindowAttribute](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/nf-dwmapi-dwmsetwindowattribute)、[DWMWINDOWATTRIBUTE](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute)。

## 3. 深色控件绘制

当前方案保留原生控件的输入和事件行为，在深色且非高对比度时接管部分外观；不是仅靠一个系统开关实现所有控件深色化。

| 接口 / 消息 | 深色模式中的用途 | 兼容性及回退 |
|---|---|---|
| `SetWindowSubclass`、`DefSubclassProc`、`RemoveWindowSubclass` | 接入按钮、复选框、下拉框、分组框、UpDown及Edit的消息处理 | Windows XP、Comctl32 5.8+；仅在所属GUI线程使用。安装失败保留原生处理 |
| `WM_PAINT` / `WM_PRINTCLIENT` | 绘制按钮、下拉框主体、分组框、增减箭头及复选框背景/文字 | 使用系统GDI绘制；不以这些消息接管Edit内容区输入和滚动 |
| `WM_CTLCOLOREDIT` / `WM_CTLCOLORSTATIC` / `WM_CTLCOLORLISTBOX` | 提供文字、输入框及下拉列表的前景色和背景画刷 | 仅处理已登记的控件；颜色消息不负责原生滚动条换肤 |
| `OpenThemeData`、`DrawThemeBackground`、`CloseThemeData` | 绘制复选框的系统勾选图形 | 文档最低客户端为Windows Vista；主题不可用或绘制失败时使用 `DrawFrameControl` |
| `SetWindowTheme` | 选择是否保留Edit原生视觉主题，以及恢复复选框默认主题关联 | Windows Vista；`NULL/NULL`恢复默认关联，空字符串禁用视觉主题，二者不可混用 |
| `GetComboBoxInfo` | 获取下拉列表句柄，以便列表内容配色 | Windows Vista；失败时不登记列表别名，列表继续使用原生外观 |

来源：[SetWindowSubclass](https://learn.microsoft.com/en-us/windows/win32/api/commctrl/nf-commctrl-setwindowsubclass)、[OpenThemeData](https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-openthemedata)、[DrawThemeBackground](https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-drawthemebackground)、[SetWindowTheme](https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-setwindowtheme)、[GetComboBoxInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcomboboxinfo)。

### Edit与滚动条

- 深色Edit内容保留原生绘制；主题层通过颜色消息提供配色，并在非客户区处理外边框。光标、选区、输入和滚动仍由原控件处理。
- 无滚动条的深色Edit关闭原生视觉主题，避免原生边框动画与深色外边框互相覆盖。
- 带 `WS_VSCROLL` 或 `WS_HSCROLL` 的Edit保留系统视觉主题，避免滚动条退回经典样式。
- 滚动条及部分系统选区、焦点效果可能仍为浅色，不保证整个控件全部变黑。退出普通深色模式时恢复对应系统主题处理。

## 4. 位数与资源约束

以下结构必须按调用进程位数处理，不能仅凭操作系统位数选择布局。

| 结构 | x86 | x64 | 用途 |
|---|---:|---:|---|
| `HIGHCONTRASTW` | 12字节 | 16字节 | 查询高对比度 |
| `COMBOBOXINFO` | 52字节 | 64字节 | `hwndList`偏移分别为48、56 |
| `PAINTSTRUCT` | 64字节 | 72字节 | 深色控件绘制 |
| `TRACKMOUSEEVENT` | 16字节 | 24字节 | 深色控件悬停/离开状态 |

- HWND、HDC及主题句柄使用 `Ptr`；RECT为四个32位LONG，COLORREF采用 `0x00BBGGRR`，与界面配色的RRGGBB区分。
- `WM_PAINT` 的 `BeginPaint/EndPaint` 成对；`WM_PRINTCLIENT` 借用调用者HDC，不调用EndPaint。Edit外边框的 `GetWindowDC/ReleaseDC` 成对。
- 自建画刷与主题句柄在对应生命周期释放；系统库存画刷不删除。销毁时移除subclass，退出时再释放回调。

## 5. 支持边界与验证

- 当前深色模式使用系统具名导出，不依赖 `AllowDarkModeForWindow`、`SetPreferredAppMode` 等未公开序号接口，也不依赖 `DarkMode_Explorer` / `DarkMode_CFD` 主题名。
- Windows 10上的深色标题栏仅按调用结果尝试；Windows 11也应检查具体属性版本与HRESULT，不能因函数存在而假定全部属性可用。
- Windows 11 build 26100 x64已有隔离运行验证；用户已在[当前深色模式验收清单](../../test/finished_test_dark_mode_current.md)填写通过结果。Win10、其他Win11 build及x86不据此视为已实机验证。
- API返回成功、源码检查通过与实际显示正确是不同的验证层次；跨系统验收仍需检查标题栏、控件状态、滚动与主题切换。
