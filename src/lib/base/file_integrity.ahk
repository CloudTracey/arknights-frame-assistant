; == 文件完整性 ==
class FileIntegrity {
    ; 文件 SHA-256（失败一律返回空串）
    static Sha256(filePath) {
        if !FileExist(filePath)
            return ""
        file := ""
        try {
            file := FileOpen(filePath, "r")
        } catch Error as e {
            Logger.Warn("FileIntegrity", "哈希读取失败，按校验不通过处理（" e.Message "）：" filePath)
            return ""
        }
        if (!IsObject(file))
            return ""
        try {
            hProv := 0
            if !DllCall("Advapi32\CryptAcquireContextW", "Ptr*", &hProv, "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xF0000000)
                return ""
            try {
                hHash := 0
                if !DllCall("Advapi32\CryptCreateHash", "Ptr", hProv, "UInt", 0x800C, "Ptr", 0, "UInt", 0, "Ptr*", &hHash)
                    return ""
                try {
                    chunkSize := 1024 * 1024
                    buf := Buffer(chunkSize)
                    try {
                        while !file.AtEOF {
                            bytesRead := file.RawRead(buf, chunkSize)
                            if (bytesRead > 0) {
                                if !DllCall("Advapi32\CryptHashData", "Ptr", hHash, "Ptr", buf, "UInt", bytesRead, "UInt", 0)
                                    return ""
                            }
                        }
                    } catch Error as e {
                        Logger.Warn("FileIntegrity", "哈希读取失败，按校验不通过处理（" e.Message "）：" filePath)
                        return ""
                    }
                    hashBuf := Buffer(32)
                    hashLen := 32
                    if !DllCall("Advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", hashBuf, "UInt*", &hashLen, "UInt", 0)
                        return ""
                    hex := ""
                    Loop hashLen {
                        hex .= Format("{:02x}", NumGet(hashBuf, A_Index - 1, "UChar"))
                    }
                    return hex
                } finally {
                    DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
                }
            } finally {
                DllCall("Advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
            }
        } finally {
            file.Close()
        }
    }

    ; 锁定文件并校验
    static PinVerified(filePath, expectedHash, &reason) {
        reason := ""
        guard := ""
        try {
            guard := FileOpen(filePath, "r-wd")
        } catch Error as e {
            reason := "无法锁定：" e.Message
        }
        if (!IsObject(guard)) {
            if (StrLen(reason) = 0)
                reason := "无法锁定"
            return ""
        }
        if (StrLower(FileIntegrity.Sha256(filePath)) = StrLower(expectedHash))
            return guard
        guard.Close()
        reason := "哈希与期望值不符"
        return ""
    }
}
