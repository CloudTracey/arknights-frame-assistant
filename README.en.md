<div align="center">

[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [English](README.en.md)

<img alt="LOGO" src="./logo.png" width="256" height="256" />

# Arknights Frame Assistant

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-orange.svg)](https://spdx.org/licenses/GPL-3.0-only.html)
[![Language: AutoHotkey v2](https://img.shields.io/badge/Language-AutoHotkey_v2-6594B9.svg)](https://www.autohotkey.com/)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
<img alt="stars" src="https://img.shields.io/github/stars/CloudTracey/arknights-frame-assistant?style=social">
<img alt="GitHub all releases" src="https://img.shields.io/github/downloads/CloudTracey/arknights-frame-assistant/total?style=social">

Welcome to **Arknights Frame Assistant** (AFA), a small Windows utility for improving the Arknights PC experience. It provides fully customizable hotkeys, Frame Advance, Quick Actions, and Stronghold Protocol operations.
</div>

<br>


> ⚠️ **Note:** This document and the in-app descriptions are mostly AI-translated and may be inaccurate. Issues and pull requests are welcome to help correct them.

## Contents

- [Download and Start](#download-and-start)
- [Features](#features)
  - [Frame Advance and Precise Operations](#frame-advance-and-precise-operations)
  - [Quick Actions](#quick-actions)
  - [Stronghold Protocol Operations](#stronghold-protocol-operations)
  - [Fully Customizable Hotkeys](#fully-customizable-hotkeys)
  - [Other Settings](#other-settings)
- [Notes](#notes)
  - [Arknights Process Only](#arknights-process-only)
  - [In-game Key Bindings](#in-game-key-bindings)
  - [In-game Frame Rate](#in-game-frame-rate)
  - [Security Notice](#security-notice)
- [FAQ](#faq)
- [Contributing](#contributing)
- [Declaration](#declaration)
- [Acknowledgements](#acknowledgements)

<br>

## Download and Start

1. Download the latest executable from the [GitHub Releases page](https://github.com/CloudTracey/arknights-frame-assistant/releases).
2. Start AFA with the game; either order is supported, or enable automatic startup in settings.
3. Customize the hotkeys and settings you need.
4. Click **Save and Close** or **Apply Settings**. Changes take effect in the game.

<br>

## Features

### Frame Advance and Precise Operations

| Feature | Description |
|------|------|
| One-click Skill | Activate the skill of the unit under the mouse cursor |
| One-click Retreat | Retreat the unit under the mouse cursor |
| Select while Paused | Select the unit under the cursor at 0 frames while paused |
| Paused Skill | Activate the skill of the unit under the mouse cursor at 0 frames while paused |
| Paused Retreat | Retreat the unit under the mouse cursor at 0 frames while paused |
| Frame Advance 16ms | Advance one logical frame at 2x speed |
| Frame Advance 33ms | Advance one logical frame at 1x speed (30 logical frames per second) |
| Frame Advance 166ms | Advance one logical frame at 0.2x speed when a unit or the deployment area is selected |
| Switch Camera | Move the camera to a unit without selecting it while paused |
| Opening Auto-pause | Automatically pause when combat starts |

### Quick Actions

| Feature | Description |
|------|------|
| Simulate Left Click | Simulate a left mouse click |
| Abandon Operation | Abandon the current combat operation |
| Skip Recruitment/Story | Click the skip button for recruitment animations or story scenes |
| Back to Previous Menu | Return to the previous menu |
| BASE Quick Collect | Click BASE collection buttons, such as Manufacturing or Trading Post products |
| Collect Integrated Strategies Items | Click the “Collect” button in Integrated Strategies |

### Stronghold Protocol Operations

| Feature | Description |
|------|------|
| View Enemies | View enemy details |
| Dispatch Center | Open the Dispatch Center |
| Freeze | Freeze a unit |
| Refresh | Refresh the shop |
| Upgrade | Upgrade the shop |
| Sell/Destroy | Sell a unit or destroy equipment |
| Ready | Mark the operation ready |
| Retreat Unit | Retreat a unit |
| One-click Retreat | Select and retreat the unit under the mouse cursor |
| One-click Sell/Destroy | Select and sell/destroy the unit under the cursor |
| One-click Purchase | Double-click to purchase the unit under the cursor |
| Back to Previous Menu | Return to the previous menu |

> **Note:** Stronghold Protocol is mutually exclusive with Combat and Quick Actions. Their hotkeys are disabled while the Stronghold Protocol page is active.

### Fully Customizable Hotkeys

Supported default bindings:

**Combat:**

| Feature | Default | Feature | Default |
|------|----------|------|----------|
| Pause on Press | F | Frame Advance 33ms | R |
| Pause on Release | Space | Frame Advance 166ms | T |
| Toggle Speed | D | One-click Skill | E |
| Select while Paused | W | One-click Retreat | Q |
| Unit Skill | S | Paused Skill | Mouse Forward Button |
| Unit Retreat | A | Paused Retreat | Mouse Back Button |
| Switch Camera | None | Opening Auto-pause Toggle | None |
| Frame Advance 16ms | None | | |

**Quick Actions:**

| Feature | Default | Feature | Default |
|------|----------|------|----------|
| Simulate Left Click | Z | Abandon Operation | None |
| Skip Recruitment/Story | None | BASE Quick Collect | None |
| Back to Previous Menu | None | Collect Integrated Strategies Items | None |

**Stronghold Protocol:**

| Feature | Default | Feature | Default |
|------|----------|------|----------|
| View Enemies | W | Upgrade | G |
| Dispatch Center | A | Sell/Destroy | X |
| Freeze | S | Ready | C |
| Refresh | D | Left Click | None |
| Retreat Unit | Q | One-click Retreat | None |
| One-click Sell/Destroy | None | One-click Purchase | None |
| Back to Previous Menu | None | | |

- Most keyboard keys are supported.
- Mouse buttons other than left click are supported, including the wheel and side buttons.
- Use `BACKSPACE/DELETE` to clear a binding.
- Conflicts are detected in real time and conflicting fields are marked red. Resolve conflicts before saving.

### Other Settings

| Setting | Description |
|------|------|
| **Automatic Updates** | Automatically check for and download updates |
| **Update Source** | Choose China Source or GitHub; China Source is the default and failed checks fall back to the other source |
| **Language** | Switch the interface between Simplified Chinese, Traditional Chinese, Japanese, Korean, and English |
| **Start Arknights with AFA** | Start the game with AFA; a game path is required |
| **Start AFA with Arknights** | Start AFA automatically with the game; a game path is required. AFA reads and calibrates Windows process-creation auditing and the current-user scheduled task as needed |
| **Exit with Game Process** | Exit AFA automatically when the game closes |
| **Open Settings at Startup** | Show the settings window at startup |
| **Exit when Window Closes** | Exit AFA when the settings window is closed with X or Alt+F4; otherwise hide it in the tray |
| **Start with Stronghold Protocol** | Use Stronghold Protocol as the default startup scheme |
| **Top Tab Management** | In Display, use eye icons to toggle tab visibility and drag to reorder tabs; Other Settings always remains visible. The order and visibility take effect together when saved or applied, and the top bar divides evenly among visible tabs |
| **Click Delay** | Set the delay in milliseconds between selecting a unit and triggering an action |
| **Enable/Disable Hotkey** | Set the shortcut for enabling or disabling all hotkeys |
| **GitHub Token** | Increase API quota when GitHub reports a rate limit |
| **Logs and Diagnostics** | Create a redacted log archive or open the log folder |
| **Tray Menu** | Open settings, toggle hotkeys, restart, or exit from the tray icon |

<br>

## Notes

### Arknights Process Only

AFA hotkeys act only on the Arknights process (`Arknights.exe`) and do not affect other applications.

### In-game Key Bindings

AFA reads the game's key bindings and adapts automatically. If reading fails, restore these defaults in the game:

**Combat:** F for speed, E for skill, Q for retreat, V for abandon operation, Space for pause.

**Stronghold Protocol:** W for View Enemies, A for Dispatch Center, S for Freeze, D for Refresh, C for Ready, G for Upgrade, X for Sell.

### In-game Frame Rate

The in-app Frame Rate options are **30 / 60 / 90 / 120 / 144 / 165 / 180 / 240+**. Choose the actual game frame rate so Frame Advance timing remains accurate.

- At 120 Hz or above, VSync may be enabled and the 120+ option selected.
- Below 120 Hz, VSync is not recommended; keep the setting equal to the actual game frame rate. If VSync is enabled, make sure the setting matches the display's refresh rate.

### Security Notice

AFA is built with AutoHotkey. Anti-cheat systems in many MMORPGs and competitive games are sensitive to AutoHotkey tools and may misidentify them as cheats, preventing the game from starting or even causing an account ban.

We strongly recommend enabling **Exit with Game Process** (enabled by default) so that forgetting to close this tool does not trigger anti-cheat systems in other games.

When **Start AFA with Arknights** is enabled, Windows identifies `Arknights.exe` through process-creation events in the security log and uses a scheduled task with the current user's SID to start AFA. Disabling it removes the current user's scheduled task, but Windows' process-creation-success auditing setting remains enabled and may increase security log volume. Both automatic-start directions can be enabled together without recursive launches.

### If the Settings Window Was Closed

If **Exit when Window Closes** is disabled, right-click the tray icon and select **Open Settings**. If it is enabled, restart AFA after closing the window.

<br>

## FAQ

### Q: The program does not respond

A: Run AFA as administrator if required, start the game, check the tray icon (including hidden icons), and confirm **Open Settings at Startup** is enabled if you expect the window to appear.

### Q: A hotkey does not work

A: Restore the game's default bindings if AFA reported a read failure, apply or save the settings, resolve conflicts, and operate inside the game window.

### Q: What is a GitHub Token?

A: It increases GitHub API quota and is only needed when a rate-limit message appears. It is encrypted with Windows DPAPI for the current user and is no longer stored as plaintext in the configuration file. On first launch of a new version, a plaintext token from an older version is migrated automatically to the encrypted format. Moving the configuration to another user or computer normally requires entering it again.

### Q: How do I exit AFA completely?

A: Choose **Exit** from the tray menu, enable **Exit when Window Closes**, or enable **Exit with Game Process**.

### Q: How do I collect logs for a report?

A: Open Logs, select **Create Log Archive**, and attach the ZIP to the issue. Logs are stored under `%AppData%\ArknightsFrameAssistant\PC\logs`; ordinary logs and critical-error context use separate rolling files with a combined limit of 20 MiB. Exported archives remove tokens, user paths, and other sensitive data.

<br>

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](./CONTRIBUTING.md) first. User-visible changes must update all five README files and all five language resources.

<br>

## Declaration

- Licensed under the [GNU General Public License v3.0 only](https://spdx.org/licenses/GPL-3.0-only.html).
- The README format and some GUI ideas were inspired by [MAA](https://github.com/MaaAssistantArknights/MaaAssistantArknights); thanks to the project.
- For learning and communication only; do not use commercially.

## Acknowledgements

### Project Contributors

Thanks to everyone who contributes code to this project.

[![Contributors](https://contrib.rocks/image?repo=CloudTracey/arknights-frame-assistant)](https://github.com/CloudTracey/arknights-frame-assistant/graphs/contributors)

### Icon Credit

The icon was created by **[文件名错误EXE](https://www.mihuashi.com/profiles/8282001?role=painter)**. It is used with permission for this open-source project.

- Artist: https://www.mihuashi.com/profiles/8282001?role=painter
- Copyright remains with the original creator.
