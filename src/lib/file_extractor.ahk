; 文件提取模块 - 管理所有编译时嵌入文件的运行时提取

class FileExtractor {
    static BaseDir := A_AppData "\ArknightsFrameAssistant\PC"
    ; 嵌入资源统一提取子目录（logo/代理按钮/关卡检测模板，避免散落在 PC 根目录）
    static ResourcesDir := FileExtractor.BaseDir "\resources"

    static LogoPath      := FileExtractor.ResourcesDir "\logo.ico"
    static TakeOver1Path := FileExtractor.ResourcesDir "\TakeOverButton_1.png"
    static TakeOver2Path := FileExtractor.ResourcesDir "\TakeOverButton_2.png"
    static TakeOver3Path := FileExtractor.ResourcesDir "\TakeOverButton_3.png"
    ; 关卡检测投票模板（6 个对象，每对象含暂停态/非暂停态等多个变体，任一命中即算对象命中）
    static FeeIcon1Path     := FileExtractor.ResourcesDir "\CostIcon_1.png"
    static FeeIcon2Path     := FileExtractor.ResourcesDir "\CostIcon_2.png"
    static ExitButton1Path  := FileExtractor.ResourcesDir "\ExitLevelButton_1.png"
    static ExitButton2Path  := FileExtractor.ResourcesDir "\ExitLevelButton_2.png"
    static ExitButton3Path  := FileExtractor.ResourcesDir "\ExitLevelButton_3.png"
    static ExitButton4Path  := FileExtractor.ResourcesDir "\ExitLevelButton_4.png"
    static ExitButton5Path  := FileExtractor.ResourcesDir "\ExitLevelButton_5.png"
    static ExitButton6Path  := FileExtractor.ResourcesDir "\ExitLevelButton_6.png"
    static ExitButton7Path  := FileExtractor.ResourcesDir "\ExitLevelButton_7.png"
    static TextInLevel1Path := FileExtractor.ResourcesDir "\TextInLevel_1.png"
    static TextInLevel2Path := FileExtractor.ResourcesDir "\TextInLevel_2.png"
    static BlueCastle1Path  := FileExtractor.ResourcesDir "\BlueCastle_1.png"
    static BlueCastle2Path  := FileExtractor.ResourcesDir "\BlueCastle_2.png"
    static EnemyCount1Path  := FileExtractor.ResourcesDir "\EnemyCount_1.png"
    static EnemyCount2Path  := FileExtractor.ResourcesDir "\EnemyCount_2.png"
    static PauseButton1Path := FileExtractor.ResourcesDir "\PauseButton_1.png"
    static PauseButton2Path := FileExtractor.ResourcesDir "\PauseButton_2.png"
    static PauseButton3Path := FileExtractor.ResourcesDir "\PauseButton_3.png"
    static PauseButton4Path := FileExtractor.ResourcesDir "\PauseButton_4.png"
    static PauseButton5Path := FileExtractor.ResourcesDir "\PauseButton_5.png"

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

        ; 关卡检测投票模板（每对象多变体：暂停态/非暂停态等）
        if (!FileExist(FileExtractor.FeeIcon1Path))
            FileInstall "resources\images\CostIcon_1.png", FileExtractor.FeeIcon1Path, 1
        if (!FileExist(FileExtractor.FeeIcon2Path))
            FileInstall "resources\images\CostIcon_2.png", FileExtractor.FeeIcon2Path, 1
        if (!FileExist(FileExtractor.ExitButton1Path))
            FileInstall "resources\images\ExitLevelButton_1.png", FileExtractor.ExitButton1Path, 1
        if (!FileExist(FileExtractor.ExitButton2Path))
            FileInstall "resources\images\ExitLevelButton_2.png", FileExtractor.ExitButton2Path, 1
        if (!FileExist(FileExtractor.ExitButton3Path))
            FileInstall "resources\images\ExitLevelButton_3.png", FileExtractor.ExitButton3Path, 1
        if (!FileExist(FileExtractor.ExitButton4Path))
            FileInstall "resources\images\ExitLevelButton_4.png", FileExtractor.ExitButton4Path, 1
        if (!FileExist(FileExtractor.ExitButton5Path))
            FileInstall "resources\images\ExitLevelButton_5.png", FileExtractor.ExitButton5Path, 1
        if (!FileExist(FileExtractor.ExitButton6Path))
            FileInstall "resources\images\ExitLevelButton_6.png", FileExtractor.ExitButton6Path, 1
        if (!FileExist(FileExtractor.ExitButton7Path))
            FileInstall "resources\images\ExitLevelButton_7.png", FileExtractor.ExitButton7Path, 1
        if (!FileExist(FileExtractor.TextInLevel1Path))
            FileInstall "resources\images\TextInLevel_1.png", FileExtractor.TextInLevel1Path, 1
        if (!FileExist(FileExtractor.TextInLevel2Path))
            FileInstall "resources\images\TextInLevel_2.png", FileExtractor.TextInLevel2Path, 1
        if (!FileExist(FileExtractor.BlueCastle1Path))
            FileInstall "resources\images\BlueCastle_1.png", FileExtractor.BlueCastle1Path, 1
        if (!FileExist(FileExtractor.BlueCastle2Path))
            FileInstall "resources\images\BlueCastle_2.png", FileExtractor.BlueCastle2Path, 1
        if (!FileExist(FileExtractor.EnemyCount1Path))
            FileInstall "resources\images\EnemyCount_1.png", FileExtractor.EnemyCount1Path, 1
        if (!FileExist(FileExtractor.EnemyCount2Path))
            FileInstall "resources\images\EnemyCount_2.png", FileExtractor.EnemyCount2Path, 1
        if (!FileExist(FileExtractor.PauseButton1Path))
            FileInstall "resources\images\PauseButton_1.png", FileExtractor.PauseButton1Path, 1
        if (!FileExist(FileExtractor.PauseButton2Path))
            FileInstall "resources\images\PauseButton_2.png", FileExtractor.PauseButton2Path, 1
        if (!FileExist(FileExtractor.PauseButton3Path))
            FileInstall "resources\images\PauseButton_3.png", FileExtractor.PauseButton3Path, 1
        if (!FileExist(FileExtractor.PauseButton4Path))
            FileInstall "resources\images\PauseButton_4.png", FileExtractor.PauseButton4Path, 1
        if (!FileExist(FileExtractor.PauseButton5Path))
            FileInstall "resources\images\PauseButton_5.png", FileExtractor.PauseButton5Path, 1
        Logger.Debug("FileExtractor", "嵌入资源提取完成：" FileExtractor.ResourcesDir)
    }
}
