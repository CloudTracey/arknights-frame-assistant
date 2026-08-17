; == GitHub Token 保护 ==
; 使用 Windows DPAPI CurrentUser 保护配置文件中的 Token。

class TokenProtector {
    static STORAGE_PREFIX := "dpapi:v1:"
    static BLOB_POINTER_OFFSET := A_PtrSize
    static BLOB_SIZE := A_PtrSize * 2
    static BASE64_FLAGS := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF

    ; 保护明文 Token，返回可写入 INI 的字符串。
    static Protect(plainToken) {
        if (plainToken = "")
            return {success: true, storedValue: "", message: ""}

        inputSize := StrPut(plainToken, "UTF-8")
        inputBuffer := Buffer(inputSize, 0)
        StrPut(plainToken, inputBuffer, "UTF-8")
        inputBlob := this._CreateBlob(inputBuffer, inputSize)
        outputBlob := Buffer(this.BLOB_SIZE, 0)
        outputPointer := 0

        try {
            if !DllCall("Crypt32\CryptProtectData"
                , "Ptr", inputBlob
                , "Ptr", 0
                , "Ptr", 0
                , "Ptr", 0
                , "Ptr", 0
                , "UInt", 0x1 ; CRYPTPROTECT_UI_FORBIDDEN
                , "Ptr", outputBlob
                , "Int") {
                errorCode := A_LastError
                return this._Failure("DPAPI 加密失败，错误码：" errorCode)
            }

            outputSize := NumGet(outputBlob, 0, "UInt")
            outputPointer := NumGet(outputBlob, this.BLOB_POINTER_OFFSET, "Ptr")
            if (outputSize <= 0 || !outputPointer)
                return this._Failure("DPAPI 加密未返回有效数据。")

            encoded := this._Base64Encode(outputPointer, outputSize)
            if (!encoded.success)
                return encoded
            return {success: true, storedValue: this.STORAGE_PREFIX encoded.value, message: ""}
        } catch Error as e {
            return this._Failure("DPAPI 加密异常：" e.Message)
        } finally {
            if (outputPointer)
                DllCall("Kernel32\LocalFree", "Ptr", outputPointer)
            this._SecureZero(inputBuffer)
            this._SecureZero(inputBlob)
            this._SecureZero(outputBlob)
        }
    }

    ; 解密 INI 中的 Token。无前缀值视为旧版明文，供迁移流程使用。
    static Unprotect(storedValue) {
        if (storedValue = "")
            return {success: true, plainText: "", format: "empty", message: ""}

        if (InStr(storedValue, this.STORAGE_PREFIX) != 1) {
            if (InStr(storedValue, "dpapi:") = 1)
                return this._Failure("不支持的 Token 加密格式。")
            return {success: true, plainText: storedValue, format: "legacy", message: ""}
        }

        encoded := SubStr(storedValue, StrLen(this.STORAGE_PREFIX) + 1)
        decoded := this._Base64Decode(encoded)
        if (!decoded.success)
            return decoded

        inputBlob := this._CreateBlob(decoded.buffer, decoded.size)
        outputBlob := Buffer(this.BLOB_SIZE, 0)
        outputPointer := 0

        try {
            if !DllCall("Crypt32\CryptUnprotectData"
                , "Ptr", inputBlob
                , "Ptr", 0
                , "Ptr", 0
                , "Ptr", 0
                , "Ptr", 0
                , "UInt", 0x1 ; CRYPTPROTECT_UI_FORBIDDEN
                , "Ptr", outputBlob
                , "Int") {
                errorCode := A_LastError
                return this._Failure("DPAPI 解密失败，错误码：" errorCode)
            }

            outputSize := NumGet(outputBlob, 0, "UInt")
            outputPointer := NumGet(outputBlob, this.BLOB_POINTER_OFFSET, "Ptr")
            if (outputSize <= 0 || !outputPointer)
                return this._Failure("DPAPI 解密未返回有效数据。")

            plainText := StrGet(outputPointer, "UTF-8")
            return {success: true, plainText: plainText, format: "protected", message: ""}
        } catch Error as e {
            return this._Failure("DPAPI 解密异常：" e.Message)
        } finally {
            if (outputPointer)
                DllCall("Kernel32\LocalFree", "Ptr", outputPointer)
            this._SecureZero(decoded.buffer)
            this._SecureZero(inputBlob)
            this._SecureZero(outputBlob)
        }
    }

    ; 创建 DATA_BLOB。结构为 DWORD cbData + 指针 pbData。
    static _CreateBlob(dataBuffer, dataSize) {
        blob := Buffer(this.BLOB_SIZE, 0)
        NumPut("UInt", dataSize, blob, 0)
        NumPut("Ptr", dataBuffer.Ptr, blob, this.BLOB_POINTER_OFFSET)
        return blob
    }

    ; 使用 Crypt32 将二进制数据转换为无换行 Base64。
    static _Base64Encode(dataPointer, dataSize) {
        characterCount := 0
        if !DllCall("Crypt32\CryptBinaryToStringW"
            , "Ptr", dataPointer
            , "UInt", dataSize
            , "UInt", this.BASE64_FLAGS
            , "Ptr", 0
            , "UInt*", &characterCount
            , "Int") {
            errorCode := A_LastError
            return this._Failure("Token Base64 编码失败，错误码：" errorCode)
        }

        outputBuffer := Buffer((characterCount + 1) * 2, 0)
        if !DllCall("Crypt32\CryptBinaryToStringW"
            , "Ptr", dataPointer
            , "UInt", dataSize
            , "UInt", this.BASE64_FLAGS
            , "Ptr", outputBuffer
            , "UInt*", &characterCount
            , "Int") {
            errorCode := A_LastError
            return this._Failure("Token Base64 编码失败，错误码：" errorCode)
        }
        return {success: true, value: StrGet(outputBuffer, characterCount, "UTF-16"), message: ""}
    }

    ; 使用 Crypt32 将 Base64 解码为二进制数据。
    static _Base64Decode(encoded) {
        if (encoded = "")
            return this._Failure("Token 加密数据为空。")

        byteCount := 0
        if !DllCall("Crypt32\CryptStringToBinaryW"
            , "Str", encoded
            , "UInt", StrLen(encoded)
            , "UInt", 0x1 ; CRYPT_STRING_BASE64
            , "Ptr", 0
            , "UInt*", &byteCount
            , "Ptr", 0
            , "Ptr", 0
            , "Int") {
            errorCode := A_LastError
            return this._Failure("Token Base64 解码失败，错误码：" errorCode)
        }

        outputBuffer := Buffer(byteCount, 0)
        if !DllCall("Crypt32\CryptStringToBinaryW"
            , "Str", encoded
            , "UInt", StrLen(encoded)
            , "UInt", 0x1
            , "Ptr", outputBuffer
            , "UInt*", &byteCount
            , "Ptr", 0
            , "Ptr", 0
            , "Int") {
            errorCode := A_LastError
            this._SecureZero(outputBuffer)
            return this._Failure("Token Base64 解码失败，错误码：" errorCode)
        }
        return {success: true, buffer: outputBuffer, size: byteCount, message: ""}
    }

    static _Failure(message) {
        return {success: false, storedValue: "", plainText: "", value: "", format: "error", message: message}
    }

    static _SecureZero(buffer) {
        if !IsObject(buffer) || buffer.Size <= 0
            return
        ; RtlSecureZeroMemory 是 Windows 宏，不是可直接 DllCall 的导出函数。
        Loop buffer.Size
            NumPut("UChar", 0, buffer, A_Index - 1)
    }
}
