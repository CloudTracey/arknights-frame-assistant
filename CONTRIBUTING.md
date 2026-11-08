# 贡献指南

感谢您考虑为明日方舟帧操小助手（Arknights Frame Assistant）做出贡献！本指南将帮助您了解如何参与项目的开发。

## 目录

- [开发环境](#开发环境)
- [代码规范](#代码规范)
- [如何贡献](#如何贡献)
  - [报告问题](#报告问题)
  - [提交功能请求](#提交功能请求)
  - [提交代码](#提交代码)
- [Pull Request 流程](#pull-request-流程)
- [测试流程](#测试流程)
- [版本发布流程](#版本发布流程)
- [社区行为准则](#社区行为准则)
- [获取帮助](#获取帮助)
- [许可证](#许可证)

## 开发环境

本项目使用 **AutoHotkey v2** 进行开发（当前推荐版本 v2.0.26）。

### 环境要求

- **操作系统**: Windows 10/11
- **编辑器**: 推荐使用 VS Code 配合 AHK++ 扩展开发

### 离线文档

仓库内的 `docs/` 目录收录了开发所需的离线文档：

- `docs/ahk_docs/`：AHK v2 官方文档（离线版）
- `docs/win_docs/`：项目所需的 Windows API 文档（`.md` 格式）

### 项目结构

```
├── src/                          # 源代码目录
│   ├── main.ahk                  # 唯一入口：只 Include 定义，启动由 App.Bootstrap() 执行
│   ├── lib/                      # 四层单向依赖：bootstrap → ui → core → base
│   │   ├── base/                 # 基础层：不依赖 core/ui
│   │   │   ├── changelog_format.ahk # 更新公告多语言裁剪
│   │   │   ├── config.ahk        # 配置管理（Config 类）
│   │   │   ├── constants.ahk     # 全局常量
│   │   │   ├── custom_hotkey_store.ahk # 自定义按键 JSON 存储（独立于 Settings.ini）
│   │   │   ├── display_info.ahk  # 显示器刷新率查询
│   │   │   ├── eventbus.ahk      # 事件总线（模块间解耦通信）
│   │   │   ├── file_extractor.ahk # 嵌入资源的运行时提取
│   │   │   ├── game_target.ahk   # 当前目标游戏窗口的唯一 owner
│   │   │   ├── hotkey_schema.ahk # 热键元数据唯一来源
│   │   │   ├── i18n.ahk          # 国际化核心（I18n 类）
│   │   │   ├── key_format.ahk    # 热键键值格式化工具
│   │   │   ├── locales/          # 五语言资源（键 = 中文原文）
│   │   │   │   ├── zh_hans.ahk
│   │   │   │   ├── zh_hant.ahk
│   │   │   │   ├── ja_jp.ahk
│   │   │   │   ├── ko_kr.ahk
│   │   │   │   └── en_us.ahk
│   │   │   ├── logger.ahk        # 双轨日志系统
│   │   │   ├── message_box.ahk   # 自定义消息框
│   │   │   ├── metrics.ahk       # UI 度量与字体
│   │   │   ├── server_profile.ahk # 区服元数据与识别
│   │   │   ├── single_instance.ahk # 单例识别（命名互斥体）
│   │   │   ├── theme.ahk         # 主题状态、配色与原生控件绘制
│   │   │   ├── timing.ahk        # 高精度延迟工具
│   │   │   ├── token_protector.ahk # GitHub Token DPAPI 加密保护
│   │   │   ├── touch_injection.ahk # Touch Injection 模拟点击
│   │   │   ├── tray.ahk          # 托盘提示封装
│   │   │   ├── unity_player_prefs.ahk # Unity PlayerPrefs 注册表读取
│   │   │   ├── version.ahk       # 内置版本号（唯一来源）
│   │   │   ├── version_utils.ahk # 版本/JSON 纯工具
│   │   │   └── window.ahk        # 窗口/屏幕工具
│   │   ├── core/                 # 核心层：依赖 base，不依赖 ui
│   │   │   ├── audio/            # 音频
│   │   │   │   └── volume_controller.ahk # 游戏应用音量控制
│   │   │   ├── diagnostics/      # 诊断
│   │   │   │   └── log_exporter.ahk # 诊断压缩包导出
│   │   │   ├── game/             # 游戏客户端
│   │   │   │   ├── game_client_registry.ahk # 游戏客户端实例注册表
│   │   │   │   └── game_frame_rate.ahk # 游戏帧率自动识别
│   │   │   ├── hotkey/           # 热键域
│   │   │   │   ├── custom_script.ahk # 自定义按键功能引擎
│   │   │   │   ├── game_keys.ahk # 游戏按键识别与注入
│   │   │   │   ├── hotkey_actions.ahk # 热键动作实现
│   │   │   │   ├── hotkey_service.ahk # 热键注册/注销/分组切换
│   │   │   │   └── timing_service.ahk # 过帧时序服务
│   │   │   ├── launch/           # 启动相关
│   │   │   │   ├── app_context.ahk # 启动上下文
│   │   │   │   ├── game_auto_start.ahk # 随游戏自动启动（计划任务）
│   │   │   │   └── game_launcher.ahk # 随 AFA 启动游戏
│   │   │   ├── monitor/          # 游戏监控
│   │   │   │   ├── game_monitor.ahk # 自动退出/自动开局暂停/二倍速
│   │   │   │   ├── hook_monitor.ahk # 键盘钩子存活检测
│   │   │   │   └── level_detector.ahk # 关卡检测状态机
│   │   │   ├── settings/         # 设置域
│   │   │   │   ├── hotkey_conflict_validator.ahk # 热键冲突校验
│   │   │   │   └── settings_service.ahk # 唯一配置写口
│   │   │   └── updater/          # 自动更新模块
│   │   │       ├── changelog_checker.ahk # 更新公告检查
│   │   │       ├── downloader.ahk # 更新包下载
│   │   │       ├── github_token_service.ahk # GitHub Token 校验
│   │   │       ├── release_repository.ahk # GitHub/国内源检查
│   │   │       ├── self_replacer.ahk # 更新器自我替换
│   │   │       ├── updater_manager.ahk # 更新流程协调器
│   │   │       └── version_checker.ahk # 版本检查门面
│   │   └── ui/                   # UI 层：依赖 core/base
│   │       ├── changelog_ui.ahk  # 更新公告 UI
│   │       ├── custom_key_editor.ahk # 自定义按键编辑窗口
│   │       ├── gui.ahk           # 设置窗口 GUI
│   │       ├── key_bind.ahk      # 按键绑定捕获（InputHook）
│   │       ├── status_bar.ahk    # 底部模拟状态栏
│   │       └── updater_ui.ahk    # 更新 UI（对话框）
│   └── resources/                # 运行时资源
│       └── images/               # 关卡检测/按钮模板图像（编译期嵌入，运行时提取）
├── .github/                      # GitHub 配置
│   ├── CODEOWNERS                # 代码所有者
│   ├── ISSUE_TEMPLATE/           # Issue 模板（Bug/功能/文档/提问）
│   ├── PULL_REQUEST_TEMPLATE.md  # PR 模板
│   ├── scripts/                  # Actions 辅助脚本（version.json 生成、版本号检查）
│   └── workflows/                # Actions 工作流（架构检查、版本检查、发布同步）
├── .dsh/                         # DeepSeek Harness 项目配置（仅 skills 入版本库）
│   └── skills/test-checklist/    # 生成手工测试清单的 skill
├── .vscode/                      # 编辑器配置
│   └── settings.json             # 统一编码/行尾/缩进，避免 PR 噪音
├── docs/                         # 文档
│   ├── ahk_docs/                 # AHK v2 官方文档（离线版）
│   ├── design/                   # 架构与设计参考分册（改到对应模块时再读）
│   │   ├── README.md             # 分册索引
│   │   ├── module_responsibilities.md # 启动流程与模块职责表
│   │   ├── key_designs_hotkey.md # 热键/注入/透传/关卡检测/多区服
│   │   ├── key_designs_base.md   # 配置/日志/诊断/更新/发布链路
│   │   ├── key_designs_ui.md     # GUI/主题/DPI/标签页
│   │   ├── hold_guard.md         # 按住去重状态机
│   │   ├── input_stall_diagnosis.md # 输入卡顿与按键失效排查
│   │   ├── ahk_v2_pitfalls.md    # AHK v2 语言/API 陷阱合集
│   │   ├── i18n.md               # 国际化约定与五语言验证
│   │   └── reference.md          # 事件/配置键/发布/静态检查速查
│   ├── i18n/glossary.md          # 游戏术语官方译法
│   └── win_docs/                 # Windows API 文档
├── tools/                        # Python 静态门禁检查
│   ├── event_contract_check.py   # 事件契约检查
│   ├── i18n_check.py             # i18n 文案与资源检查
│   └── layer_check.py            # 四层依赖与 include 顺序检查
├── test/                         # 手工测试清单
│   ├── template/test_template.md # 测试清单模板
│   └── finished_test_*.md        # 已完成的测试清单
├── AGENTS.md                     # AI 编码助手指南（含铁律速查）
├── CONTRIBUTING.md               # 贡献指南
├── KNOWN_VIOLATIONS              # layer_check 已知耦合基线
├── LICENSE                       # GNU GPL v3.0
├── README.md                     # 项目说明（另有 en/ja/ko/zh-Hant 版本）
├── logo.ico / logo.png           # 项目图标
├── .gitattributes                # 行尾规范（检出 CRLF / 提交 LF）
└── .gitignore                    # 版本库排除规则
```

## 代码规范

为了保持代码质量和一致性，请遵循以下规则：

### 代码风格

- 函数名与方法名使用大驼峰命名法（如 `CheckVersion()`）
- 全局变量名和静态变量名使用大驼峰命名法（如`static WindowName`）
- 局部变量名使用小驼峰命名法（如 `gameProcess`）
- 常量使用全大写（如 `MAX_RETRY`）
- 添加适当的注释说明复杂逻辑

### 注释规范

```autohotkey
; 单行注释

/*
 * 多行注释
 * 用于说明复杂功能
 */
```

## 如何贡献

### 报告问题

如果您发现了 bug，请使用 [Bug 报告模板](.github/ISSUE_TEMPLATE/bug_report.yml) 提交。请尽量包含以下信息，以便更快定位问题：

- AFA 版本号、Windows 版本
- 游戏分辨率、屏幕刷新率
- 详细复现步骤，以及期望行为与实际行为
- 如有可能，附上日志压缩包（AFA 设置 →“日志”页面 → **生成日志压缩包**）

### 提交功能请求

请使用 [功能请求模板](.github/ISSUE_TEMPLATE/feature_request.yml)。提交新功能请求前，请先搜索 [现有 Issues](https://github.com/CloudTracey/arknights-frame-assistant/issues) 确认没有重复。

### 提交代码

#### 准备工作

1. Fork 本仓库
2. 克隆您的 Fork 到本地：
   ```bash
   git clone https://github.com/YOUR_USERNAME/arknights-frame-assistant.git
   cd arknights-frame-assistant
   ```
3. 添加上游仓库：
   ```bash
   git remote add upstream https://github.com/CloudTracey/arknights-frame-assistant.git
   ```

#### 创建分支

基于最新的 `develop` 分支创建您的功能分支：

```bash
git checkout develop
git pull upstream develop
git checkout -b feat/your-feature-name
```

分支命名规范：
- `feat/描述` - 新功能
- `fix/描述` - Bug 修复
- `docs/描述` - 文档更新
- `style/描述` - 代码格式（不影响功能）
- `ui/描述` - GUI修改
- `perf/描述` - 性能优化
- `refactor/描述` - 代码重构

#### 开发流程

1. 编写代码并遵循上述代码规范
2. 按[测试流程](#测试流程)一节创建测试清单
3. 本地手动测试您的更改，确保测试通过
4. 更新相关文档（如需要）

## Pull Request 流程

### 提交前准备

1. **同步代码**：
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout your-branch
   git rebase develop
   ```

2. **检查文件**：
   - 确保没有遗漏未删除的调试代码

3. **提交信息规范**：

   我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

   ```
   <type>(<scope>): <subject>

   <body>

   <footer>
   ```

   **类型（type）：**
   - `feat`: 新功能
   - `fix`: Bug 修复
   - `docs`: 文档更新
   - `style`: 代码格式（不影响功能）
   - `refactor`: 代码重构
   - `perf`: 性能优化
   - `test`: 测试相关
   - `chore`: 构建过程或辅助工具的变动
   - `ui`: GUI相关修改

   **范围（scope）：** 与改动涉及的模块文件名保持一致（如 `feat(game_keys)`、`fix(hotkey_actions)`）。
   测试清单属于特殊情况：类型固定为 `docs`，scope 为 `test`（如 `docs(test): 添加 xxx 测试清单`）。

   **示例：**
   ```
   feat(hotkey): 添加新的按键绑定功能

   实现了对鼠标中键的绑定支持，
   允许用户在设置界面配置鼠标中键触发的动作。

   Closes #123
   ```

### 创建 Pull Request

1. 推送您的分支到您的 Fork：
   ```bash
   git push origin your-branch
   ```

2. 在 GitHub 上创建 Pull Request，**目标分支选择 `develop`**

3. 参照 [PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) 提供的模板填写

4. 等待代码审查

### 代码审查

- 所有提交都需要至少一个审查者的批准
- @CloudTracey 是项目维护者，拥有最终合并决定权
- 审查者可能会要求您进行修改，请积极响应

## 测试流程

运行时与 GUI 功能以**手工验证**为主。仓库包含 Python 静态门禁检查，可在项目根目录运行：

```powershell
python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS
python -X utf8 tools/event_contract_check.py
python -X utf8 tools/i18n_check.py
```

静态检查不启动 AFA；静态检查结果与手工验证结果分别记录。

### 测试清单创建

每次进行更改后，需要创建测试清单文件：

1. 参考模板 [test/template/test_template.md](test/template/test_template.md)（分为**单元测试**、**集成测试**、**回归测试**三部分，并包含测试环境表格）
2. 文件名格式：`test_[更改主题].md`（英文，如 `test_download_progress_bar.md`）
3. 文件内每小步添加复选框，方便逐项标记

> 测试清单模板说明：可以交由 AI 根据模板生成测试清单以节约工作量（项目使用我自行编写的 `test-checklist` skill 生成，技能位于 `.dsh/skills/test-checklist`，由 DeepSeek Harness 等编码 Agent 自动发现调用）。

### 测试完成标记

当测试完成后，将测试清单文件重命名为 `finished_test_[更改主题].md`（可参考 `test/` 目录下已有的 `finished_test_*.md` 文件）。

## 关于 AI编程

本项目不排斥AI编程，自AFA v1.5.0+版本开始本项目便大量使用了AI来提高开发速度。
AI编程的优点是一些重复性较高的工作得以快速完成，复杂度较高的功能也能快速开发出原型用于后续迭代。
缺点也很突出，AI根据反馈找BUG和修BUG的速度很快，但写BUG的速度更快，审查代码的时候稍微犯点懒跳过几项，等发版之后就可能会给你来点大惊喜；
然后就是屎山堆积，原先我古法编程写出来的东西虽然也是屎山，但好歹还是我自己能读明白的屎山，AI编程整多了之后一些地方是想手动修都不知道从哪里开始修。
因此如果您使用AI编程进行开发并希望提交PR，请遵循以下规则：

### 对使用者自身的要求

1. 具备一定的软件工程知识，了解软件开发的流程（不用AI编程也是需要了解的，但是用AI编程就更需要了解了）
2. 具备一定的架构设计能力，能清晰界定待开发任务的功能范围、模块边界和依赖约束（比如明确“这个功能归哪个模块管，哪个部分能动哪个部分不能动”），避免AI自由发挥，破坏现有结构
3. 能读懂AI写出来的代码，知道AI在写什么东西
4. 能对自己使用AI写出来的代码进行全面的审查

### 使用的模型和Harness

1. **不要使用各路AI厂商的网页端和APP端进行开发**，不要把项目文件丢给什么豆包、DeepSeek的网页端、App端然后跟它们说“豆包豆包我要做一个xxxx请你帮帮我”，在缺乏上下文引导、没有Harness辅助和限制、模型参数微调、免费端模型的智力限制、工具缺失的情况下，这么写出来的东西一定是**纯粹的屎**
2. 关于使用的AI模型：只要模型能力不是太差一般都没啥问题，个人目前使用的是DeepSeek 官方 API，即便经过涨价依旧是性价比最高的模型之一
3. 关于使用的Harness：当前主流的几个Harness一般也没啥问题，比如Claude Code、Codex、ZCode、DeepSeek Harness之类的
4. 目前项目里的.dsh和AGENTS.md可以根据自己使用的模型和Harness进行重命名，比如使用Claude就改成.claude和CLAUDE.md

### Skills

目前我最常用的Skill只有我自己写的test-checklist，用来手动生成测试清单，已经放在仓库里了。然后就是mattpocock的这套Skills：https://github.com/mattpocock/skills ，基本上能满足大部分的开发需求了

### 注意事项

PR表现为完全的许愿式编程和显然没经过审查的破坏性变更、大面积改动，或者莫名其妙修改完全不相干部分的代码都会被维护者视为不负责任的PR，可能会在简要说明后被直接关闭，还请见谅
另外，使用AI开发 ≠ 完全交给AI，PR模版、对评审的回复总该自己写吧，要Vibe Coding我会去自己的Harness里，而不是在PR页面跟不知道是真人还是人机对聊

## 社区行为准则

参与本项目即表示您同意遵守以下行为准则：

1. **尊重他人**：对所有参与者保持礼貌和尊重
2. **建设性反馈**：提供有帮助的反馈和建议
3. **耐心沟通**：理解不同技术水平的贡献者
4. **专注技术**：讨论保持技术相关，避免无关话题

## 获取帮助

- **GitHub Issues**: 报告问题或请求功能（请使用对应模板）
- **GitHub Discussions**: 一般性讨论
- **邮件**: 如有私密问题，可邮件联系维护者 <cloudtrace233@qq.com>

## 许可证

通过贡献代码，您同意您的贡献将在 [GNU General Public License v3.0](LICENSE) 下发布。

---

再次感谢您对本项目的贡献！

**维护者：** [@CloudTracey](https://github.com/CloudTracey)
