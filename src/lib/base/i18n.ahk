; == 多语言资源 ==
class I18n {
    static Locale := "zh-CN"
    static Supported := ["zh-CN", "en-US", "ja-JP"]
    static Texts := Map(
        "zh-CN", Map(),
        "en-US", Map(
            "明日方舟帧操小助手 ArknightsFrameAssistant", "Arknights Frame Assistant", "常规作战", "Combat", "快捷操作", "Quick Actions", "卫戍协议", "Stronghold Protocol", "其他设置", "Other Settings",
            "启动与退出", "Launch & Exit", "更新", "Update", "自定义", "Custom", "日志", "Logs", "关于", "About",
            "按下时暂停", "Pause on Press", "松开时暂停", "Pause on Release", "切换倍速", "Toggle Speed", "暂停时选中", "Select while Paused",
            "技能", "Skill", "撤退", "Retreat", "视角切换", "Switch Camera", "一键技能", "One-click Skill", "暂停技能", "Paused Skill",
            "暂停撤退", "Paused Retreat", "开局自动暂停开关", "Auto-pause Toggle", "模拟左键点击", "Simulate Left Click",
            "基建快速收取", "BASE Quick Collect", "放弃行动", "Abandon Operation", "跳过招募动画/剧情", "Skip Recruitment/Story",
            "肉鸽收取道具", "Collect Integrated Strategies Items", "返回上级菜单", "Back to Previous Menu", "查看敌人", "View Enemies",
            "调度中心", "Dispatch Center", "冻结", "Freeze", "刷新", "Refresh", "准备就绪", "ready", "升级", "Upgrade",
            "出售/销毁", "Sell/Destroy", "单位撤退", "Retreat Unit", "一键撤退", "One-click Retreat", "一键出售/销毁", "One-click Sell/Destroy", "一键购买", "One-click Purchase",
            "前进", "Frame Advance", "前进 16ms", "Frame Advance 16ms", "前进 33ms", "Frame Advance 33ms", "前进 166ms", "Frame Advance 166ms",
            "点击输入框修改按键，使用【BACKSPACE/DELETE】清除按键", "Click a field to bind a key; use BACKSPACE/DELETE to clear it",
            "为避免冲突，切换到此页面时“卫戍协议”按键将被禁用", "Stronghold Protocol hotkeys are disabled on this page to avoid conflicts",
            "为避免冲突，切换到此页面时“常规作战”、“快捷操作”按键将被禁用", "Combat and Quick Actions hotkeys are disabled on this page to avoid conflicts",
            "游戏内帧率", "In-game FPS", " 切换开局自动暂停", " Toggle opening auto-pause", " 使用“返回上级菜单”放弃行动", " Use Back to Previous Menu to abandon operation",
            " 仅在关卡内启用常规作战热键（实验性）", " Enable Combat hotkeys only in stages (Experimental)",
            "若开启了游戏内的“垂直同步”，请确保上方“游戏内帧率”设置与你的屏幕刷新率保持一致", "With VSync enabled, match In-game FPS to the display refresh rate",
            "若关闭了游戏的“垂直同步”，请确保上方“游戏内帧率”设置与游戏内保持一致", "With VSync disabled, match In-game FPS to the actual game frame rate",
            "  启动与退出设置  ", "  Launch & Exit Settings  ", "语言", "Language", " 随游戏进程关闭自动退出（强烈建议开启）", " Exit automatically when the game closes (Recommended)",
            " 启动时打开设置窗口", " Open settings at startup", " 点击关闭窗口按钮时退出小助手", " Exit AFA when closing the settings window",
            " 默认启动卫戍协议方案", " Start with Stronghold", " 启动小助手时同时启动明日方舟", " Start Arknights with AFA",
            " 启动明日方舟时自动启动小助手", " Start AFA with Arknights", "识别游戏路径", "Detect Game Path", "请先启动游戏再进行识别", "Start the game before detection",
            " 游戏路径: ", " Game path: ", "  更新设置  ", "  Update Settings  ", "更新渠道", "Update Channel", "正式版", "Stable", "测试版", "Beta",
            "更新源", "Update Source", "国内源", "China Source", " 自动检查更新", " Check for updates automatically", "手动检查更新", "Check for Updates",
            "手动下载更新", "Download Update", " 使用GitHub Token: ", " Use GitHub Token: ", "只要没有提示API配额超限，就不需要使用GitHub Token", "A GitHub Token is only needed when the API rate limit is reached",
            "安全迁移失败，当前仍保留旧 Token；请重新保存设置后重试", "Secure migration failed; the old token remains. Save settings to retry",
            "Token 已加密，但旧格式清理失败；请重新保存设置后重试", "Token encrypted, but legacy cleanup failed. Save settings to retry",
            "Token 无法解密，可能来自其他 Windows 用户或电脑；请重新输入并保存", "Token cannot be decrypted. Re-enter and save it for this Windows account",
            "  自定义设置  ", "  Custom Settings  ", "点击延迟", "Click Delay", "从选中单位到按下【技能】【撤退】【出售】的间隔，单位为毫秒，太短点击会失灵", "Delay between selecting a unit and Skill/Retreat/Sell, in milliseconds",
            "启用/禁用热键快捷键", "Enable/Disable Hotkey", "过帧档位1", "Frame Advance Level 1", "过帧档位2", "Frame Advance Level 2", "过帧档位3", "Frame Advance Level 3",
            " 游戏窗口未激活时允许鼠标悬停在窗口上触发热键", " Allow hotkeys while hovering over an inactive game window", "顶部标签页", "Top Tabs", "拖动排序 · 点击眼睛切换显示", "Drag to reorder · Click the eye to show/hide",
            "（无法隐藏）", " (Always visible)", "  日志设置  ", "  Log Settings  ", "生成日志压缩包", "Create Log Archive", "打开日志文件夹", "Open Log Folder",
            " 启用调试模式（实时日志窗口，日志额外记录调试信息）", " Enable debug mode (live console and detailed logs)", "更新公告", "Changelog", "GitHub仓库", "GitHub Repository",
            "反馈与建议", "Feedback", "我的B站主页", "Bilibili Profile", "图标画师", "Icon Artist", "重置按键", "Reset Hotkeys", "保存并关闭", "Save and Close",
            "应用设置", "Apply Settings", "取消", "Cancel", "修改尚未保存或应用！", "Unsaved changes", "存在按键冲突", "Hotkey conflict detected", "修改尚未保存或应用", "Unsaved changes",
            "打开设置界面", "Open Settings", "启用/禁用热键", "Enable/Disable Hotkeys", "重启小助手", "Restart AFA", "退出", "Exit",
            "热键已启用", "Hotkeys enabled", "热键已禁用", "Hotkeys disabled", "已启用卫戍协议方案", "Stronghold Protocol enabled", "已退出卫戍协议方案", "Stronghold Protocol disabled",
            "调试日志控制台已打开", "Debug console opened", "检查中...", "Checking...", "提示", "Notice", "确定", "OK",
            "暂无更新公告，请先连接网络检查更新。", "No changelog available. Connect to the network and check for updates.", "暂无更新公告。", "No changelog available.",
            "至少保留一个功能标签页，不能隐藏全部功能标签。", "At least one feature tab must remain visible.", "AFA版本更新公告", "AFA Changelog", "直到下次更新前不再弹出", "Do not show again until the next update",
            "发现新版本", "New Version Available", "当前版本", "Current version", "最新版本", "Latest version", "检测到新版本可用！", "A new version is available!", "是否立即更新？", "Update now?",
            "是(&Y)", "Yes (&Y)", "否(&N)", "No (&N)", "忽略此版本(&I)", "Ignore Version (&I)", "下载中", "Downloading", "正在下载更新，请稍候...", "Downloading update...",
            "手动下载(&M)", "Manual Download (&M)", "取消下载(&C)", "Cancel Download (&C)", "正在取消下载...", "Cancelling download...", "下载完成", "Download Complete", "下载失败", "Download Failed", "下载取消", "Download Cancelled",
            "下载完成！程序将在重启后应用更新。", "Download complete. The update will be applied after restart.", "下载已取消。", "Download cancelled.", "检查失败", "Update Check Failed", "无需更新", "Up to Date",
            "设置已应用！", "Settings applied!", "应用成功", "Applied", "设置已保存！后续可双击右下角托盘区图标或通过右键菜单打开设置", "Settings saved. Open settings again from the tray icon.", "保存成功", "Saved",
            "重置按键设置", "Reset Hotkeys", "  确定重置*所有*按键为默认设置吗 ？", "Reset all hotkeys to their defaults?",
            "请按键", "Press a key", "鼠标后侧键", "Mouse Back Button", "鼠标前侧键", "Mouse Forward Button", "鼠标中键", "Middle Mouse Button", "鼠标右键", "Right Mouse Button",
            "滚轮向后", "Wheel Down", "滚轮向前", "Wheel Up", "滚轮向左", "Wheel Left", "滚轮向右", "Wheel Right"
        ),
        "ja-JP", Map(
            "明日方舟帧操小助手 ArknightsFrameAssistant", "アークナイツフレーム操作アシスタント", "常规作战", "通常作戦", "快捷操作", "クイック操作", "卫戍协议", "堅守協定", "其他设置", "その他の設定",
            "启动与退出", "起動と終了", "更新", "更新", "自定义", "カスタム", "日志", "ログ", "关于", "概要",
            "按下时暂停", "押下時にPause", "松开时暂停", "離した時にPause", "切换倍速", "速度切替", "暂停时选中", "Pause中に選択",
            "技能", "スキル", "撤退", "撤退", "视角切换", "視点切替", "一键技能", "ワンクリックスキル", "暂停技能", "Pauseスキル",
            "暂停撤退", "Pause撤退", "开局自动暂停开关", "開幕自動Pause切替", "模拟左键点击", "左クリックをシミュレート",
            "基建快速收取", "基地の高速収集", "放弃行动", "作戦放棄", "跳过招募动画/剧情", "募集演出/ストーリーをスキップ",
            "肉鸽收取道具", "統合戦略アイテム収集", "返回上级菜单", "前のメニューへ戻る", "查看敌人", "敵を確認",
            "调度中心", "調度センター", "冻结", "凍結", "刷新", "更新", "准备就绪", "準備完了", "升级", "レベルアップ",
            "出售/销毁", "売却/破棄", "单位撤退", "ユニット撤退", "一键撤退", "一括撤退", "一键出售/销毁", "一括売却/破棄", "一键购买", "一括購入",
            "前进", "フレーム送り", "前进 16ms", "フレーム送り 16ms", "前进 33ms", "フレーム送り 33ms", "前进 166ms", "フレーム送り 166ms",
            "点击输入框修改按键，使用【BACKSPACE/DELETE】清除按键", "入力欄をクリックしてキーを変更し、BACKSPACE/DELETE で消去します",
            "为避免冲突，切换到此页面时“卫戍协议”按键将被禁用", "競合を避けるため、このページでは堅守協定のキーが無効になります",
            "为避免冲突，切换到此页面时“常规作战”、“快捷操作”按键将被禁用", "競合を避けるため、このページでは通常作戦とクイック操作のキーが無効になります",
            "游戏内帧率", "ゲーム内FPS", " 切换开局自动暂停", " 開幕自動停止を切替", " 使用“返回上级菜单”放弃行动", " 「前のメニューへ戻る」で作戦を放棄",
            " 仅在关卡内启用常规作战热键（实验性）", " ステージ内のみ通常作戦キーを有効化（実験的）",
            "若开启了游戏内的“垂直同步”，请确保上方“游戏内帧率”设置与你的屏幕刷新率保持一致", "垂直同期を有効にした場合、ゲーム内FPSを画面のリフレッシュレートに合わせてください",
            "若关闭了游戏的“垂直同步”，请确保上方“游戏内帧率”设置与游戏内保持一致", "垂直同期を無効にした場合、ゲーム内FPSを実際のFPSに合わせてください",
            "  启动与退出设置  ", "  起動と終了の設定  ", "语言", "言語", " 随游戏进程关闭自动退出（强烈建议开启）", " ゲーム終了時に自動終了（推奨）",
            " 启动时打开设置窗口", " 起動時に設定を開く", " 点击关闭窗口按钮时退出小助手", " 設定画面を閉じた時にAFAを終了",
            " 默认启动卫戍协议方案", " 堅守協定で起動", " 启动小助手时同时启动明日方舟", " AFAと同時にアークナイツを起動",
            " 启动明日方舟时自动启动小助手", " アークナイツと同時にAFAを起動", "识别游戏路径", "ゲームパスを検出", "请先启动游戏再进行识别", "検出前にゲームを起動してください",
            " 游戏路径: ", " ゲームパス: ", "  更新设置  ", "  更新設定  ", "更新渠道", "更新チャンネル", "正式版", "正式版", "测试版", "テスト版",
            "更新源", "更新ソース", "国内源", "中国ソース", " 自动检查更新", " 更新を自動確認", "手动检查更新", "更新を確認",
            "手动下载更新", "更新をダウンロード", " 使用GitHub Token: ", " GitHub Tokenを使用: ", "只要没有提示API配额超限，就不需要使用GitHub Token", "API制限が表示されない限りGitHub Tokenは不要です",
            "安全迁移失败，当前仍保留旧 Token；请重新保存设置后重试", "安全な移行に失敗しました。再保存して再試行してください",
            "Token 已加密，但旧格式清理失败；请重新保存设置后重试", "Tokenは暗号化されましたが旧形式の削除に失敗しました。再保存してください",
            "Token 无法解密，可能来自其他 Windows 用户或电脑；请重新输入并保存", "Tokenを復号できません。このWindowsアカウントで再入力して保存してください",
            "  自定义设置  ", "  カスタム設定  ", "点击延迟", "クリック遅延", "从选中单位到按下【技能】【撤退】【出售】的间隔，单位为毫秒，太短点击会失灵", "ユニット選択からスキル/撤退/売却までの待機時間（ミリ秒）",
            "启用/禁用热键快捷键", "ホットキー有効/無効キー", "过帧档位1", "フレーム送りレベル1", "过帧档位2", "フレーム送りレベル2", "过帧档位3", "フレーム送りレベル3",
            " 游戏窗口未激活时允许鼠标悬停在窗口上触发热键", " 非アクティブ時もホットキーを許可", "顶部标签页", "上部タブ", "拖动排序 · 点击眼睛切换显示", "ドラッグで並替え・目をクリックして表示切替",
            "（无法隐藏）", "（常に表示）", "  日志设置  ", "  ログ設定  ", "生成日志压缩包", "ログ圧縮ファイルを作成", "打开日志文件夹", "ログフォルダーを開く",
            " 启用调试模式（实时日志窗口，日志额外记录调试信息）", " デバッグモードを有効化（リアルタイム表示と詳細ログ）", "更新公告", "更新履歴", "GitHub仓库", "GitHubリポジトリ",
            "反馈与建议", "フィードバック", "我的B站主页", "Bilibiliページ", "图标画师", "アイコン作者", "重置按键", "キー設定をリセット", "保存并关闭", "保存して閉じる",
            "应用设置", "設定を適用", "取消", "キャンセル", "修改尚未保存或应用！", "未保存の変更", "存在按键冲突", "キー競合があります", "修改尚未保存或应用", "未保存の変更",
            "打开设置界面", "設定を開く", "启用/禁用热键", "ホットキー有効/無効", "重启小助手", "AFAを再起動", "退出", "終了",
            "热键已启用", "ホットキーを有効化", "热键已禁用", "ホットキーを無効化", "已启用卫戍协议方案", "堅守協定を有効化", "已退出卫戍协议方案", "堅守協定を終了",
            "调试日志控制台已打开", "デバッグコンソールを開きました", "检查中...", "確認中...", "提示", "お知らせ", "确定", "確認",
            "暂无更新公告，请先连接网络检查更新。", "更新履歴がありません。ネットワークに接続して更新を確認してください。", "暂无更新公告。", "更新履歴がありません。",
            "至少保留一个功能标签页，不能隐藏全部功能标签。", "機能タブを1つ以上表示してください。", "AFA版本更新公告", "AFA更新履歴", "直到下次更新前不再弹出", "次の更新まで表示しない",
            "发现新版本", "新しいバージョン", "当前版本", "現在のバージョン", "最新版本", "最新バージョン", "检测到新版本可用！", "新しいバージョンがあります！", "是否立即更新？", "今すぐ更新しますか？",
            "是(&Y)", "はい(&Y)", "否(&N)", "いいえ(&N)", "忽略此版本(&I)", "このバージョンを無視(&I)", "下载中", "ダウンロード中", "正在下载更新，请稍候...", "更新をダウンロードしています...",
            "手动下载(&M)", "手動ダウンロード(&M)", "取消下载(&C)", "ダウンロードをキャンセル(&C)", "正在取消下载...", "キャンセル中...", "下载完成", "ダウンロード完了", "下载失败", "ダウンロード失敗", "下载取消", "ダウンロードキャンセル",
            "下载完成！程序将在重启后应用更新。", "ダウンロードが完了しました。再起動後に更新されます。", "下载已取消。", "ダウンロードをキャンセルしました。", "检查失败", "更新確認失敗", "无需更新", "最新版です",
            "设置已应用！", "設定を適用しました！", "应用成功", "適用完了", "设置已保存！后续可双击右下角托盘区图标或通过右键菜单打开设置", "設定を保存しました。タスクトレイから再度開けます。", "保存成功", "保存完了",
            "重置按键设置", "キー設定をリセット", "  确定重置*所有*按键为默认设置吗 ？", "すべてのキー設定を初期値に戻しますか？",
            "请按键", "キーを押してください", "鼠标后侧键", "マウス後側ボタン", "鼠标前侧键", "マウス前側ボタン", "鼠标中键", "マウス中央ボタン", "鼠标右键", "マウス右ボタン",
            "滚轮向后", "ホイール下", "滚轮向前", "ホイール上", "滚轮向左", "ホイール左", "滚轮向右", "ホイール右"
        )
    )

    static Init(locale := "") {
        if (locale = "")
            locale := Config.GetImportant("Language")
        this.SetLocale(locale)
    }

    static SetLocale(locale) {
        this.Locale := "zh-CN"
        for supported in this.Supported {
            if (supported = locale) {
                this.Locale := locale
                break
            }
        }
    }

    static T(text) {
        if (this.Locale = "zh-CN")
            return text
        if (text = "卫戍协议")
            return this.Locale = "ja-JP" ? "堅守協定" : "Stronghold Protocol"
        if (text = "肉鸽")
            return this.Locale = "ja-JP" ? "統合戦略" : "Integrated Strategies"
        if (text = "基建")
            return this.Locale = "ja-JP" ? "基地" : "BASE"
        switch text {
            case "查看敌人": return this.Locale = "ja-JP" ? "敵を確認" : "View Enemies"
            case "升级": return this.Locale = "ja-JP" ? "レベルアップ" : "Upgrade"
            case "出售/销毁": return this.Locale = "ja-JP" ? "売却/破棄" : "Sell/Destroy"
            case "单位撤退": return this.Locale = "ja-JP" ? "ユニット撤退" : "Retreat Unit"
            case "一键撤退": return this.Locale = "ja-JP" ? "一括撤退" : "One-click Retreat"
            case "一键出售/销毁": return this.Locale = "ja-JP" ? "一括売却/破棄" : "One-click Sell/Destroy"
            case "一键购买": return this.Locale = "ja-JP" ? "一括購入" : "One-click Purchase"
            case "模拟左键点击": return this.Locale = "ja-JP" ? "左クリックをシミュレート" : "Simulate Left Click"
        }
        table := this.Texts[this.Locale]
        return table.Has(text) ? table[text] : text
    }

    static LanguageOptions() {
        return [this.T("简体中文"), this.T("English"), this.T("日本語")]
    }

    static LocaleIndex(locale := "") {
        locale := locale = "" ? this.Locale : locale
        for i, supported in this.Supported
            if (supported = locale)
                return i
        return 1
    }

    static LocaleFromIndex(index) {
        for i, supported in this.Supported
            if (i = index)
                return supported
        return "zh-CN"
    }

    static RefreshControl(control) {
        try {
            if (control.Type = "Text" || control.Type = "Button" || control.Type = "Checkbox") {
                source := this.SourceText(control.Text)
                control.Text := this.T(source)
            }
        }
    }

    static SourceText(text) {
        for _, table in this.Texts {
            for source, translated in table {
                if (translated = text)
                    return source
            }
        }
        return text
    }
}
