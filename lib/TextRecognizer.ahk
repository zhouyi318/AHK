#Requires AutoHotkey v2.0

class TextRecognizer {
    __New(logger := "", runner := "", rootDir := "", executor := "") {
        this.log := logger
        this.runner := runner
        this.executor := executor
        this.rootDir := (rootDir = "" ? this.ResolveDefaultRootDir() : rootDir)
        this.helperScriptPath := this.rootDir "\lib\ocr_capture.ps1"
        this.rapidRunnerPath := this.rootDir "\lib\rapidocr_runner.py"
        this.rapidPythonPath := this.rootDir "\tools\rapidocr\python\python.exe"
        this.coordTemplateReaderPath := this.rootDir "\lib\coord_template_reader.py"
        this.coordTemplateDir := this.rootDir "\assets\coord_templates"
        this.outputDir := this.rootDir "\logs"
    }

    HasCoordTemplates() {
        templateDir := this.coordTemplateDir
        if !DirExist(templateDir)
            return false
        if !FileExist(templateDir "\colon.png")
            return false
        loop 10 {
            if FileExist(templateDir "\" (A_Index - 1) ".png")
                return true
        }
        return false
    }

    ReadCoordByTemplate(hwnd, region) {
        result := {ok: false, text: "", error: "", raw: "", reason: ""}
        if !hwnd || !WinExist("ahk_id " hwnd) {
            result.error := "绑定窗口不存在"
            result.reason := "WINDOW_NOT_FOUND"
            return result
        }
        if (!region || !IsObject(region)) {
            result.error := "区域无效"
            result.reason := "INVALID_REGION"
            return result
        }
        if !this.HasCoordTemplates() {
            result.error := "坐标模板不存在，请先运行模板截取工具"
            result.reason := "NO_TEMPLATES"
            return result
        }

        rect := this.ResolveScreenRect(hwnd, region)
        if !rect {
            result.error := "区域超出窗口范围"
            result.reason := "OUT_OF_BOUNDS"
            return result
        }

        outputPath := this.BuildOutputPath()
        cmd := this.QuoteArg(this.rapidPythonPath)
            . " " this.QuoteArg(this.coordTemplateReaderPath)
            . " --x " rect.x
            . " --y " rect.y
            . " --width " rect.width
            . " --height " rect.height
            . " --output-path " this.QuoteArg(outputPath)

        try {
            raw := this.RunCommand(cmd, outputPath)
            this.LogInfo("模板匹配坐标", "原始输出长度=" StrLen(raw) " 前200字符=" SubStr(raw, 1, 200))
            parsed := this.ParseOutput(raw)
            result.raw := raw
            result.text := parsed.text
            result.ok := (parsed.status = "OK")
            result.error := parsed.error
            if !result.ok {
                result.reason := "TEMPLATE_ERROR"
            } else if (Trim(parsed.text) = "") {
                result.reason := "NO_TEXT"
            } else {
                result.reason := "TEXT_ONLY"
            }
        } catch as err {
            result.error := err.Message
            result.reason := "EXEC_ERROR"
        } finally {
            try if FileExist(outputPath)
                FileDelete(outputPath)
        }

        if result.ok {
            if (result.reason = "NO_TEXT")
                this.LogWarn("模板匹配坐标", "成功但未匹配到坐标")
            else
                this.LogInfo("模板匹配坐标", "成功: " result.text)
        } else {
            this.LogWarn("模板匹配坐标", "失败: " result.error)
        }
        return result
    }

    ResolveDefaultRootDir() {
        if RegExMatch(A_LineFile, "^(.*)\\lib\\[^\\]+$", &m)
            return m[1]
        return A_ScriptDir
    }

    Recognize(hwnd, region, targetText := "", logLabel := "", preprocess := false) {
        result := {ok: false, matched: false, text: "", error: "", raw: "", reason: ""}
        if !hwnd || !WinExist("ahk_id " hwnd) {
            result.error := "绑定窗口不存在"
            result.reason := "WINDOW_NOT_FOUND"
            this.LogWarn(logLabel, result.error)
            return result
        }
        if (!region || !IsObject(region)) {
            result.error := "区域无效"
            result.reason := "INVALID_REGION"
            this.LogWarn(logLabel, result.error)
            return result
        }
        backend := this.ResolveBackend()
        if (backend.name = "") {
            result.error := "OCR helper 不存在"
            result.reason := "HELPER_MISSING"
            this.LogWarn(logLabel, result.error)
            return result
        }

        rect := this.ResolveScreenRect(hwnd, region)
        if !rect {
            result.error := "区域超出窗口范围"
            result.reason := "OUT_OF_BOUNDS"
            this.LogWarn(logLabel, result.error)
            return result
        }

        this.LogInfo(logLabel, "截屏区域: 屏幕=(" rect.x "," rect.y ") 尺寸=" rect.width "x" rect.height " 预处理=" preprocess)

        outputPath := this.BuildOutputPath()
        cmd := this.BuildCommand(rect.x, rect.y, rect.width, rect.height, outputPath, preprocess)

        try {
            raw := this.RunCommand(cmd, outputPath)
            this.LogInfo(logLabel, "原始输出长度=" StrLen(raw) " 前200字符=" SubStr(raw, 1, 200))
            parsed := this.ParseOutput(raw)
            result.raw := raw
            result.text := parsed.text
            result.ok := (parsed.status = "OK")
            result.error := parsed.error
            if !result.ok {
                result.reason := "OCR_ERROR"
            } else if (Trim(parsed.text) = "") {
                result.reason := "NO_TEXT"
            } else if (targetText != "") {
                result.matched := this.ContainsText(parsed.text, targetText)
                result.reason := result.matched ? "MATCHED" : "NOT_MATCHED"
            } else {
                result.reason := "TEXT_ONLY"
            }
        } catch as err {
            result.error := err.Message
            result.reason := "EXEC_ERROR"
        } finally {
            try if FileExist(outputPath)
                FileDelete(outputPath)
        }

        if result.ok {
            if (result.reason = "NO_TEXT")
                this.LogWarn(logLabel, "成功但未识别到文本")
            else
                this.LogInfo(logLabel, "成功: 文本长度" . StrLen(result.text) . (targetText != "" ? " 匹配=" . (result.matched ? "是" : "否") : ""))
        } else {
            this.LogWarn(logLabel, "失败: " . result.error)
        }
        return result
    }

    ResolveScreenRect(hwnd, region) {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        this.LogInfo("坐标转换", "客户区原点=(" cx "," cy ") 尺寸=" cw "x" ch " 区域原始=(" region.x1 "," region.y1 ")-(" region.x2 "," region.y2 ")")
        if (cw <= 0 || ch <= 0)
            return ""
        left := Max(Min(region.x1, region.x2), 0)
        top := Max(Min(region.y1, region.y2), 0)
        right := Min(Max(region.x1, region.x2), cw - 1)
        bottom := Min(Max(region.y1, region.y2), ch - 1)
        if (right < left || bottom < top)
            return ""
        return {
            x: cx + left,
            y: cy + top,
            width: right - left + 1,
            height: bottom - top + 1
        }
    }

    BuildCommand(x, y, width, height, outputPath, preprocess := false) {
        backend := this.ResolveBackend()
        if (backend.name = "rapidocr") {
            cmd := backend.command
                . " --x " x
                . " --y " y
                . " --width " width
                . " --height " height
                . " --output-path " this.QuoteArg(outputPath)
            if preprocess
                cmd .= " --preprocess"
            return cmd
        }
        return backend.command
            . " -X " x
            . " -Y " y
            . " -Width " width
            . " -Height " height
            . " -OutputPath " this.QuoteArg(outputPath)
            . " -Languages " this.QuoteArg("zh-Hans-CN,en-US,zh-CN")
    }

    ResolveBackend() {
        if (FileExist(this.rapidPythonPath) && FileExist(this.rapidRunnerPath)) {
            return {
                name: "rapidocr",
                command: this.QuoteArg(this.rapidPythonPath) . " " . this.QuoteArg(this.rapidRunnerPath)
            }
        }
        if FileExist(this.helperScriptPath) {
            return {
                name: "winrt",
                command: "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " . this.QuoteArg(this.helperScriptPath)
            }
        }
        return {name: "", command: ""}
    }

    RunCommand(commandLine, outputPath) {
        if IsObject(this.runner)
            return this.runner.Call(commandLine, outputPath)
        if IsObject(this.executor) {
            stdout := this.executor.Call(commandLine, outputPath)
            if (stdout != "")
                return stdout
            if FileExist(outputPath)
                return FileRead(outputPath, "UTF-8")
            return ""
        }

        shell := ComObject("WScript.Shell")
        exitCode := shell.Run(commandLine, 0, true)
        stdout := ""
        if (FileExist(outputPath)) {
            fileText := FileRead(outputPath, "UTF-8")
            if (fileText != "")
                stdout := fileText
        }
        if (stdout = "" && exitCode != 0)
            stdout := "Process exited with code " exitCode
        return stdout
    }

    BuildOutputPath() {
        if !DirExist(this.outputDir)
            DirCreate(this.outputDir)
        return this.outputDir "\ocr_" A_Now "_" A_TickCount ".txt"
    }

    ParseOutput(raw) {
        text := raw
        status := ""
        error := ""
        if RegExMatch(raw, "m)^STATUS=(.*)$", &m)
            status := Trim(m[1])
        if RegExMatch(raw, "m)^ERROR=(.*)$", &m)
            error := Trim(m[1])
        if RegExMatch(raw, "s)TEXT_BEGIN`r?`n(.*?)`r?`nTEXT_END", &m)
            text := m[1]
        else
            text := ""
        return {status: status, text: text, error: error}
    }

    ContainsText(text, targetText) {
        normalizedText := this.NormalizeForMatch(text)
        normalizedTarget := this.NormalizeForMatch(targetText)
        if (normalizedTarget = "")
            return false
        return InStr(normalizedText, normalizedTarget) > 0
    }

    NormalizeForMatch(text) {
        text := StrLower(text)
        text := RegExReplace(text, "\s+", "")
        return text
    }

    BuildDisplayText(text) {
        return Trim(text) = "" ? "(OCR 未识别到文本)" : text
    }

    QuoteArg(value) {
        return '"' . StrReplace(value, '"', '\"') . '"'
    }

    LogInfo(prefix, msg) {
        if (prefix = "")
            prefix := "OCR"
        try {
            if this.log
                this.log.Info(prefix . msg)
        }
    }

    LogWarn(prefix, msg) {
        if (prefix = "")
            prefix := "OCR"
        try {
            if this.log
                this.log.Warn(prefix . msg)
        }
    }
}
