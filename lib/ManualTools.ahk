#Requires AutoHotkey v2.0

class ManualTools {
    __New(deps) {
        this.deps := deps
        this.cfg := deps.Has("cfg") ? deps["cfg"] : ""
        this.appLogger := deps.Has("logger") ? deps["logger"] : ""
        this.playback := deps.Has("playback") ? deps["playback"] : ""
        this.ocrRecognizer := deps.Has("ocrRecognizer") ? deps["ocrRecognizer"] : ""
        this.regionTool := deps.Has("regionTool") ? deps["regionTool"] : ""
        this.guiState := deps.Has("guiState") ? deps["guiState"] : ""
    }

    HandleConfigSystemImageRegions(*) {
        this.ShowSystemImageRegionManager()
    }

    HandleTestRegionFind(*) {
        if !this.EnsureBoundWindow()
            return

        info := this.ShowImageRegionDialog("测试区域找图", "", "", "", false, false
            , "选择图片并框选区域后，立即测试这张图是否出现在当前绑定窗口里。浏览器场景建议先试 0.65 ~ 0.80。"
            , true, this.cfg.Bot.Sim)
        if (!info || (info.HasProp("clear") && info.clear))
            return

        imageName := info.image
        region := info.region
        simValue := info.HasProp("sim") ? info.sim : this.cfg.Bot.Sim
        WinActivate "ahk_id " this.cfg.Window.Hwnd
        try WinWaitActive("ahk_id " this.cfg.Window.Hwnd, , 1)
        Sleep 150
        if this.playback.FindPic(imageName, this.cfg.Window.Hwnd, &x, &y, region, "手动测试找图", simValue) {
            hitText := this.playback.HitPointText(this.cfg.Window.Hwnd, x, y)
            MsgBox("找图成功：`n图片: " . imageName . "`n命中: " . hitText . "`n区域: " . this.RegionSummary(region) . "`n相似度: " . Format("{:.2f}", simValue), "测试结果")
            return
        }

        sweep := this.RunFindPicSimilaritySweep(imageName, region, simValue)
        if sweep.found {
            hitText := this.playback.HitPointText(this.cfg.Window.Hwnd, sweep.x, sweep.y)
            MsgBox("当前相似度 " . Format("{:.2f}", simValue) . " 失败，但在更低相似度命中了。`n`n图片: " . imageName . "`n命中: " . hitText . "`n区域: " . this.RegionSummary(region) . "`n可命中相似度: " . Format("{:.2f}", sweep.sim) . "`n已扫描: " . sweep.scannedText . "`n`n这说明更像是匹配度过高，建议把全局找图相似度调到 " . Format("{:.2f}", sweep.sim) . " 附近再验证。", "测试结果")
        } else {
            MsgBox("找图失败：`n图片: " . imageName . "`n区域: " . this.RegionSummary(region) . "`n起始相似度: " . Format("{:.2f}", simValue) . "`n已扫描: " . sweep.scannedText . "`n`n连更低相似度都没有命中，更可能不是简单的相似度问题，而是模板图本身不适合当前页面渲染。建议改截更小、更稳定的局部，优先截图标、边角特征，不要只截文字。", "测试结果")
        }
    }

    HandleTestRegionOcr(*) {
        if !this.EnsureBoundWindow()
            return

        info := this.ShowTextOcrDialog("测试区域 OCR 找字")
        if !info
            return

        WinActivate "ahk_id " this.cfg.Window.Hwnd
        try WinWaitActive("ahk_id " this.cfg.Window.Hwnd, , 1)
        Sleep 150

        result := this.ocrRecognizer.Recognize(this.cfg.Window.Hwnd, info.region, info.targetText, "手动 OCR 找字")
        if result.ok {
            displayText := this.ocrRecognizer.BuildDisplayText(result.text)
            if (result.reason = "NO_TEXT") {
                MsgBox("OCR 已执行，但这个区域里没有识别到可用文本。`n`n目标文本: " . info.targetText . "`n区域: " . this.RegionSummary(info.region) . "`n`n识别文本:`n" . displayText . "`n`n这通常说明框选区域太大/太小、文字太糊、颜色对比不够，或者刚好没框到字。", "测试结果")
            } else {
                matchedText := result.matched ? "命中" : "未命中"
                MsgBox("OCR 成功：`n目标文本: " . info.targetText . "`n匹配结果: " . matchedText . "`n区域: " . this.RegionSummary(info.region) . "`n`n识别文本:`n" . displayText, "测试结果")
            }
        } else {
            MsgBox("OCR 失败：`n目标文本: " . info.targetText . "`n区域: " . this.RegionSummary(info.region) . "`n错误: " . result.error, "测试结果")
        }
    }

    HandlePreviewRegionOcr(*) {
        if !this.EnsureBoundWindow()
            return

        info := this.ShowTextOcrDialog("查看区域 OCR 文本", "", "", false)
        if !info
            return

        WinActivate "ahk_id " this.cfg.Window.Hwnd
        try WinWaitActive("ahk_id " this.cfg.Window.Hwnd, , 1)
        Sleep 150

        result := this.ocrRecognizer.Recognize(this.cfg.Window.Hwnd, info.region, "", "查看 OCR 文本")
        if !result.ok {
            MsgBox("OCR 失败：`n区域: " . this.RegionSummary(info.region) . "`n错误: " . result.error, "测试结果")
            return
        }
        this.ShowOcrPreviewResult(info.region, result)
    }

    HandleSetGlobalSim(*) {
        ib := InputBox("请输入全局找图相似度（0.10 ~ 1.00，值越高越严格）：", "设置找图相似度", , Format("{:.2f}", this.cfg.Bot.Sim))
        if (ib.Result = "Cancel" || Trim(ib.Value) = "")
            return
        try simValue := Float(Trim(ib.Value))
        catch {
            MsgBox("请输入有效的小数，例如 0.75。", "提示")
            return
        }
        if (simValue < 0.10 || simValue > 1.00) {
            MsgBox("相似度必须在 0.10 到 1.00 之间。", "提示")
            return
        }
        this.cfg.SaveBotSim(simValue)
        if this.deps.Has("onBotSimChanged") {
            callback := this.deps["onBotSimChanged"]
            if IsObject(callback)
                callback.Call()
            else if (callback != "")
                Func(callback).Call()
        }
        this.appLogger.Info("已更新全局找图相似度: " . Format("{:.2f}", this.cfg.Bot.Sim))
        MsgBox("全局找图相似度已更新为 " . Format("{:.2f}", this.cfg.Bot.Sim) . "。", "提示")
    }

    RunFindPicSimilaritySweep(imageName, region, baseSim) {
        sims := this.BuildSimSweepList(baseSim)
        scannedText := this.JoinSimValues(sims)
        for _, simValue in sims {
            if this.playback.FindPic(imageName, this.cfg.Window.Hwnd, &x, &y, region, "手动测试找图扫描", simValue)
                return {found: true, sim: simValue, x: x, y: y, scannedText: scannedText}
        }
        return {found: false, scannedText: scannedText}
    }

    BuildSimSweepList(baseSim) {
        values := []
        seen := Map()
        this.AddSimCandidate(values, seen, baseSim)
        for _, candidate in [baseSim - 0.05, baseSim - 0.10, baseSim - 0.15, baseSim - 0.20, 0.50, 0.40, 0.30] {
            this.AddSimCandidate(values, seen, candidate)
        }
        return values
    }

    AddSimCandidate(values, seen, candidate) {
        if !(candidate is Number)
            return
        if (candidate < 0.10 || candidate > 1.00)
            return
        key := Format("{:.2f}", candidate)
        if seen.Has(key)
            return
        seen[key] := true
        values.Push(Float(key))
    }

    JoinSimValues(values) {
        text := ""
        for index, value in values {
            if (index > 1)
                text .= ", "
            text .= Format("{:.2f}", value)
        }
        return text
    }

    ListAssetImages() {
        files := []
        assetsDir := A_ScriptDir "\" this.cfg.Paths.AssetsDir
        if !DirExist(assetsDir)
            return files
        loop files, assetsDir "\*.*" {
            ext := LTrim(StrLower(A_LoopFileExt), ".")
            if (ext = "bmp" || ext = "png" || ext = "jpg" || ext = "jpeg")
                files.Push(A_LoopFileName)
        }
        return files
    }

    NormalizeRegionObject(region) {
        if (!region || !IsObject(region))
            return ""
        x1 := Min(region.x1, region.x2)
        y1 := Min(region.y1, region.y2)
        x2 := Max(region.x1, region.x2)
        y2 := Max(region.y1, region.y2)
        return {x1: x1, y1: y1, x2: x2, y2: y2}
    }

    RegionSummary(region) {
        if (!region || !IsObject(region))
            return "(全窗口)"
        return "(" . region.x1 . "," . region.y1 . ")-(" . region.x2 . "," . region.y2 . ")"
    }

    SystemImageDefs() {
        return [
            {key: "Town", label: "土城检测图"},
            {key: "AutoFightBtn", label: "挂机按钮图"},
            {key: "AutoFightOn", label: "挂机已开启图"},
            {key: "ReturnStone", label: "回城石图"},
            {key: "Disconnect", label: "掉线重连图"},
            {key: "Dead", label: "死亡复活图"}
        ]
    }

    SystemImageLabel(imgKey) {
        for _, item in this.SystemImageDefs() {
            if (item.key = imgKey)
                return item.label
        }
        return imgKey
    }

    SystemImageSummaryText(imgKey) {
        imageName := this.cfg.Images.%imgKey%
        region := this.cfg.ImageRegions.%imgKey%
        return imageName . "  " . this.RegionSummary(region)
    }

    ShowSystemImageRegionManager() {
        dlg := Gui(, "系统找图区域配置")
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        dlg.Add("Text", "xm ym w470 h36", "这些区域会用于 BOT 内置找图与点击。区域越聚焦，查找越快；留空则仍按整个绑定窗口搜索。")

        for _, item in this.SystemImageDefs() {
            dlg.Add("Text", "xm y+12 w120 h22", item.label . ":")
            txtSummary := dlg.Add("Text", "x+8 yp w260 h22", this.SystemImageSummaryText(item.key))
            btnEdit := dlg.Add("Button", "x+8 yp-4 w90", "设置区域")
            btnEdit.__imgKey := item.key
            btnEdit.__summaryCtrl := txtSummary
            btnEdit.OnEvent("Click", ObjBindMethod(this, "OnSystemImageRegionEdit"))
        }

        btnClose := dlg.Add("Button", "xm y+18 w90 Default", "关闭")
        btnClose.OnEvent("Click", ObjBindMethod(this, "OnSystemRegionManagerClose"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnSystemRegionManagerGuiClose"))
        dlg.Show("AutoSize Center")
    }

    OnSystemImageRegionEdit(ctrl, *) {
        imgKey := ctrl.__imgKey
        currentRegion := this.cfg.ImageRegions.%imgKey%
        imageName := this.cfg.Images.%imgKey%
        info := this.ShowImageRegionDialog("设置" . this.SystemImageLabel(imgKey) . "区域", imageName, "", currentRegion, false, true)
        if (!info)
            return
        if (info.HasProp("clear") && info.clear)
            this.cfg.SaveImageRegion(imgKey, "")
        else
            this.cfg.SaveImageSetting(imgKey, info.image, info.region)
        ctrl.__summaryCtrl.Text := this.SystemImageSummaryText(imgKey)
        this.appLogger.Info("已更新系统找图区域: " . imgKey . " " . this.RegionSummary(this.cfg.ImageRegions.%imgKey%))
    }

    OnSystemRegionManagerClose(ctrl, *) {
        ctrl.Gui.Destroy()
    }

    OnSystemRegionManagerGuiClose(guiObj, *) {
        guiObj.Destroy()
    }

    ShowImageRegionDialog(title, defaultImage := "", defaultTimeout := "", initialRegion := "", requireTimeout := true, allowClear := false, tipText := "", allowSim := false, defaultSim := "") {
        if !this.EnsureBoundWindow()
            return ""

        dlg := Gui(, title)
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        state := {
            done: false,
            result: "",
            region: this.NormalizeRegionObject(initialRegion),
            requireTimeout: requireTimeout,
            prompt: requireTimeout ? "请在绑定窗口内拖拽框选找图搜索区域" : "请在绑定窗口内拖拽框选目标地图搜索区域"
        }
        dlg.__state := state

        dlg.Add("Text", "xm ym w80", "图片文件:")
        cmbImage := dlg.Add("ComboBox", "x+8 yp-3 w260", this.ListAssetImages())
        cmbImage.Text := defaultImage
        dlg.__cmbImage := cmbImage

        if (allowSim) {
            dlg.Add("Text", "xm y+14 w80", "相似度:")
            edtSim := dlg.Add("Edit", "x+8 yp-3 w120", defaultSim = "" ? Format("{:.2f}", this.cfg.Bot.Sim) : Format("{:.2f}", Float(defaultSim)))
            dlg.__edtSim := edtSim
        }

        if (requireTimeout) {
            dlg.Add("Text", "xm y+14 w80", "超时(ms):")
            edtTimeout := dlg.Add("Edit", "x+8 yp-3 w120 number", defaultTimeout = "" ? "10000" : String(defaultTimeout))
            dlg.__edtTimeout := edtTimeout
        }

        txtRegion := dlg.Add("Text", "xm y+14 w380", "搜索区域: " . this.RegionSummary(state.region))
        dlg.__txtRegion := txtRegion

        btnPick := dlg.Add("Button", "xm y+10 w120", "框选搜索区域")
        btnPick.OnEvent("Click", ObjBindMethod(this, "OnRegionDialogPick"))

        btnOk := dlg.Add("Button", "xm y+18 w90 Default", "确定")
        btnOk.OnEvent("Click", ObjBindMethod(this, "OnImageRegionDialogOk"))

        if (allowClear) {
            btnClear := dlg.Add("Button", "x+8 yp w90", "清除绑定")
            btnClear.OnEvent("Click", ObjBindMethod(this, "OnImageRegionDialogClear"))
        }

        btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
        btnCancel.OnEvent("Click", ObjBindMethod(this, "OnImageRegionDialogCancel"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnImageRegionDialogCancel"))

        if (tipText = "") {
            tip := requireTimeout
                ? "建议：图片先选资源，再点“框选搜索区域”在绑定窗口内截定局部范围。"
                : "建议：目标地图图也尽量只框选小区域，地图校验会更快。"
        } else {
            tip := tipText
        }
        dlg.Add("Text", "xm y+14 w400 h36", tip)

        dlg.Show("AutoSize Center")
        while !state.done
            Sleep 30
        return state.result
    }

    ShowTextOcrDialog(title, defaultTargetText := "", initialRegion := "", requireTargetText := true) {
        if !this.EnsureBoundWindow()
            return ""

        dlg := Gui(, title)
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        state := {
            done: false,
            result: "",
            region: this.NormalizeRegionObject(initialRegion),
            prompt: "请在绑定窗口内拖拽框选要 OCR 的文字区域",
            requireTargetText: requireTargetText
        }
        dlg.__state := state

        if (requireTargetText) {
            dlg.Add("Text", "xm ym w80", "目标文本:")
            edtText := dlg.Add("Edit", "x+8 yp-3 w280", defaultTargetText)
            dlg.__edtText := edtText
        } else {
            dlg.Add("Text", "xm ym w400 h36", "框选一个区域后，直接查看 OCR 识别出的原始文本。这个模式不做命中判断，只负责把识别结果展示出来。")
        }

        txtRegion := dlg.Add("Text", "xm y+16 w380", "搜索区域: " . this.RegionSummary(state.region))
        dlg.__txtRegion := txtRegion

        btnPick := dlg.Add("Button", "xm y+10 w120", "框选文字区域")
        btnPick.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogPick"))

        btnOk := dlg.Add("Button", "xm y+18 w90 Default", "确定")
        btnOk.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogOk"))

        btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
        btnCancel.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogCancel"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnTextOcrDialogCancel"))

        dlg.Add("Text", "xm y+14 w400 h36", "建议：只框住文字本身，尽量缩小区域。OCR 对纯文字按钮/NPC 名称比图片匹配更稳，但仍会受字号和遮挡影响。")

        dlg.Show("AutoSize Center")
        while !state.done
            Sleep 30
        return state.result
    }

    OnRegionDialogPick(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        if !this.regionTool.Start(this.cfg.Window.Hwnd, ObjBindMethod(this, "OnRegionDialogPicked", dlg), state.prompt)
            MsgBox("无法启动区域框选，请先确认绑定窗口存在。", "提示")
    }

    OnRegionDialogPicked(dlg, region) {
        state := dlg.__state
        state.region := this.NormalizeRegionObject(region)
        dlg.__txtRegion.Text := "搜索区域: " . this.RegionSummary(state.region)
    }

    OnImageRegionDialogOk(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        image := Trim(dlg.__cmbImage.Text)
        if (image = "") {
            MsgBox("请选择或输入图片文件名。", "提示")
            return
        }
        if (!state.region) {
            MsgBox("请先框选搜索区域。", "提示")
            return
        }

        result := {image: image, region: state.region}
        if dlg.HasProp("__edtSim") {
            try simValue := Float(Trim(dlg.__edtSim.Value))
            catch {
                MsgBox("请输入有效的相似度，例如 0.75。", "提示")
                return
            }
            if (simValue < 0.10 || simValue > 1.00) {
                MsgBox("相似度必须在 0.10 到 1.00 之间。", "提示")
                return
            }
            result.sim := simValue
        }
        if (state.requireTimeout) {
            try timeout := Integer(Trim(dlg.__edtTimeout.Value))
            catch {
                MsgBox("请输入有效的整数超时毫秒数。", "提示")
                return
            }
            if (timeout <= 0) {
                MsgBox("超时时间必须大于 0。", "提示")
                return
            }
            result.timeout := timeout
        }

        state.result := result
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        dlg.Destroy()
    }

    OnImageRegionDialogClear(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        state.result := {clear: true}
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        dlg.Destroy()
    }

    OnImageRegionDialogCancel(guiObj, *) {
        state := guiObj.__state
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        guiObj.Destroy()
    }

    OnTextOcrDialogPick(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        if !this.regionTool.Start(this.cfg.Window.Hwnd, ObjBindMethod(this, "OnTextOcrDialogPicked", dlg), state.prompt)
            MsgBox("无法启动区域框选，请先确认绑定窗口存在。", "提示")
    }

    OnTextOcrDialogPicked(dlg, region) {
        state := dlg.__state
        state.region := this.NormalizeRegionObject(region)
        dlg.__txtRegion.Text := "搜索区域: " . this.RegionSummary(state.region)
    }

    OnTextOcrDialogOk(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        targetText := ""
        if (state.requireTargetText) {
            targetText := Trim(dlg.__edtText.Value)
            if (targetText = "") {
                MsgBox("请输入要匹配的目标文本。", "提示")
                return
            }
        }
        if (!state.region) {
            MsgBox("请先框选文字区域。", "提示")
            return
        }

        state.result := {targetText: targetText, region: state.region}
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        dlg.Destroy()
    }

    ShowOcrPreviewResult(region, result) {
        dlg := Gui(, "OCR 识别文本")
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        displayText := this.ocrRecognizer.BuildDisplayText(result.text)
        dlg.__ocrText := displayText

        dlg.Add("Text", "xm ym w420", "区域: " . this.RegionSummary(region))
        if (result.reason = "NO_TEXT")
            dlg.Add("Text", "xm y+8 w420 h36", "这次 OCR 已执行，但没有识别到可用文本。你仍然可以复制下面的结果，方便确认当前返回值。")
        else
            dlg.Add("Text", "xm y+8 w420 h20", "下面是当前区域的 OCR 原始识别结果，可以直接复制。")

        edtText := dlg.Add("Edit", "xm y+10 w420 r10 ReadOnly -Wrap", displayText)
        edtText.Focus()

        btnCopy := dlg.Add("Button", "xm y+14 w90 Default", "复制文本")
        btnCopy.OnEvent("Click", ObjBindMethod(this, "OnOcrPreviewCopy"))

        btnClose := dlg.Add("Button", "x+8 yp w90", "关闭")
        btnClose.OnEvent("Click", ObjBindMethod(this, "OnOcrPreviewClose"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnOcrPreviewClose"))

        dlg.Show("AutoSize Center")
    }

    OnOcrPreviewCopy(ctrl, *) {
        dlg := ctrl.Gui
        A_Clipboard := dlg.__ocrText
        MsgBox("OCR 文本已复制到剪贴板。", "提示")
    }

    OnOcrPreviewClose(guiObj, *) {
        GuiHelper.DestroyOwner(guiObj)
    }

    OnTextOcrDialogCancel(guiObj, *) {
        state := guiObj.__state
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        guiObj.Destroy()
    }

    EnsureBoundWindow() {
        if (this.cfg.Window.Hwnd = "" || this.cfg.Window.Hwnd = "0" || !WinExist("ahk_id " this.cfg.Window.Hwnd)) {
            MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
            return false
        }
        return true
    }

    GetOwnerHwnd() {
        if IsObject(this.guiState) && this.guiState.HasOwnProp("gui")
            return this.guiState.gui.Hwnd
        return 0
    }
}
