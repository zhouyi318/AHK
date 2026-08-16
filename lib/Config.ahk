; ===== 全局配置加载模块 =====
; 读取 config.ini 全局配置；脚本与存仓配置由 ScriptStore 管理

class Config {
    __New(iniPath) {
        this.iniPath := iniPath

        this.Window := {}
        this.Window.ExeName := this.ReadIniValue("Window", "ExeName", "")
        this.Window.Title := this.ReadIniValue("Window", "Title", "")
        this.Window.Hwnd := this.ReadIniValue("Window", "Hwnd", "0")
        this.Window.ExpectedWidth := Integer(this.ReadIniValue("Window", "ExpectedWidth", "1280"))
        this.Window.ExpectedHeight := Integer(this.ReadIniValue("Window", "ExpectedHeight", "720"))

        this.Images := {}
        this.Images.Town := IniRead(iniPath, "Images", "Town", "town.bmp")
        this.Images.AutoFightBtn := IniRead(iniPath, "Images", "AutoFightBtn", "autofight_btn.bmp")
        this.Images.AutoFightOn := IniRead(iniPath, "Images", "AutoFightOn", "autofight_on.bmp")
        this.Images.ReturnStone := IniRead(iniPath, "Images", "ReturnStone", "return_stone.bmp")
        this.Images.Disconnect := IniRead(iniPath, "Images", "Disconnect", "btn_reconnect.bmp")
        this.Images.Dead := IniRead(iniPath, "Images", "Dead", "btn_revive.bmp")

        this.ImageRegions := {}
        this.ImageRegions.Town := this.ReadRegionValue("ImageRegions", "Town")
        this.ImageRegions.AutoFightBtn := this.ReadRegionValue("ImageRegions", "AutoFightBtn")
        this.ImageRegions.AutoFightOn := this.ReadRegionValue("ImageRegions", "AutoFightOn")
        this.ImageRegions.ReturnStone := this.ReadRegionValue("ImageRegions", "ReturnStone")
        this.ImageRegions.Disconnect := this.ReadRegionValue("ImageRegions", "Disconnect")
        this.ImageRegions.Dead := this.ReadRegionValue("ImageRegions", "Dead")

        this.Hotkey := {}
        this.Hotkey.StartStop := IniRead(iniPath, "Hotkey", "StartStop", "F8")
        this.Hotkey.EmergencyStop := IniRead(iniPath, "Hotkey", "EmergencyStop", "F12")

        this.Bot := {}
        this.Bot.TickMs := Integer(IniRead(iniPath, "Bot", "TickMs", "500"))
        this.Bot.Sim := Float(IniRead(iniPath, "Bot", "Sim", "0.75"))
        this.Bot.AutoFightRetry := Integer(IniRead(iniPath, "Bot", "AutoFightRetry", "3"))
        this.Bot.StoreIntervalMin := Integer(IniRead(iniPath, "Bot", "StoreIntervalMin", "60"))
        this.Bot.MonitorIntervalMs := Integer(IniRead(iniPath, "Bot", "MonitorIntervalMs", "10000"))

        this.Paths := {}
        this.Paths.AssetsDir := IniRead(iniPath, "Paths", "AssetsDir", "assets")
        this.Paths.LogDir := IniRead(iniPath, "Paths", "LogDir", "logs")
        this.Paths.ScriptsDir := IniRead(iniPath, "Paths", "ScriptsDir", "scripts")

        this.OcrRegions := this.ReadNamedRegionSection("OcrRegions")
    }

    SaveWindow(exeName, title, hwnd, w, h) {
        this.WriteSectionValues("Window", Map(
            "ExeName", exeName,
            "Title", title,
            "Hwnd", hwnd,
            "ExpectedWidth", w,
            "ExpectedHeight", h
        ))
        ; 刷新内存
        this.Window.ExeName := exeName
        this.Window.Title := title
        this.Window.Hwnd := hwnd
        this.Window.ExpectedWidth := w
        this.Window.ExpectedHeight := h
    }

    SaveImageSetting(key, imageName, region := "") {
        this.WriteSectionValues("Images", Map(key, imageName))
        this.WriteSectionValues("ImageRegions", Map(key, this.FormatRegion(region)))
        this.Images.%key% := imageName
        this.ImageRegions.%key% := this.NormalizeRegion(region)
    }

    SaveImageRegion(key, region := "") {
        this.WriteSectionValues("ImageRegions", Map(key, this.FormatRegion(region)))
        this.ImageRegions.%key% := this.NormalizeRegion(region)
    }

    SaveBotSim(sim) {
        simValue := this.NormalizeSim(sim)
        this.WriteSectionValues("Bot", Map("Sim", simValue))
        this.Bot.Sim := Float(simValue)
    }

    SaveNamedOcrRegion(name, region) {
        normalizedName := Trim(name)
        if (normalizedName = "")
            return false
        normalizedRegion := this.NormalizeRegion(region)
        if !normalizedRegion
            return false
        this.WriteSectionValues("OcrRegions", Map(normalizedName, this.FormatRegion(normalizedRegion)))
        this.OcrRegions[normalizedName] := normalizedRegion
        return true
    }

    ListNamedOcrRegionNames() {
        names := []
        for name in this.OcrRegions
            names.Push(name)
        if (names.Length <= 1)
            return names
        text := ""
        for index, name in names
            text .= (index = 1 ? "" : "`n") . name
        return StrSplit(Sort(text), "`n")
    }

    DeleteNamedOcrRegion(name) {
        normalizedName := Trim(name)
        if (normalizedName = "" || !this.OcrRegions.Has(normalizedName))
            return false
        this.RemoveSectionKeys("OcrRegions", Map(normalizedName, true))
        this.OcrRegions.Delete(normalizedName)
        return true
    }

    RenameNamedOcrRegion(oldName, newName) {
        normalizedOld := Trim(oldName)
        normalizedNew := Trim(newName)
        if (normalizedOld = "" || normalizedNew = "")
            return false
        if !this.OcrRegions.Has(normalizedOld)
            return false
        if (normalizedNew != normalizedOld && this.OcrRegions.Has(normalizedNew))
            return false
        region := this.OcrRegions[normalizedOld]
        this.RemoveSectionKeys("OcrRegions", Map(normalizedOld, true))
        this.WriteSectionValues("OcrRegions", Map(normalizedNew, this.FormatRegion(region)))
        this.OcrRegions.Delete(normalizedOld)
        this.OcrRegions[normalizedNew] := region
        return true
    }

    ReadIniValue(section, key, defaultValue := "") {
        if !FileExist(this.iniPath)
            return defaultValue
        text := FileRead(this.iniPath, "UTF-8")
        inSection := false
        targetHeader := "[" section "]"
        for _, line in StrSplit(text, "`n", "`r") {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[.*\]$") {
                inSection := (trimmed = targetHeader)
                continue
            }
            if !inSection
                continue
            eqPos := InStr(line, "=")
            if (eqPos <= 0)
                continue
            currentKey := Trim(SubStr(line, 1, eqPos - 1))
            if (currentKey = key)
                return SubStr(line, eqPos + 1)
        }
        return defaultValue
    }

    ReadRegionValue(section, key) {
        return this.ParseRegionString(this.ReadIniValue(section, key, ""))
    }

    ReadNamedRegionSection(section) {
        result := Map()
        if !FileExist(this.iniPath)
            return result
        text := FileRead(this.iniPath, "UTF-8")
        inSection := false
        targetHeader := "[" section "]"
        for _, line in StrSplit(text, "`n", "`r") {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[.*\]$") {
                inSection := (trimmed = targetHeader)
                continue
            }
            if (!inSection || trimmed = "")
                continue
            eqPos := InStr(line, "=")
            if (eqPos <= 0)
                continue
            currentKey := Trim(SubStr(line, 1, eqPos - 1))
            if (currentKey = "")
                continue
            region := this.ParseRegionString(SubStr(line, eqPos + 1))
            if region
                result[currentKey] := region
        }
        return result
    }

    ParseRegionString(raw) {
        raw := Trim(raw)
        if (raw = "")
            return ""
        parts := StrSplit(raw, ",")
        if (parts.Length != 4)
            return ""
        try {
            x1 := Integer(Trim(parts[1]))
            y1 := Integer(Trim(parts[2]))
            x2 := Integer(Trim(parts[3]))
            y2 := Integer(Trim(parts[4]))
        } catch {
            return ""
        }
        return this.NormalizeRegion({x1: x1, y1: y1, x2: x2, y2: y2})
    }

    NormalizeRegion(region) {
        if (!region || !IsObject(region))
            return ""
        left := Min(region.x1, region.x2)
        top := Min(region.y1, region.y2)
        right := Max(region.x1, region.x2)
        bottom := Max(region.y1, region.y2)
        return {x1: left, y1: top, x2: right, y2: bottom}
    }

    FormatRegion(region) {
        normalized := this.NormalizeRegion(region)
        if !normalized
            return ""
        return normalized.x1 "," normalized.y1 "," normalized.x2 "," normalized.y2
    }

    NormalizeSim(sim) {
        try value := Float(sim)
        catch
            value := 0.75
        if (value < 0.10)
            value := 0.10
        if (value > 1.00)
            value := 1.00
        return Format("{:.2f}", value)
    }

    RemoveSectionKeys(section, keys) {
        if !FileExist(this.iniPath)
            return
        text := FileRead(this.iniPath, "UTF-8")
        newline := InStr(text, "`r`n") ? "`r`n" : "`n"
        lines := []
        inSection := false
        targetHeader := "[" section "]"

        for _, line in StrSplit(text, "`n", "`r") {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[.*\]$") {
                inSection := (trimmed = targetHeader)
                lines.Push(line)
                continue
            }
            if inSection {
                eqPos := InStr(line, "=")
                if (eqPos > 0) {
                    currentKey := Trim(SubStr(line, 1, eqPos - 1))
                    if keys.Has(currentKey)
                        continue
                }
            }
            lines.Push(line)
        }

        out := ""
        for index, line in lines
            out .= (index = 1 ? "" : newline) . line
        if (out != "")
            out .= newline
        if FileExist(this.iniPath)
            FileDelete(this.iniPath)
        FileAppend out, this.iniPath, "UTF-8-RAW"
    }

    WriteSectionValues(section, values) {
        text := FileRead(this.iniPath, "UTF-8")
        newline := InStr(text, "`r`n") ? "`r`n" : "`n"
        lines := []
        sourceLines := StrSplit(text, "`n", "`r")
        inSection := false
        foundSection := false
        missingInserted := false
        writtenKeys := Map()
        targetHeader := "[" section "]"

        for _, line in sourceLines {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[.*\]$") {
                if (inSection && !missingInserted) {
                    for currentKey, currentValue in values {
                        if !writtenKeys.Has(currentKey)
                            lines.Push(currentKey "=" currentValue)
                    }
                    missingInserted := true
                }
                inSection := (trimmed = targetHeader)
                if inSection
                    foundSection := true
                lines.Push(line)
                continue
            }

            if inSection {
                eqPos := InStr(line, "=")
                if (eqPos > 0) {
                    currentKey := Trim(SubStr(line, 1, eqPos - 1))
                    if values.Has(currentKey) {
                        lines.Push(currentKey "=" values[currentKey])
                        writtenKeys[currentKey] := true
                        continue
                    }
                }
            }

            lines.Push(line)
        }

        if foundSection {
            if !missingInserted {
                for currentKey, currentValue in values {
                    if !writtenKeys.Has(currentKey)
                        lines.Push(currentKey "=" currentValue)
                }
            }
        } else {
            if (lines.Length > 0 && lines[lines.Length] != "")
                lines.Push("")
            lines.Push(targetHeader)
            for currentKey, currentValue in values
                lines.Push(currentKey "=" currentValue)
        }

        out := ""
        for index, line in lines
            out .= (index = 1 ? "" : newline) . line
        if (out != "")
            out .= newline
        if FileExist(this.iniPath)
            FileDelete(this.iniPath)
        FileAppend out, this.iniPath, "UTF-8-RAW"
    }

    winTitle() {
        if (this.Window.Hwnd != "0" && this.Window.Hwnd != "")
            return "ahk_id " this.Window.Hwnd
        if (this.Window.ExeName != "")
            return "ahk_exe " this.Window.ExeName
        return ""
    }
}
