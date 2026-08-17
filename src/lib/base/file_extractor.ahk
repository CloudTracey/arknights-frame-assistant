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
        Logger.Debug("FileExtractor", "嵌入资源提取完成：" FileExtractor.ResourcesDir)
    }
}
