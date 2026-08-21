#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

class FakeRecorders {
    __New() {
        this.calls := []
        this.pendingMouseCallback := ""
    }

    RecordMouseSequence(hwnd, onCompleted) {
        this.calls.Push("mouse:" hwnd)
        this.pendingMouseCallback := onCompleted
        return true
    }

    CompleteMouseSequence() {
        callback := this.pendingMouseCallback
        this.pendingMouseCallback := ""
        if !callback
            return
        callback.Call([
            {
                id: "step_click_1",
                type: "click",
                name: "点击",
                enabled: true,
                params: {x: 120, y: 230, button: "L", delay: 450, repeat: 3, intervalMs: 90},
                onSuccess: {action: "next"},
                onFailure: {action: "stop"}
            },
            {
                id: "step_hold_1",
                type: "mouse_action",
                name: "按住",
                enabled: true,
                params: {x: 140, y: 260, button: "R", action: "hold", holdMs: 800, delay: 120},
                onSuccess: {action: "next"},
                onFailure: {action: "stop"}
            }
        ])
    }

    StopMouseSequence() {
        this.calls.Push("stop-mouse")
        callback := this.pendingMouseCallback
        this.pendingMouseCallback := ""
        if callback
            callback.Call([])
        return true
    }

    PromptKeypressStep() {
        this.calls.Push("keypress")
        return {
            id: "step_key_1",
            type: "keypress",
            name: "按键",
            enabled: true,
            params: {keyName: "F8", repeat: 2},
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }
}

try {
    scriptsDir := A_ScriptDir "\tmp_editor_recording"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    recorders := FakeRecorders()
    cfg := {Window: {Hwnd: 456}}
    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema, "recorders", recorders, "cfg", cfg))
    guiObj := editor.Build()
    editor.CreateAndPersistScript("录制测试", "enter_map")

    if !editor.HasProp("btnRecordClick")
        throw Error("Build should restore the click recording button")
    if !editor.HasProp("btnRecordKey")
        throw Error("Build should restore the keypress recording button")

    if !editor.StartMouseRecording()
        throw Error("StartMouseRecording should delegate to StepRecorders")
    if (editor.btnRecordClick.Text != "停止录制（ESC）")
        throw Error("Mouse recording should update the record button text while recording is active")
    if (editor.txtRunState.Text != "当前状态：录制鼠标中")
        throw Error("Mouse recording should update the run-state hint while recording is active")
    if !InStr(editor.txtStatusContext.Text, "按 ESC 停止")
        throw Error("Mouse recording should expose an ESC stop hint in the status context")
    recorders.CompleteMouseSequence()
    if !editor.RecordKeypressStep()
        throw Error("RecordKeypressStep should append a keypress step")
    if (editor.currentScript.steps.Length != 3)
        throw Error("Recording actions should append the full recorded mouse sequence plus the keypress step")
    if (editor.currentScript.steps[1].params.repeat != 3 || editor.currentScript.steps[1].params.intervalMs != 90)
        throw Error("Recorded click step should preserve aggregated rapid-click metadata")
    if (editor.currentScript.steps[2].type != "mouse_action")
        throw Error("Recorded mouse hold should be appended as a standard mouse_action step")
    if (editor.currentScript.steps[2].params.holdMs != 800)
        throw Error("Recorded mouse hold step should preserve hold duration")
    if (editor.currentScript.steps[3].params.keyName != "F8")
        throw Error("Recorded keypress step should preserve captured key info")
    if (recorders.calls[1] != "mouse:456" || recorders.calls[2] != "keypress")
        throw Error("Recording actions should invoke the recorder service with the bound hwnd")
    if (editor.btnRecordClick.Text != "录制点击")
        throw Error("Mouse recording completion should restore the record button text")
    if (editor.txtRunState.Text != "当前状态：已录制 2 个鼠标步骤")
        throw Error("Mouse recording completion should update the run-state hint")
    if !InStr(editor.txtStatusContext.Text, "最近一次录制：已录制 2 个鼠标步骤")
        throw Error("Mouse recording completion should update the status context with the recording summary")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
