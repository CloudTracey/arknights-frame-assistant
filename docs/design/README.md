# 设计文档索引

本目录是 [AGENTS.md](../../AGENTS.md) 的**参考资料分册**。AGENTS.md 只保留「每轮任务都必须遵守的铁律」，机制细节、历史沿革、参数取舍与陷阱解释全部移到这里，按需查阅。

这样做的原因：AGENTS.md 每轮对话都会被加载，把"参考资料"混进去会让真正必须遵守的约束被淹没有效上下文；而这些细节本身只在改到对应模块时才需要。

## 分册导航

| 文件 | 什么时候读 | 内容 |
|------|-----------|------|
| [module_responsibilities.md](module_responsibilities.md) | 要改某个模块、找不到职责归属、新增模块时 | 启动流程（按 `StartupMark` 语义标记定位）、四层架构、56 个模块的职责表 |
| [key_designs_hotkey.md](key_designs_hotkey.md) | 改热键/注入/按键透传/关卡检测/多区服识别时 | 多区服与热路径预算、热键注册与拦截、关卡守卫与透传、帧开头轮询、InjectedPressKeys、GameKeys、冲突检测 |
| [key_designs_base.md](key_designs_base.md) | 改配置/日志/诊断/更新/发布链路时 | Constants、Logger、调试控制台、Config 读写分离、EventBus 约定、自动开局暂停、双源更新、chcp 陷阱、钩子健康探针 |
| [key_designs_ui.md](key_designs_ui.md) | 改 GUI 布局/主题/标签页/坐标换算时 | 脏值对比、主题生命周期、深色绘制与 Win32 边界、DPI 换算、Text 背景色、标签页管理器 |
| [ahk_v2_pitfalls.md](ahk_v2_pitfalls.md) | 写任何 AHK 代码前（危险项已在 AGENTS.md 铁律速查） | AHK v2 语言/API 陷阱合集：删除类异常、File.Read、箭头函数、函数对象身份、数值比较、`..`、DropDownList |
| [i18n.md](i18n.md) | 新增或修改任何用户可见文案时 | source-as-key 约定、资源表与 19KB 拆分、回退链、保持中文不译清单、控件宽度自适应、五语言验证 |
| [reference.md](reference.md) | 查事件名/配置键/发布步骤/静态检查工具时 | EventBus 事件清单（55 个，标注 Legacy）、配置文件与数据文件、发布流程、静态检查工具表 |

## 相关文档

- [CONTRIBUTING.md](../../CONTRIBUTING.md) — 代码规范、分支/提交约定、PR 流程、发布流程、AI 编程约定。**代码规范与项目结构树以 CONTRIBUTING 为准**（其项目结构树已滞后于源码，模块清单以 [module_responsibilities.md](module_responsibilities.md) 为准）。
- [`docs/ahk_docs/`](../ahk_docs/) — AHK v2 官方文档离线版。开发时优先读它，而非依赖模型内置的 AHK 知识（可能过时或不完整）。
- [`docs/win_docs/`](../win_docs/) — 项目所需的 Windows API 文档。
- [`docs/i18n/glossary.md`](../i18n/glossary.md) — 游戏术语官方翻译对照，翻译前先查。
- [`CONTEXT.md`](../../CONTEXT.md) — 领域术语表（过帧、关卡守卫、按键透传等），**本地文件、不入版本库**。

## 维护约定

- **新增知识时的判断标准**：这条内容「不知道就不会去查」吗？是 → 写进 AGENTS.md 铁律速查；否 → 写进对应分册。
- **本目录纳入版本库**（不同于 `docs/adr`、`docs/architecture`、`docs/plan` 这些 `.gitignore` 内的本地目录）。
- 改动行为后若铁律或本目录内容失配，先改文档再提交代码——文档滞后过一次的代价已经在启动流程上体现（曾漏记四个启动调用）。
