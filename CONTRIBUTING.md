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
│   ├── main.ahk                  # 主入口文件（程序启动点）
│   └── lib/                      # 核心库模块
│       ├── changelog/            # 更新公告模块
│       │   ├── changelog.ahk     # 更新公告核心逻辑（兼容骨架）
│       │   ├── changelog_checker.ahk  # 更新公告检查器
│       │   └── changelog_ui.ahk  # 更新公告 UI
│       ├── config.ahk            # 配置管理（Config/State/Constants 类）
│       ├── eventbus.ahk          # 事件总线（模块间解耦通信）
│       ├── file_extractor.ahk    # 嵌入资源的运行时提取
│       ├── game_auto_start.ahk   # 随明日方舟自动启动小助手
│       ├── game_keys.ahk         # 游戏按键注册表识别
│       ├── game_launcher.ahk     # 随小助手自动启动游戏
│       ├── game_monitor.ahk      # 游戏监控（自动退出 + 自动开局暂停）
│       ├── gui.ahk               # 设置窗口 GUI
│       ├── hotkey_actions.ahk    # 热键动作实现（功能函数）
│       ├── hotkey_control.ahk    # 热键注册/注销/分组切换
│       ├── key_bind.ahk          # 按键绑定（InputHook 捕获按键）
│       ├── log_exporter.ahk      # 诊断日志压缩包导出
│       ├── logger.ahk            # 双轨日志系统
│       ├── message_box.ahk       # 自定义消息框
│       ├── settings/             # 设置管理模块
│       │   ├── actions.ahk       # 设置操作（重置/保存/应用/取消）
│       │   ├── hotkey_conflict_validator.ahk  # 热键冲突验证
│       │   ├── loader.ahk        # 设置加载
│       │   ├── saver.ahk         # 设置保存（含验证逻辑）
│       │   └── settings_manager.ahk  # 设置管理器入口
│       ├── token_protector.ahk   # GitHub Token DPAPI 加密保护
│       ├── touch_injection.ahk   # Touch Injection 模拟点击
│       ├── updater/              # 自动更新模块
│       │   ├── downloader.ahk    # 更新下载器
│       │   ├── self_replacer.ahk # 自替换脚本（批处理生成）
│       │   ├── updater_manager.ahk   # 更新协调器（流程控制）
│       │   ├── updater_ui.ahk    # 更新 UI（对话框）
│       │   └── version_checker.ahk   # 版本检查器（GitHub + 国内源）
│       └── version.ahk           # 内置版本号
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

本项目**没有自动化测试框架**，所有测试均为**手工验证**。

### 测试清单创建

每次进行更改后，需要创建测试清单文件：

1. 参考模板 [test/template/test_template.md](test/template/test_template.md)（分为**单元测试**、**集成测试**、**回归测试**三部分，并包含测试环境表格）
2. 文件名格式：`test_[更改主题].md`（英文，如 `test_download_progress_bar.md`）
3. 文件内每小步添加复选框，方便逐项标记

> 测试清单模板说明：可以交由 AI 根据模板生成测试清单以节约工作量（本项目使用 Claude Code 的 `test-checklist` skill 工作流，已同步至.claude/skills目录内，开发时可沿用）。

### 测试完成标记

当测试完成后，将测试清单文件重命名为 `finished_test_[更改主题].md`（可参考 `test/` 目录下已有的 `finished_test_*.md` 文件）。

## 版本发布流程

> 该流程仅由维护者执行。

1. 更新 `src/lib/version.ahk` 中 `Version.Number` 为新的版本号
2. 按 [RELEASE_TEMPLATE.md](.github/RELEASE_TEMPLATE.md) 撰写发布说明（新增 / 改进 / 修复）
3. 在 GitHub 创建 Release（tag 形如 `v1.6.2`）
4. GitHub Action（`.github/workflows/release-sync.yml`）自动将 exe 和 version.json 同步到国内源 COS 并刷新 CDN

**版本号格式：** [语义化版本](https://semver.org/lang/zh-CN/)
- `主版本号.次版本号.修订号`（如 `1.0.0`）
- 预发布版本：`1.0.0-alpha.1`、`1.0.0-beta.1`

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
