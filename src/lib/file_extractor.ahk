; 文件提取模块 - 管理所有编译时嵌入文件的运行时提取

class FileExtractor {
    static BaseDir := A_AppData "\ArknightsFrameAssistant\PC"

    static LogoPath      := FileExtractor.BaseDir "\logo.ico"
    static TakeOver1Path := FileExtractor.BaseDir "\TakeOverButton_1.png"
    static TakeOver2Path := FileExtractor.BaseDir "\TakeOverButton_2.png"
    static TakeOver3Path := FileExtractor.BaseDir "\TakeOverButton_3.png"

    ; 确保所有嵌入文件已提取到 AppData
    static EnsureExtracted() {
        ; logo.ico（含大小校验，防止旧版本残留）
        if (!FileExist(FileExtractor.LogoPath) || FileGetSize(FileExtractor.LogoPath) != 341766)
            FileInstall "..\logo.ico", FileExtractor.LogoPath, 1

        ; 代理指挥按钮图像（用于开局暂停后识别伪暂停）
        if (!FileExist(FileExtractor.TakeOver1Path))
            FileInstall "resources\images\TakeOverButton_1.png", FileExtractor.TakeOver1Path, 1
        if (!FileExist(FileExtractor.TakeOver2Path))
            FileInstall "resources\images\TakeOverButton_2.png", FileExtractor.TakeOver2Path, 1
        if (!FileExist(FileExtractor.TakeOver3Path))
            FileInstall "resources\images\TakeOverButton_3.png", FileExtractor.TakeOver3Path, 1
    }
}
