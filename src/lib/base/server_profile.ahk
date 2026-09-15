; == 区服元数据与识别 ==
; 纯数据 + 纯函数：负责从游戏安装目录 / 可执行文件推断区服，
; 并给出对应 Unity PlayerPrefs 注册表根。
; 不引用 core/ui，不产生副作用。

class ServerProfile {

    ; 所有区服客户端可执行文件名相同（事实基线）
    static ExeName := "Arknights.exe"

    ; 内置区服元数据表（仅用于按 id 查找，不要用它推导枚举顺序）。
    ; AHK v2 Map 的 for 枚举顺序是哈希序而非插入序（实测 BILI/CN/EN/JP/KR 乱序），
    ; 因此所有需要顺序的遍历必须走 Order（CN 优先：CN 与 BILI 共享 company/product，
    ; 兜底匹配时默认展示为官服）。
    ; DirectoryHint 用于目录特征识别；ScanPaths 用于无进程时按特征扫描（相对安装父目录）。
    ; TC（繁中服）的 company/product 取自游戏本体 Arknights_Data\app.info 的实测值
    ; （对应 Unity persistentDataPath 为 AppData\LocalLow\Gryphline\Arknights_TC）。
    ; Company 必须保持 app.info 的拼写 "Gryphline"：启动器写的是 HKCU\Software\GRYPHLINK\Launcher，
    ; 实测这两个键在 HKCU\Software 下并存（仅大小写不同），而注册表查找对精确拼写优先——用 "GRYPHLINK"
    ; 会落到启动器那个键上、读不到 Arknights_TC 子键（等价于把 TC 判成未安装）。
    static Profiles := Map(
        "CN", {Id: "CN", DisplayNameKey: "国服", Company: "HyperGryph", Product: "Arknights", DirectoryHint: "Arknights Game", Locale: "zh-CN", ScanPaths: ["Arknights Game\Arknights.exe", "games\Arknights\Arknights.exe"]},
        "BILI", {Id: "BILI", DisplayNameKey: "哔哩哔哩服", Company: "HyperGryph", Product: "Arknights", DirectoryHint: "Arknights bilibili", Locale: "zh-CN", ScanPaths: ["Arknights bilibili\games\Arknights\Arknights.exe"]},
        "TC", {Id: "TC", DisplayNameKey: "繁中服", Company: "Gryphline", Product: "Arknights_TC", DirectoryHint: "Arknights_TC", Locale: "zh-Hant"},
        "JP", {Id: "JP", DisplayNameKey: "日服", Company: "Yostar", Product: "Arknights_JP", DirectoryHint: "Arknights_JP", Locale: "ja-JP"},
        "KR", {Id: "KR", DisplayNameKey: "韩服", Company: "Yostar", Product: "Arknights_KR", DirectoryHint: "Arknights_KR", Locale: "ko-KR"},
        "EN", {Id: "EN", DisplayNameKey: "国际服", Company: "Yostar", Product: "Arknights_EN", DirectoryHint: "Arknights_EN", Locale: "en-US"}
    )

    ; 区服优先级/枚举序（新增区服必须同步登记到此处与 Profiles）。
    ; CN 优先于 BILI：两者共享 company/product 与注册表根，兜底时默认展示为官服；
    ; BILI 安装目录必然含 "Arknights bilibili"，由目录特征先行命中，不冲突。
    ; TC 与任何区服都不共享 company/product，顺序仅决定 GUI 总览中的展示次序（中文区服相邻）。
    static Order := ["CN", "BILI", "TC", "JP", "KR", "EN"]

    ; 按 serverId 获取元数据；不存在返回 ""
    static Get(serverId) {
        if this.Profiles.Has(serverId)
            return this.Profiles[serverId]
        return ""
    }

    ; 已知区服 id 列表（显式顺序；不要用 for 迭代 Profiles Map 推导顺序——
    ; AHK v2 Map 枚举顺序是哈希序而非插入序，见 Order 注释）
    static Ids() {
        result := []
        for id in this.Order
            result.Push(id)
        return result
    }

    ; 全部游戏路径配置项的有序列表（旧 GamePath 在前，其后按 Order 的 GamePath<Id>）。
    ; 供「保存校验」与「识别前清理」共用，保证两处判定范围一致。
    ; 返回数组元素：{key, serverId, name（区服显示名，旧 GamePath 为 ""）}
    static AllGamePathEntries() {
        entries := [{key: "GamePath", serverId: "", name: ""}]
        for serverId in this.Ids() {
            profile := this.Get(serverId)
            entries.Push({
                key: "GamePath" serverId,
                serverId: serverId,
                name: profile != "" ? I18n.T(profile.DisplayNameKey) : serverId
            })
        }
        return entries
    }

    ; 从可执行文件完整路径推断区服。
    ; 返回对象：{serverId, company, product, registryRoot, source}
    ; 识别顺序：
    ;  0. XelLauncher 链接运行环境（`.xel-linked-runtime\<...>\<渠道>\`）：渠道段目录名即权威渠道
    ;     （Official→CN、Bilibili→BILI）；见 _DetectXelLinkedRuntime。
    ;  1. 安装目录特征（权威）：CN 与 BILI 共享 company/product，app.info 完全相同，
    ;     只有目录特征能区分渠道；其余区服的目录特征与 app.info 结果一致，先查不影响结论。
    ;  2. app.info（兜底）：目录被移动/重命名后仍可识别；命中 CN 的 app.info 与 BILI 语义等价
    ;     （共享注册表根与按键设置）。
    ;  3. 注册表存在性：某服注册表根下存在 KEYBOARD_SETTING_V* 时优先。
    static FromExePath(exePath) {
        if (exePath = "")
            return this._Unknown("", "")

        SplitPath(exePath, &fileName, &exeDir)
        if (StrLower(fileName) != StrLower(this.ExeName)) {
            ; 本方法只接受“名为 Arknights.exe 的文件”；调用方传入游戏目录时请用 FromGameDir。
            ; 不能容忍其他输入形式：传入目录或以反斜杠结尾时 SplitPath 会让 fileName 为空，
            ; 于是校验被绕过，且后续第 3 步注册表兜底只看本机有没有某服按键设置、与传入路径无关，
            ; 会把 C:\Windows\System32 这类无关目录判成已安装的那个区服。
            return this._Unknown("", "")
        }

        ; 0. XelLauncher「硬链接共享运行环境」的渠道特征（最高优先级，见 _DetectXelLinkedRuntime）
        xelServerId := this._DetectXelLinkedRuntime(exeDir)
        if (xelServerId != "") {
            profile := this.Get(xelServerId)
            return {
                serverId: xelServerId,
                company: profile.Company,
                product: profile.Product,
                registryRoot: "HKCU\Software\" profile.Company "\" profile.Product,
                source: "xel_linked_runtime"
            }
        }

        ; 1. 安装目录特征（BILI 与 CN 共用 app.info，目录特征先行；按 Order 显式顺序遍历）
        for serverId in this.Order {
            profile := this.Get(serverId)
            if (profile.DirectoryHint != "" && InStr(exeDir, profile.DirectoryHint, false)) {
                return {
                    serverId: serverId,
                    company: profile.Company,
                    product: profile.Product,
                    registryRoot: "HKCU\Software\" profile.Company "\" profile.Product,
                    source: "directory_hint"
                }
            }
        }

        ; 2. app.info 权威识别（目录被移动/重命名后的兜底；按 Order 显式顺序匹配）
        appInfo := this._ReadAppInfo(exeDir)
        if (appInfo.company != "" && appInfo.product != "") {
            for serverId in this.Order {
                profile := this.Get(serverId)
                if (StrLower(profile.Company) = StrLower(appInfo.company)
                    && StrLower(profile.Product) = StrLower(appInfo.product)) {
                    return {
                        serverId: serverId,
                        company: appInfo.company,
                        product: appInfo.product,
                        registryRoot: "HKCU\Software\" appInfo.company "\" appInfo.product,
                        source: "app_info"
                    }
                }
            }
            ; app.info 有值但不在内置表：按新服处理，直接用 company/product 拼注册表根
            return {
                serverId: "Unknown",
                company: appInfo.company,
                product: appInfo.product,
                registryRoot: "HKCU\Software\" appInfo.company "\" appInfo.product,
                source: "app_info_unknown"
            }
        }

        ; 3. 注册表存在性：某服注册表根下有 KEYBOARD_SETTING_V* 时优先（同样按 Order；与 CN 同根时 CN 优先）
        for serverId in this.Order {
            if (this._RegistryHasKeyboardSetting(serverId)) {
                profile := this.Get(serverId)
                return {
                    serverId: serverId,
                    company: profile.Company,
                    product: profile.Product,
                    registryRoot: "HKCU\Software\" profile.Company "\" profile.Product,
                    source: "registry"
                }
            }
        }

        ; 4. 完全无法识别
        return this._Unknown("", "")
    }

    ; 识别 XelLauncher「硬链接共享运行环境」（.xel-linked-runtime）生成的运行目录，
    ; 返回渠道对应的区服 id；不是这种布局时返回 ""（调用方继续走原有识别链）。
    ;
    ; 目录约定（Xel-Launcher Helpers/LinkedRuntimeService.GetRuntimePath）：
    ;   <物理安装的父目录>\.xel-linked-runtime\<GameId>\<sharedRootId>\<渠道>\Arknights.exe
    ;   - 容器名 .xel-linked-runtime 为源码常量；
    ;   - GameId 固定为 Arknights，sharedRootId 为物理安装路径的哈希；
    ;   - 渠道取自 GameChannelCatalog 的 Channel 字段：Official / Bilibili。
    ;
    ; 为什么必须按渠道段判定：渠道段的目录名是本次运行客户端渠道的权威身份。硬链接只覆盖
    ; Arknights_Data 下内容一致的资源文件，Arknights.exe 与 SDK/config 等渠道差异文件是各渠道
    ; 独立文件，因此运行目录归属只取决于渠道段，与祖先目录叫什么无关。
    ; 而 path 上的目录特征（步骤 1）无法承担这个判定：物理安装为 B服 时其父目录名必然含
    ; "Arknights bilibili"，官服渠道的运行目录路径也会带上该子串而被判成 BILI；且 CN 与 BILI 的
    ; app.info 同为 HyperGryph/Arknights，靠 app.info 兜底也无法区分这两个渠道。
    ;
    ; 健壮性约定：只按**固定位置**取段（容器段之后第 3 段 = 渠道段），不做全路径子串匹配，
    ; 否则祖先目录名会再次污染判定；渠道段名字变了或段数不足时返回 ""，回落既有识别链。
    static _DetectXelLinkedRuntime(exeDir) {
        if (exeDir = "" || !InStr(exeDir, ".xel-linked-runtime", false))
            return ""
        parts := StrSplit(exeDir, "\")
        for index, part in parts {
            if (part != "" && InStr(part, ".xel-linked-runtime", false)) {
                ; 渠道段 = 容器段之后第 3 段：中间还有 GameId 与 sharedRootId 两段
                channelIndex := index + 3
                if (channelIndex > parts.Length)
                    return ""
                channel := parts[channelIndex]
                if (channel = "")
                    return ""
                if (StrLower(channel) = "official")
                    return "CN"
                if (StrLower(channel) = "bilibili")
                    return "BILI"
                return ""
            }
        }
        return ""
    }

    ; 从游戏目录（含 Arknights.exe 的目录）推断区服；传目录的调用方用这个方法
    static FromGameDir(gameDir) {
        if (gameDir = "")
            return this._Unknown("", "")
        ; 去掉结尾反斜杠，避免拼出双反斜杠；FromExePath 只接受 exe 文件路径
        gameDir := RTrim(gameDir, "\")
        return this.FromExePath(gameDir "\" this.ExeName)
    }

    ; 根据 serverId 返回注册表根；Unknown 或未知 id 返回 ""
    static RegistryRoot(serverId) {
        profile := this.Get(serverId)
        if (profile = "")
            return ""
        return "HKCU\Software\" profile.Company "\" profile.Product
    }

    ; 根据 company/product 返回注册表根
    static RegistryRootByCompanyProduct(company, product) {
        if (company = "" || product = "")
            return ""
        return "HKCU\Software\" company "\" product
    }

    ; 在不启动游戏的情况下，按已知目录特征扫描常见位置，返回 serverId → exePath。
    ; 目录特征：CN=Arknights Game / games\Arknights（Hypergryph Launcher 布局），
    ; BILI=Arknights bilibili（games\Arknights 子目录布局），TC=Arknights_TC
    ; （Gryphline Launcher 布局：<启动器目录>\games\Arknights_TC\Arknights.exe），
    ; JP/KR/EN=Arknights_JP|KR|EN。
    static FindInstalledPaths() {
        result := Map()
        for serverId in this.Ids() {
            path := this._FindServerPath(serverId)
            if (path != "")
                result[serverId] := path
        }
        return result
    }

    ; 在固定磁盘常见父目录中查找指定区服的可执行文件。
    static _FindServerPath(serverId) {
        profile := this.Get(serverId)
        if (profile = "")
            return ""
        dirName := profile.DirectoryHint
        if (dirName = "")
            return ""

        ; 如果用户已经配置过该区服路径且文件仍存在，优先保留用户选择
        configured := Config.GetImportant("GamePath" serverId)
        if (configured != "" && FileExist(configured))
            return configured

        ; 兼容旧版单一 GamePath：若旧路径能推断为当前区服，也优先使用
        legacy := Config.GetImportant("GamePath")
        if (legacy != "" && FileExist(legacy)) {
            legacyInfo := this.FromExePath(legacy)
            if (legacyInfo.serverId = serverId)
                return legacy
        }

        ; 可执行文件相对安装父目录的候选路径。
        ; 默认 "<DirectoryHint>\Arknights.exe"；BILI 渠道布局为
        ; <Arknights bilibili>\games\Arknights\Arknights.exe，由 ScanPaths 覆盖。
        scanPaths := profile.HasOwnProp("ScanPaths") ? profile.ScanPaths : [dirName "\Arknights.exe"]

        for drive in this._FixedDriveLetters() {
            root := drive ":\"
            ; 直接位于盘符根目录，例如 E:\Arknights Game\Arknights.exe
            for scanPath in scanPaths {
                candidate := root scanPath
                if FileExist(candidate)
                    return candidate
            }

            ; 常见启动器/安装目录。GRYPHLINK = 繁中服 Gryphline Launcher 的安装目录名，
            ; 游戏位于其 <启动器目录>\games\Arknights_TC\ 下。
            ; 扫描范围注意：parent 只在**每个固定盘的根目录**下匹配，即只覆盖
            ; <盘符>:\GRYPHLINK\games\Arknights_TC\Arknights.exe 这类布局；启动器装在更深层级
            ; （如 D:\Tools\GRYPHLINK\）时扫不到——这是所有区服共有的既有扫描限制（整盘有界递归
            ; 在多区服版本试过后回退：深层路径仍未识别且「识别游戏路径」界面卡死，见
            ; test/test_multi_server_and_i18n.md 问题7），此时靠启动一次游戏由进程路径识别，
            ; 或手动填「游戏路径」后由启动迁移写入 GamePath<Id>。
            for parent in ["YostarGames", "Hypergryph Launcher", "GRYPHLINK"] {
                for scanPath in scanPaths {
                    candidate := root parent "\" scanPath
                    if FileExist(candidate)
                        return candidate
                    candidate := root parent "\games\" scanPath
                    if FileExist(candidate)
                        return candidate
                }
            }
        }
        return ""
    }

    ; 获取固定磁盘盘符列表
    static _FixedDriveLetters() {
        result := []
        list := DriveGetList("FIXED")
        for letter in StrSplit(list)
            result.Push(letter)
        return result
    }

    ; 检查某个区服的注册表根是否存在（用于避免对未安装区服弹警告）
    static RegistryRootExists(serverId) {
        return this._RegistryKeyExists(this.RegistryRoot(serverId))
    }

    ; 检查某服注册表根下是否存在 KEYBOARD_SETTING_V* 键值（推断用）
    static _RegistryHasKeyboardSetting(serverId) {
        root := this.RegistryRoot(serverId)
        if (root = "" || !this._RegistryKeyExists(root))
            return false
        try {
            Loop Reg, root, "V" {
                if (InStr(A_LoopRegName, "KEYBOARD_SETTING_V") = 1)
                    return true
            }
        } catch Error as e {
            Logger.Debug("ServerProfile", "注册表按键设置检查失败：" root " - " e.Message)
        }
        return false
    }

    ; 通过 RegOpenKeyEx 判断注册表键是否存在，比 Loop Reg 更可靠
    static _RegistryKeyExists(root) {
        if (root = "")
            return false
        rootHandle := 0
        subkey := ""
        if RegExMatch(root, "i)^HKCU\\", &m)
            rootHandle := 0x80000001 ; HKEY_CURRENT_USER
        else if RegExMatch(root, "i)^HKLM\\", &m)
            rootHandle := 0x80000002 ; HKEY_LOCAL_MACHINE
        else if RegExMatch(root, "i)^HKCR\\", &m)
            rootHandle := 0x80000000 ; HKEY_CLASSES_ROOT
        else if RegExMatch(root, "i)^HKU\\", &m)
            rootHandle := 0x80000003 ; HKEY_USERS
        else if RegExMatch(root, "i)^HKCC\\", &m)
            rootHandle := 0x80000005 ; HKEY_CURRENT_CONFIG
        else
            return false

        ; 去掉 "HKCU" 等前缀，得到子键路径
        if RegExMatch(root, "i)^[A-Z]+\\", &m)
            subkey := SubStr(root, m.Len[0] + 1)
        if (subkey = "")
            return true

        phk := 0
        ; KEY_READ = 0x20019
        result := DllCall("Advapi32\RegOpenKeyExW", "Ptr", rootHandle, "Str", subkey, "UInt", 0, "UInt", 0x20019, "Ptr*", &phk, "Int")
        if (result = 0) {
            DllCall("Advapi32\RegCloseKey", "Ptr", phk)
            return true
        }
        return false
    }

    ; 读取 <exeDir>\Arknights_Data\app.info
    ; 文件两行分别为 Unity companyName / productName；容忍 BOM 和空行。
    static _ReadAppInfo(exeDir) {
        result := {company: "", product: ""}
        path := exeDir "\Arknights_Data\app.info"
        if !FileExist(path)
            return result
        try {
            file := FileOpen(path, "r")
            if !IsObject(file)
                return result
            try {
                line := file.ReadLine()
                result.company := Trim(StrReplace(line, Chr(0xFEFF), ""))
                line := file.ReadLine()
                result.product := Trim(StrReplace(line, Chr(0xFEFF), ""))
            } finally {
                file.Close()
            }
        } catch Error as e {
            ; 读取失败保持空，交给目录特征回退
            Logger.Warn("ServerProfile", "读取 app.info 失败：" e.Message)
        }
        return result
    }

    static _Unknown(company, product) {
        return {
            serverId: "Unknown",
            company: company,
            product: product,
            registryRoot: (company != "" && product != "") ? ("HKCU\Software\" company "\" product) : "",
            source: "unknown"
        }
    }
}
