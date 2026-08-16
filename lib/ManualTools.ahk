#Requires AutoHotkey v2.0

class ManualTools {
    __New(deps) {
        this.deps := deps
        this.cfg := deps.Has("cfg") ? deps["cfg"] : ""
        this.appLogger := deps.Has("logger") ? deps["logger"] : ""
        this.playback := deps.Has("playback") ? deps["playback"] : ""
        this.ocrRecognizer := deps.Has("ocrRecognizer") ? deps["ocrRecognizer"] : ""
        this.regionTool := deps.Has("regionTool") ? deps["regionTool"] : ""
        this.pointTool := deps.Has("pointTool") ? deps["pointTool"] : ""
        this.guiState := deps.Has("guiState") ? deps["guiState"] : ""
        this.regionManagerGui := ""
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

        usePreprocess := info.HasProp("preprocess") ? info.preprocess : true
        result := this.ocrRecognizer.Recognize(this.cfg.Window.Hwnd, info.region, info.targetText, "手动 OCR 找字", usePreprocess)
        if result.ok {
            displayText := this.ocrRecognizer.BuildDisplayText(result.text)
            if (result.reason = "NO_TEXT") {
                MsgBox("OCR 已执行，但这个区域里没有识别到可用文本。`n`n目标文本: " . info.targetText . "`n区域: " . this.RegionSummary(info.region) . "`n预处理: " . (usePreprocess ? "是" : "否") . "`n`n识别文本:`n" . displayText . "`n`n这通常说明框选区域太大/太小、文字太糊、颜色对比不够，或者刚好没框到字。", "测试结果")
            } else {
                matchedText := result.matched ? "命中" : "未命中"
                MsgBox("OCR 成功：`n目标文本: " . info.targetText . "`n匹配结果: " . matchedText . "`n区域: " . this.RegionSummary(info.region) . "`n预处理: " . (usePreprocess ? "是" : "否") . "`n`n识别文本:`n" . displayText, "测试结果")
            }
        } else {
            MsgBox("OCR 失败：`n目标文本: " . info.targetText . "`n区域: " . this.RegionSummary(info.region) . "`n预处理: " . (usePreprocess ? "是" : "否") . "`n错误: " . result.error, "测试结果")
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

        result := this.ocrRecognizer.Recognize(this.cfg.Window.Hwnd, info.region, "", "查看 OCR 文本", info.HasProp("preprocess") ? info.preprocess : true)
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
            else
                throw Error("onBotSimChanged must be a callable object, not a string")
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
            requireTargetText: requireTargetText,
            preprocess: true
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

        btnUseNamed := dlg.Add("Button", "x+8 yp w120", "引用已保存区域")
        btnUseNamed.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogUseNamedRegion"))

        chkPreprocess := dlg.Add("CheckBox", "xm y+10 w380", "启用图像预处理（灰度+二值化+放大，适合传奇私服游戏文字）")
        chkPreprocess.Value := 1
        chkPreprocess.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogPreprocessToggle"))
        dlg.__chkPreprocess := chkPreprocess

        btnOk := dlg.Add("Button", "xm y+18 w90 Default", "确定")
        btnOk.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogOk"))

        btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
        btnCancel.OnEvent("Click", ObjBindMethod(this, "OnTextOcrDialogCancel"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnTextOcrDialogCancel"))

        dlg.Add("Text", "xm y+14 w400 h36", "建议：只框住文字本身，尽量缩小区域。传奇私服建议开启图像预处理。")

        dlg.Show("AutoSize Center")
        while !state.done
            Sleep 30
        return state.result
    }

    ShowClientPointDialog(title, initialPoint := "", prompt := "") {
        if !this.EnsureBoundWindow()
            return ""
        if !IsObject(this.pointTool)
            return ""

        state := {done: false, result: ""}
        pickPrompt := Trim(prompt)
        if (pickPrompt = "")
            pickPrompt := title != "" ? title : "请在绑定窗口内点一下要记录的位置"
        if IsObject(initialPoint) && initialPoint.HasProp("x") && initialPoint.HasProp("y")
            pickPrompt .= "`n当前: " initialPoint.x "," initialPoint.y

        if !this.pointTool.Start(this.cfg.Window.Hwnd, ObjBindMethod(this, "OnClientPointPicked", state), pickPrompt)
            return ""

        while (!state.done && this.pointTool.active)
            Sleep 30
        return state.done ? state.result : ""
    }

    OnClientPointPicked(state, point) {
        state.result := point
        state.done := true
        if IsObject(this.pointTool) && this.pointTool.active
            this.pointTool.Stop(false)
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

    OnTextOcrDialogUseNamedRegion(ctrl, *) {
        dlg := ctrl.Gui
        regionInfo := this.ChooseNamedOcrRegion()
        if !IsObject(regionInfo)
            return
        state := dlg.__state
        state.region := this.NormalizeRegionObject(regionInfo.region)
        dlg.__txtRegion.Text := "搜索区域: " . this.RegionSummary(state.region) . " [" . regionInfo.name . "]"
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

        state.result := {targetText: targetText, region: state.region, preprocess: state.preprocess}
        state.done := true
        if (this.regionTool.active)
            this.regionTool.Stop(false)
        dlg.Destroy()
    }

    OnTextOcrDialogPreprocessToggle(ctrl, *) {
        ctrl.Gui.__state.preprocess := ctrl.Value
    }

    ShowOcrPreviewResult(region, result) {
        dlg := Gui(, "OCR 识别文本")
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        displayText := this.ocrRecognizer.BuildDisplayText(result.text)
        dlg.__ocrText := displayText
        dlg.__ocrRegion := this.NormalizeRegionObject(region)

        dlg.Add("Text", "xm ym w420", "区域: " . this.RegionSummary(region))
        if (result.reason = "NO_TEXT")
            dlg.Add("Text", "xm y+8 w420 h36", "这次 OCR 已执行，但没有识别到可用文本。你仍然可以复制下面的结果，方便确认当前返回值。")
        else
            dlg.Add("Text", "xm y+8 w420 h20", "下面是当前区域的 OCR 原始识别结果，可以直接复制。")

        edtText := dlg.Add("Edit", "xm y+10 w420 r10 ReadOnly -Wrap", displayText)
        edtText.Focus()

        btnCopy := dlg.Add("Button", "xm y+14 w90 Default", "复制文本")
        btnCopy.OnEvent("Click", ObjBindMethod(this, "OnOcrPreviewCopy"))

        btnSaveRegion := dlg.Add("Button", "x+8 yp w140", "保存为命名 OCR 区域")
        btnSaveRegion.OnEvent("Click", ObjBindMethod(this, "OnOcrPreviewSaveRegion"))

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

    OnOcrPreviewSaveRegion(ctrl, *) {
        dlg := ctrl.Gui
        region := dlg.__ocrRegion
        if !region {
            MsgBox("当前没有可保存的 OCR 区域。", "提示")
            return
        }
        ib := InputBox("请输入 OCR 区域名称，后续写脚本时可直接引用：", "保存命名 OCR 区域")
        if (ib.Result = "Cancel")
            return
        name := Trim(ib.Value)
        if (name = "") {
            MsgBox("区域名称不能为空。", "提示")
            return
        }
        if !this.SaveNamedOcrRegion(name, region) {
            MsgBox("保存失败，请确认当前区域和配置对象有效。", "提示")
            return
        }
        if IsObject(this.appLogger)
            this.appLogger.Info("已保存命名 OCR 区域: " . name . " " . this.RegionSummary(region))
        MsgBox("已保存命名 OCR 区域：" . name, "提示")
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

    ChooseNamedOcrRegion() {
        if !(IsObject(this.cfg) && this.cfg.HasProp("OcrRegions"))
            return ""
        names := this.cfg.ListNamedOcrRegionNames()
        if (names.Length = 0) {
            MsgBox("还没有保存过命名 OCR 区域。请先在“查看 OCR 文本”结果里保存一块区域。", "提示")
            return ""
        }

        dlg := Gui(, "选择命名 OCR 区域")
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")
        state := {done: false, result: ""}
        dlg.__state := state

        dlg.Add("Text", "xm ym w360 h36", "请选择一块已经确认过的 OCR 区域。选中后会直接带入当前 OCR 或坐标识别配置。")
        listText := ""
        for index, name in names
            listText .= (index = 1 ? "" : "|") . name
        lbNames := dlg.Add("ListBox", "xm y+10 w360 r8", StrSplit(listText, "|"))
        lbNames.Choose(1)
        dlg.__lbNames := lbNames

        btnUse := dlg.Add("Button", "xm y+14 w90 Default", "使用")
        btnUse.OnEvent("Click", ObjBindMethod(this, "OnChooseNamedOcrRegionOk"))

        btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
        btnCancel.OnEvent("Click", ObjBindMethod(this, "OnChooseNamedOcrRegionCancel"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnChooseNamedOcrRegionCancel"))

        btnManage := dlg.Add("Button", "x+8 yp w120", "管理已保存区域")
        btnManage.OnEvent("Click", ObjBindMethod(this, "ShowNamedOcrRegionManager"))

        dlg.Show("AutoSize Center")
        while !state.done
            Sleep 30
        return state.result
    }

    OnChooseNamedOcrRegionOk(ctrl, *) {
        dlg := ctrl.Gui
        state := dlg.__state
        name := Trim(dlg.__lbNames.Text)
        if (name = "") {
            MsgBox("请先选择一个已保存区域。", "提示")
            return
        }
        if !this.cfg.OcrRegions.Has(name) {
            MsgBox("所选区域不存在，请重新选择。", "提示")
            return
        }
        state.result := {name: name, region: this.cfg.OcrRegions[name]}
        state.done := true
        dlg.Destroy()
    }

    OnChooseNamedOcrRegionCancel(guiObj, *) {
        state := guiObj.__state
        state.done := true
        guiObj.Destroy()
    }

    SaveNamedOcrRegion(name, region) {
        if !(IsObject(this.cfg) && this.cfg.HasProp("OcrRegions"))
            return false
        return this.cfg.SaveNamedOcrRegion(name, region)
    }

    DeleteNamedOcrRegion(name) {
        if !(IsObject(this.cfg) && this.cfg.HasProp("OcrRegions"))
            return false
        return this.cfg.DeleteNamedOcrRegion(name)
    }

    RenameNamedOcrRegion(oldName, newName) {
        if !(IsObject(this.cfg) && this.cfg.HasProp("OcrRegions"))
            return false
        return this.cfg.RenameNamedOcrRegion(oldName, newName)
    }

    ShowNamedOcrRegionManager() {
        if !(IsObject(this.cfg) && this.cfg.HasProp("OcrRegions")) {
            MsgBox("配置对象不可用，无法管理已保存的 OCR 区域。", "提示")
            return
        }
        this.RebuildNamedOcrRegionManager()
    }

    RebuildNamedOcrRegionManager() {
        if IsObject(this.regionManagerGui)
            this.regionManagerGui.Destroy()

        names := this.cfg.ListNamedOcrRegionNames()
        dlg := Gui(, "管理已保存 OCR 区域")
        dlg.Opt("+Owner" this.GetOwnerHwnd())
        dlg.SetFont("s10")

        if (names.Length = 0) {
            dlg.Add("Text", "xm ym w460 h36", "还没有保存过命名 OCR 区域。请先在“查看 OCR 文本”结果里保存一块区域。")
        } else {
            dlg.Add("Text", "xm ym w460 h22", "已保存的 OCR 区域列表。重命名或删除后立即生效，已写入脚本的步骤不受影响。")
            for _, name in names {
                region := this.cfg.OcrRegions[name]
                dlg.Add("Text", "xm y+12 w170 h22", name ":")
                dlg.Add("Text", "x+8 yp w160 h22", this.RegionSummary(region))
                btnRename := dlg.Add("Button", "x+8 yp-4 w80", "重命名")
                btnRename.__regionName := name
                btnRename.OnEvent("Click", ObjBindMethod(this, "OnNamedOcrRegionRename"))
                btnDelete := dlg.Add("Button", "x+8 yp w80", "删除")
                btnDelete.__regionName := name
                btnDelete.OnEvent("Click", ObjBindMethod(this, "OnNamedOcrRegionDelete"))
            }
        }

        btnClose := dlg.Add("Button", "xm y+18 w90 Default", "关闭")
        btnClose.OnEvent("Click", ObjBindMethod(this, "OnNamedOcrRegionManagerClose"))
        dlg.OnEvent("Close", ObjBindMethod(this, "OnNamedOcrRegionManagerClose"))

        this.regionManagerGui := dlg
        dlg.Show("AutoSize Center")
    }

    OnNamedOcrRegionRename(ctrl, *) {
        name := ctrl.__regionName
        ib := InputBox("请输入新的区域名称：", "重命名 OCR 区域", , name)
        if (ib.Result = "Cancel")
            return
        newName := Trim(ib.Value)
        if (newName = "" || newName = name)
            return
        if !this.RenameNamedOcrRegion(name, newName) {
            MsgBox("重命名失败：新名称可能已存在，或原区域已被移除。", "提示")
            return
        }
        if IsObject(this.appLogger)
            this.appLogger.Info("已重命名命名 OCR 区域: " name " -> " newName)
        this.RebuildNamedOcrRegionManager()
    }

    OnNamedOcrRegionDelete(ctrl, *) {
        name := ctrl.__regionName
        result := MsgBox("确定删除已保存区域「" name "」吗？已写入脚本的步骤不受影响。", "删除 OCR 区域", "YesNo Icon! Default2")
        if (result != "Yes")
            return
        if !this.DeleteNamedOcrRegion(name) {
            MsgBox("删除失败：区域可能已被移除。", "提示")
            return
        }
        if IsObject(this.appLogger)
            this.appLogger.Info("已删除命名 OCR 区域: " name)
        this.RebuildNamedOcrRegionManager()
    }

    OnNamedOcrRegionManagerClose(guiObj, *) {
        guiObj.Destroy()
        this.regionManagerGui := ""
    }

    HandleCaptureCoordTemplates(*) {
        if !this.EnsureBoundWindow()
            return

        ; Ask for the expected coordinate text
        coordText := InputBox("请输入当前坐标框内显示的实际坐标值（例如 334:333）。`n`n确保你在游戏中能看到坐标数字，并且已经绑定了正确的窗口。", "截取坐标模板", "w400 h160")
        if (coordText.Result != "OK" || Trim(coordText.Value) = "")
            return

        label := Trim(coordText.Value)
        ; Validate format: digits:digits or digits,digits
        if !RegExMatch(label, "^\d{2,4}[:.,]\d{2,4}$") {
            MsgBox("坐标格式不正确。请使用类似 334:333 或 334,333 的格式。", "提示")
            return
        }

        ; Replace common separators with colon
        label := RegExReplace(label, "[.,]", ":")
        digitCount := StrLen(StrReplace(label, ":", ""))

        ; Use the region picker to select the coordinate area
        hwnd := this.cfg.Window.Hwnd
        WinActivate "ahk_id " hwnd
        Sleep 150
        this.regionTool.Start(hwnd, ObjBindMethod(this, "OnCaptureCoordTemplateRegionPicked"), "按住鼠标左键拖拽框选坐标数字，松手完成截取。ESC 取消")
        this._captureCoordLabel := label
        if IsObject(this.appLogger)
            this.appLogger.Info("模板截取: 请在游戏窗口内框选坐标数字区域（期望值: " label "）")
    }

    OnCaptureCoordTemplateRegionPicked(region) {
        label := this._captureCoordLabel
        this._captureCoordLabel := ""

        hwnd := this.cfg.Window.Hwnd
        rect := this.ocrRecognizer.ResolveScreenRect(hwnd, region)
        if !rect {
            MsgBox("无法获取屏幕坐标，请重试。", "错误")
            return
        }

        pythonPath := this.ocrRecognizer.rapidPythonPath
        captureScript := this.ocrRecognizer.rootDir "\lib\coord_template_capture.py"
        cmd := this.ocrRecognizer.QuoteArg(pythonPath)
            . " " this.ocrRecognizer.QuoteArg(captureScript)
            . " --x " rect.x
            . " --y " rect.y
            . " --width " rect.width
            . " --height " rect.height
            . " --label " this.ocrRecognizer.QuoteArg(label)

        if IsObject(this.appLogger)
            this.appLogger.Info("模板截取: 执行 " cmd)
        try {
            shell := ComObject("WScript.Shell")
            shell.Run(cmd, 1, true)
            templateDir := this.ocrRecognizer.coordTemplateDir

            ; Show capture error if the python script aborted (split mismatch)
            errFile := templateDir "\_capture_error.txt"
            if FileExist(errFile) {
                try {
                    errText := FileRead(errFile, "UTF-8")
                    MsgBox("模板截取失败！`n`n" errText, "模板截取")
                    return
                }
            }

            ; Check what was actually created
            createdFiles := ""
            missingFiles := ""
            loop 10 {
                fname := templateDir "\" (A_Index - 1) ".png"
                if FileExist(fname)
                    createdFiles .= (createdFiles = "" ? "" : ", ") (A_Index - 1)
                else
                    missingFiles .= (missingFiles = "" ? "" : ", ") (A_Index - 1)
            }
            colonFile := templateDir "\colon.png"
            if FileExist(colonFile)
                createdFiles .= ", :"
            else
                missingFiles .= ", :"

            msg := "模板截取完成！`n`n期望坐标: " label
            if (createdFiles != "")
                msg .= "`n已生成: " createdFiles
            if (missingFiles != "")
                msg .= "`n缺失: " missingFiles "`n`n请在游戏中去一个包含缺失数字的坐标，重新截取。"
            else
                msg .= "`n`n模板已全部生成！点击「读坐标」按钮测试效果。"
            MsgBox(msg, "模板截取")
        } catch as err {
            MsgBox("模板截取失败: " err.Message, "错误")
        }
    }

    OnCaptureCoordTemplateRegionCancelled(*) {
        this._captureCoordLabel := ""
        if IsObject(this.appLogger)
            this.appLogger.Info("模板截取: 已取消")
    }

    HandleReadCoord(*) {
        if !this.EnsureBoundWindow()
            return

        hwnd := this.cfg.Window.Hwnd
        WinActivate "ahk_id " hwnd
        Sleep 150
        this.regionTool.Start(hwnd, ObjBindMethod(this, "OnReadCoordRegionPicked"), "框选坐标数字区域，松手即读")
    }

    OnReadCoordRegionPicked(region) {
        hwnd := this.cfg.Window.Hwnd

        ; Check if templates exist, use them if available
        hasTemplates := this.ocrRecognizer.HasCoordTemplates()
        method := hasTemplates ? "模板匹配" : "OCR"

        if hasTemplates {
            result := this.ocrRecognizer.ReadCoordByTemplate(hwnd, region)
        } else {
            result := this.ocrRecognizer.Recognize(hwnd, region, "", "读坐标-OCR", true)
        }

        if !result.ok {
            MsgBox("读取失败 [" method "]`n`n错误: " result.error, "读坐标")
            return
        }
        if (Trim(result.text) = "") {
            MsgBox("未识别到文本 [" method "]`n`n区域可能没有文字，请重新框选。", "读坐标")
            return
        }

        ; Try to parse as coordinates
        parsed := this.ParseCoordTextForDisplay(result.text)
        displayText := "原始文本: " result.text "`n`n"
        if parsed.ok {
            displayText .= "解析坐标: " parsed.x "," parsed.y
        } else {
            displayText .= "解析: 无法识别为坐标格式"
        }
        displayText .= "`n`n识别方式: " method
        if hasTemplates {
            displayText .= "`n模板目录: " this.ocrRecognizer.coordTemplateDir
        } else {
            displayText .= "`n提示: 点击「截模板」创建模板后可获得更高准确率"
        }

        MsgBox(displayText, "读坐标 - " method)
    }

    ParseCoordTextForDisplay(rawText) {
        text := StrUpper(rawText)
        text := StrReplace(text, "O", "0")
        text := StrReplace(text, "I", "1")
        text := StrReplace(text, "L", "1")
        text := StrReplace(text, "S", "5")
        text := StrReplace(text, "Z", "2")
        text := StrReplace(text, "B", "8")
        text := StrReplace(text, ":", " ")
        text := StrReplace(text, ",", " ")
        text := RegExReplace(text, "\s+", " ")
        text := RegExReplace(text, "[^0-9 ]", "")
        text := Trim(text)
        text := StrReplace(text, " ", ",")

        if RegExMatch(text, "(\d{1,4})\D+(\d{1,4})", &m) {
            return {ok: true, x: Integer(m[1]), y: Integer(m[2])}
        }
        if RegExMatch(text, "^\d{4,6}$") {
            mid := Floor(StrLen(text) / 2)
            return {ok: true, x: Integer(SubStr(text, 1, mid)), y: Integer(SubStr(text, mid + 1))}
        }
        return {ok: false}
    }
}
