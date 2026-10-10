; 文件提取模块 - 管理所有编译时嵌入文件的运行时提取

class FileExtractor {
    static BaseDir := A_AppData "\ArknightsFrameAssistant\PC"
    ; 嵌入资源统一提取子目录（logo/代理按钮/关卡检测模板，避免散落在 PC 根目录）
    static ResourcesDir := FileExtractor.BaseDir "\resources"

    static LogoPath      := FileExtractor.ResourcesDir "\logo.ico"
    static TakeOver1Path := FileExtractor.ResourcesDir "\TakeOverButton_1.png"
    static TakeOver2Path := FileExtractor.ResourcesDir "\TakeOverButton_2.png"
    static TakeOver3Path := FileExtractor.ResourcesDir "\TakeOverButton_3.png"

    ; logo.ico 的预期字节数。更换图标文件后，更新此值为新文件的字节数即可
    static LogoExpectedSize := 120488

    ; web 引擎资源提取目录
    static WebDir     := FileExtractor.BaseDir "\web"
    static LoaderPath := FileExtractor.WebDir "\WebView2Loader.dll"

    ; WebView2Loader.dll的预期字节数与 SHA-256。更换加载器后两者必须同时更新
    static LoaderExpectedSize := 160880
    static LoaderExpectedHash := "bf2fefaff7fd4775ea1e07328cc3142721943948f16d261fb82cbd978b7f99e2"

    ; 确保所有嵌入文件已提取到 AppData
    static EnsureExtracted() {
        ; 确保模板子目录存在（目录已存在时无副作用）
        DirCreate(FileExtractor.ResourcesDir)
        ; logo.ico（含大小校验，防止旧版本残留）
        if (!FileExist(FileExtractor.LogoPath) || FileGetSize(FileExtractor.LogoPath) != FileExtractor.LogoExpectedSize)
            FileInstall "..\logo.ico", FileExtractor.LogoPath, 1

        ; 代理指挥按钮图像（用于开局暂停后识别伪暂停）
        if (!FileExist(FileExtractor.TakeOver1Path))
            FileInstall "resources\images\TakeOverButton_1.png", FileExtractor.TakeOver1Path, 1
        if (!FileExist(FileExtractor.TakeOver2Path))
            FileInstall "resources\images\TakeOverButton_2.png", FileExtractor.TakeOver2Path, 1
        if (!FileExist(FileExtractor.TakeOver3Path))
            FileInstall "resources\images\TakeOverButton_3.png", FileExtractor.TakeOver3Path, 1

        ; web 引擎资源；失败只记 Warn 并继续——web 是可选引擎，不该拖死经典界面启动
        try {
            DirCreate(FileExtractor.WebDir)
            FileInstall "lib\ui\web\app\index.html", FileExtractor.WebDir "\index.html", 1
            if (A_PtrSize = 8 && !FileExtractor._LoaderUpToDate()) {
                FileInstall "lib\vendor\WebView2\64bit\WebView2Loader.dll", FileExtractor.LoaderPath, 1
                Logger.Info("FileExtractor", "已提取 WebView2 加载器")
            }
            Logger.Info("FileExtractor", "嵌入资源提取完成：" FileExtractor.ResourcesDir "、" FileExtractor.WebDir)
        } catch Error as e {
            Logger.Warn("FileExtractor", "web 引擎资源提取失败（" e.Message "），本次会话 web 模式将不可用")
        }
    }

    ; 路径上的加载器是否与嵌入版一致（尺寸 + 哈希）
    static LoaderIntact() {
        if !FileExist(FileExtractor.LoaderPath)
            return false
        if (FileGetSize(FileExtractor.LoaderPath) != FileExtractor.LoaderExpectedSize)
            return false
        return FileIntegrity.Sha256(FileExtractor.LoaderPath) = FileExtractor.LoaderExpectedHash
    }

    ; 提取阶段
    static _LoaderUpToDate() {
        if FileExtractor.LoaderIntact()
            return true
        if (FileExist(FileExtractor.LoaderPath) && FileGetSize(FileExtractor.LoaderPath) = FileExtractor.LoaderExpectedSize)
            Logger.Warn("FileExtractor", "已提取的 WebView2 加载器哈希与嵌入版不符，重写")
        return false
    }
}
