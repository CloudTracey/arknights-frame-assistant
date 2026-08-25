; == 区服元数据与识别 ==
; 纯数据 + 纯函数：负责从游戏安装目录 / 可执行文件推断区服，
; 并给出对应 Unity PlayerPrefs 注册表根。
; 不引用 core/ui，不产生副作用。

class ServerProfile {

    ; 所有区服客户端可执行文件名相同（事实基线）
    static ExeName := "Arknights.exe"

    ; 内置区服元数据表。
    ; DirectoryHint 用于目录特征识别（也是 CN/BILI 区分的唯一手段）与无进程时按特征扫描。
    ; ScanPaths（可选）表示 <安装父目录>\<该路径> 形态的可执行文件候选路径，
    ; 默认为 <DirectoryHint>\Arknights.exe；BILI（哔哩哔哩渠道客户端）布局特殊，需要覆盖。
    ; BILI 与 CN 共享 company/product（HyperGryph\Arknights），因而注册表根与
    ; 游戏内按键设置完全相同（两者互通），仅安装目录特征不同。
    static Profiles := Map(
        "CN", {Id: "CN", DisplayNameKey: "国服", Company: "HyperGryph", Product: "Arknights", DirectoryHint: "Arknights Game", Locale: "zh-CN"},
        "BILI", {Id: "BILI", DisplayNameKey: "哔哩哔哩服", Company: "HyperGryph", Product: "Arknights", DirectoryHint: "Arknights bilibili", Locale: "zh-CN", ScanPaths: ["Arknights bilibili\games\Arknights\Arknights.exe"]},
        "JP", {Id: "JP", DisplayNameKey: "日服", Company: "Yostar", Product: "Arknights_JP", DirectoryHint: "Arknights_JP", Locale: "ja-JP"},
        "KR", {Id: "KR", DisplayNameKey: "韩服", Company: "Yostar", Product: "Arknights_KR", DirectoryHint: "Arknights_KR", Locale: "ko-KR"},
        "EN", {Id: "EN", DisplayNameKey: "国际服", Company: "Yostar", Product: "Arknights_EN", DirectoryHint: "Arknights_EN", Locale: "en-US"}
    )

    ; 按 serverId 获取元数据；不存在返回 ""
    static Get(serverId) {
        if this.Profiles.Has(serverId)
            return this.Profiles[serverId]
        return ""
    }

    ; 已知区服 id 列表（保持表顺序）
    static Ids() {
        result := []
        for id, _ in this.Profiles
            result.Push(id)
        return result
    }

    ; 从可执行文件完整路径推断区服。
    ; 返回对象：{serverId, company, product, registryRoot, source}
    ; 识别顺序：
    ;  1. 安装目录特征（权威）：CN 与 BILI 共享 company/product，app.info 完全相同，
    ;     只有目录特征能区分渠道；其余区服的目录特征与 app.info 结果一致，先查不影响结论。
    ;  2. app.info（兜底）：目录被移动/重命名后仍可识别；命中 CN 的 app.info 与 BILI 语义等价
    ;     （共享注册表根与按键设置）。
    ;  3. 注册表存在性：某服注册表根下存在 KEYBOARD_SETTING_V* 时优先。
    static FromExePath(exePath) {
        if (exePath = "")
            return this._Unknown("", "")

        SplitPath(exePath, &fileName, &exeDir)
        if (StrLower(fileName) != "arknights.exe")
            exeDir := exePath  ; 调用方可能直接传入游戏目录

        ; 1. 安装目录特征（BILI 与 CN 共用 app.info，必须先于 app.info 判定）
        for serverId, profile in this.Profiles {
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

        ; 2. app.info 权威识别（目录被移动/重命名后的兜底）
        appInfo := this._ReadAppInfo(exeDir)
        if (appInfo.company != "" && appInfo.product != "") {
            for serverId, profile in this.Profiles {
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

        ; 3. 注册表存在性：某服注册表根下有 KEYBOARD_SETTING_V* 时优先
        for serverId, profile in this.Profiles {
            if (this._RegistryHasKeyboardSetting(serverId)) {
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

    ; 从游戏目录（含 Arknights.exe 的目录）推断区服
    static FromGameDir(gameDir) {
        if (gameDir = "")
            return this._Unknown("", "")
        return this.FromExePath(gameDir "\Arknights.exe")
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
    ; 目录特征：CN=Arknights Game，BILI=Arknights bilibili（games\Arknights 子目录布局），
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

            ; 常见启动器/安装目录
            for parent in ["YostarGames", "Hypergryph Launcher"] {
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
