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
- [许可证](#许可证)

## 开发环境

本项目使用 **AutoHotkey v2** 进行开发。

### 环境要求

- **操作系统**: Windows 10/11
- **AutoHotkey**: 版本 2.0 或更高
- **编辑器**: 推荐使用 VS Code 配合 AutoHotkey v2 Language Support 扩展

### 项目结构

```
E:\AFA
├── src/
│   ├── main.ahk              # 主入口文件
│   ├── lib/
│   │   ├── gui.ahk           # GUI 相关
│   │   ├── hotkey.ahk        # 热键处理
│   │   ├── hotkey_actions.ahk # 热键动作
│   │   ├── config.ahk        # 配置管理
│   │   ├── game_monitor.ahk  # 游戏监控
│   │   ├── setting.ahk       # 设置功能
│   │   ├── eventbus.ahk      # 事件总线
│   │   ├── key_bind.ahk      # 按键绑定
│   │   ├── settings/         # 设置模块
│   │   ├── updater/          # 更新器模块
│   │   └── version.ahk       # 版本信息
│   └── lib/
├── test/                     # 测试清单
├── .github/
│   ├── workflows/            # CI/CD 工作流
│   └── CODEOWNERS            # 代码所有者
├── README.md                 # 项目说明
├── CHANGELOG.md              # 更新日志
├── LICENSE                   # 许可证
└── version.txt               # 版本文件
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

如果您发现了 bug 或有功能建议，请通过 GitHub Issues 提交。

**提交 Issue 时，请（尽量）包含以下信息：**
并不是严格要求，如果问题或者建议很简单那可以用一句话概括

1. **问题类型**: Bug 报告 / 功能请求
2. **环境信息**:
   - AFA 版本号
   - AutoHotkey 版本
   - Windows 版本
   - 游戏分辨率
3. **问题描述**: 清晰简洁地描述问题
4. **复现步骤**（Bug 报告）:
   - 步骤 1
   - 步骤 2
   - ...
5. **期望行为**: 描述您期望发生的情况
6. **实际行为**: 描述实际发生的情况
7. **截图或视频**（如适用）
8. **日志文件**（如适用）

**Issue 标签：**

- `bug`: 报告程序错误
- `enhancement`: 功能改进或新功能建议
- `documentation`: 文档相关问题
- `question`: 使用问题

### 提交功能请求

在提交新功能请求前，请先检查是否已有类似Issue。

功能请求应包含：
- 功能名称
- 功能描述
- 使用场景
- 可能的实现方案（如有）

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
- `feature/描述` - 新功能
- `bugfix/描述` - Bug 修复
- `hotfix/描述` - 紧急修复
- `docs/描述` - 文档更新

#### 开发流程

1. 编写代码并遵循上述代码规范
2. 在 `test/` 目录下创建测试清单文件
3. 本地测试您的更改，确保测试通过
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
   - 检查文件编码为 UTF-8

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

2. 在 GitHub 上创建 Pull Request，目标分支选择 `develop`

3. **PR 描述应包含：**
   - 功能/修复的简要描述
   - 相关的 Issue 编号（如有）
   - 更改的详细说明
   - 测试步骤和结果
   - 截图（如适用）

4. 等待代码审查

### 代码审查

- 所有提交都需要至少一个审查者的批准
- @CloudTracey 是项目维护者，拥有最终合并决定权
- 审查者可能会要求您进行修改，请积极响应

## 测试流程

### 测试清单创建

每次进行更改后，需要创建测试清单文件：

1. 在 `test/` 目录下创建测试清单文件
2. 文件名格式：`test_[更改主题].md`（英文）
3. 文件内每小步添加复选框，方便标记

**测试清单模板：**

```markdown
# 测试清单：[功能/修复描述]

## 测试环境
- AFA 版本: [版本号]
- AutoHotkey 版本: [版本号]
- Windows 版本: [版本]

## 测试步骤

### 测试 1: [测试项名称]
- [ ] 步骤 1: [具体操作]
- [ ] 步骤 2: [具体操作]
- [ ] 验证: [预期结果]

### 测试 2: [测试项名称]
- [ ] ...

## 测试结果
- [ ] 全部通过
- [ ] 存在问题（请详细描述）

## 问题反馈
[如有问题，在此描述]
```

### 测试完成标记

当测试完成后，在测试清单文件内将其标记为已完成

## 版本发布流程

本项目使用 [release-please](https://github.com/googleapis/release-please) 进行版本管理：

1. 遵循 Conventional Commits 规范提交代码
2. release-please 会自动修改 CHANGELOG 和版本号
3. 维护者审核后发布新版本

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

- **GitHub Issues**: 报告问题或请求功能
- **GitHub Discussions**: 一般性讨论
- **邮件**: 如有私密问题，可联系维护者

## 许可证

通过贡献代码，您同意您的贡献将在 [GNU General Public License v3.0](LICENSE) 下发布。

---

再次感谢您对本项目的贡献！

**维护者：** [@CloudTracey](https://github.com/CloudTracey)
