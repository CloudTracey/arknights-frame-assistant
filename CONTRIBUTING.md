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
│   ├── main.ahk                  # 主入口文件（仅加载定义，App.Bootstrap() 启动）
│   └── lib/                      # 按四层架构组织
│       ├── base/                 # 基础层：不依赖 core/ui
│       │   ├── config.ahk        # 配置管理（Config 类）
│       │   ├── constants.ahk     # 全局常量
│       │   ├── eventbus.ahk      # 事件总线（模块间解耦通信）
│       │   ├── file_extractor.ahk # 嵌入资源的运行时提取
│       │   ├── hotkey_schema.ahk # 热键元数据唯一来源
│       │   ├── key_format.ahk    # 热键键值格式化工具
│       │   ├── logger.ahk        # 双轨日志系统
│       │   ├── message_box.ahk   # 自定义消息框
│       │   ├── theme.ahk         # 主题状态、配色与原生控件绘制
│       │   ├── timing.ahk        # 高精度延迟工具
│       │   ├── token_protector.ahk # GitHub Token DPAPI 加密保护
│       │   ├── touch_injection.ahk # Touch Injection 模拟点击
│       │   ├── tray.ahk          # 托盘提示封装
│       │   ├── version.ahk       # 内置版本号
│       │   ├── version_utils.ahk # 版本/JSON 纯工具
│       │   └── window.ahk        # 窗口判定工具
│       ├── core/                 # 核心层：依赖 base，不依赖 ui
│       │   ├── changelog/        # 更新公告检查
│       │   │   └── changelog_checker.ahk
│       │   ├── diagnostics/      # 诊断导出
│       │   │   └── log_exporter.ahk
│       │   ├── hotkey/           # 热键域
│       │   │   ├── game_keys.ahk
│       │   │   ├── hotkey_actions.ahk
│       │   │   ├── hotkey_service.ahk
│       │   │   └── timing_service.ahk
│       │   ├── launch/           # 启动相关
│       │   │   ├── app_context.ahk
│       │   │   ├── game_auto_start.ahk
│       │   │   └── game_launcher.ahk
│       │   ├── monitor/          # 游戏监控
│       │   │   ├── game_monitor.ahk
│       │   │   └── level_detector.ahk
│       │   ├── settings/         # 设置域
│       │   │   ├── hotkey_conflict_validator.ahk
│       │   │   └── settings_service.ahk
│       │   └── updater/          # 自动更新模块
│       │       ├── downloader.ahk
│       │       ├── github_token_service.ahk
│       │       ├── release_repository.ahk
│       │       ├── self_replacer.ahk
│       │       ├── updater_manager.ahk
│       │       └── version_checker.ahk
│       └── ui/                   # UI 层：依赖 core/base
│           ├── changelog_ui.ahk  # 更新公告 UI
│           ├── gui.ahk           # 设置窗口 GUI
│           ├── key_bind.ahk      # 按键绑定（InputHook 捕获按键）
│           └── updater_ui.ahk    # 更新 UI（对话框）
├── .github/                      # GitHub 配置
│   ├── CODEOWNERS                # 代码所有者
│   ├── ISSUE_TEMPLATE/           # Issue 模板
│   ├── PULL_REQUEST_TEMPLATE.md  # PR 模板
│   ├── RELEASE_TEMPLATE.md       # 发布说明模板
│   ├── scripts/                  # GitHub Action 辅助脚本
│   └── workflows/                # GitHub Action 工作流
├── CONTRIBUTING.md               # 贡献指南
├── docs/                         # 离线文档
│   ├── ahk_docs/                 # AHK v2 官方文档（离线版）
│   └── win_docs/                 # Windows API 文档
├── LICENSE                       # 许可证
├── logo.ico / logo.png           # 项目图标
├── README.md                     # 项目说明
└── test/                         # 测试清单
    ├── template/                 # 测试清单模板
    └── ...                       # 各次更改对应的测试清单
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

; 函数注释示例
; 功能：检查游戏进程是否存在
; 参数：process_name - 进程名称
; 返回：布尔值，存在返回 true，否则 false
CheckGameProcess(process_name) {
    ; 实现代码
}
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
git checkout -b feature/your-feature-name
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

运行时与 GUI 功能以**手工验证**为主。仓库同时包含 Python 静态门禁与源码契约检查，可在项目根目录运行：

```powershell
python -X utf8 tools/layer_check.py --baseline KNOWN_VIOLATIONS
python -X utf8 tools/event_contract_check.py
python -X utf8 tools/i18n_check.py
python -X utf8 tools/test_theme_contract.py
```

静态检查不启动 AFA，也不证明原生控件绘制正确。AHK 独立测试位于 `test/scripts/`，执行结果与手工结果分别记录。主题流程及增量验收见 [深色模式测试清单](test/finished_test_dark_mode.md)。

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

### 一点经验分享

#### 模型

先说说我用过的模型，Kimi使用起来的效果还不错，就是实在是太贵了，用了几下额度就爆炸了。
然后是Minimax，这个很便宜，给的额度也多，但是当时用了一轮对话就感觉这家伙的脑子不太好使，用了两轮后要修的Bug比写出来的功能还多。
再然后是阿里的Qwen，当时订了一个月的Plan，也是用了一天就感觉不太行，前后一个月加起来可能只用了五次。
然后是Claude，我用了半天的Opus，强是真的强，号没的也是真的快，A/你赢了。上面的几个模型都是浅尝辄止，2026年初到四月份这段时间大部分时间还是在古法编程，直到四月底DeepSeek v4预览版发布。
DSv4预览版也不太聪明，但是实在是太便宜了。当时我大部分功能还是手搓的，只有一些简单的重复性工作会交给AI，因此DS v4 Flash很好地扮演了苦力的角色（比如项目内的注释、文档的修改补充、新添加按键重复逻辑的编写等等），Pro则用来做代码审查和一些Bug的分析。
再然后就是DS v4 Flash正式版了，这个直到现在还是我的主力，在你能极其详细地描述你的需求、你的思路、以及阐明各种限制的时候，v4 Flash正式版真的是个非常好的打手。至于v4 Pro正式版，我的使用很有限，大部分时候我都是自己去想方案，并不需要它来帮我构思或者设计什么，主要还是输出速度太慢了，只有Flash二分之一的输出速度，目前只用它来细化了一下AFA v2.0.0的解耦方案设计

#### Harness

然后是Harness，我使用过的有OpenCode、Claude Code、Codex和DeepSeek Harness，其中OpenCode在年初使用了一段时间，Bug真的奇多，可能是因为当时刚发布没多久的原因吧，听说现在好像也变成了屎山，准备新开一个OpenCode v2了。
然后是Claude Code，这是我使用时间最长也是最熟悉的Harness，真的好用，非常顺手，但是封了我一次号，导致我后面只敢接DeepSeek开发，没能深入体验完全体，略微遗憾。被封号之后一怒之下转了一天的Codex，用不习惯又转回Claude Code了。
最后是现在在用的DeepSeek Harness，V4 Pro正式版出来之后换的，目前为止感觉**没有**Claude Code那么好用，一切皆插件的想法很好，但是现在社区充斥着无数的Vibe Coding的屎山插件，踩了几天的雷给我用得身心俱疲。先说一下不加插件的Harness本身，首先是界面，只有Web UI，没有TUI，我个人还是比较喜欢TUI的，轻量，操作起来也很方便，Web UI用起来还是太重了，不管是长对话的内存占用和优化还是各种操作上；然后是回滚功能，DeepSeek Harness本体目前没有回滚功能，想回滚只能通过Git回滚，或者打字叫AI帮你回滚，这就非常麻烦，Git回滚没法回滚被.gitignore忽略的本地文档，AI回滚又慢还要浪费Token；再然后是Diff的审查，Claude Code的话AI所有的修改都会立刻直接显示在TUI界面上，一目了然非常直观，可以很明显看到AI先改了哪个再改了哪个，DeepSeek Harness浏览起来就非常麻烦，只显示了Edit的操作但不显示修改的内容，想看修改的内容还得去IDE里看，但IDE里又不显示修改的先后顺序。不过DeepSeek Harness毕竟还是开发预览版，进步空间还很大，至于插件，我感觉这东西的上限取决于大模型的上限，毕竟大部分的插件最后都是丢给模型去写的，个人还是保持乐观的，毕竟大模型能力还是越来越强的。

#### Skills

目前我最常用的Skill只有我自己写的test-checklist，用来手动生成测试清单，已经放在仓库里了。然后就是mattpocock的这套Skills：https://github.com/mattpocock/skills ，基本上能满足大部分的开发需求了

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
