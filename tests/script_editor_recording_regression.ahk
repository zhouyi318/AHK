#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

class FakeRecorders {
    __New() {
        this.calls := []
    }

    RecordNextClick(hwnd, onRecorded) {
        this.calls.Push("click:" hwnd)
        onRecorded.Call({
            id: "step_click_1",
            type: "click",
            name: "点击",
            enabled: true,
            params: {x: 120, y: 230, button: "L", delay: 450},
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        })
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

    if !editor.RecordNextClickStep()
        throw Error("RecordNextClickStep should delegate to StepRecorders")
    if !editor.RecordKeypressStep()
        throw Error("RecordKeypressStep should append a keypress step")
    if (editor.currentScript.steps.Length != 2)
        throw Error("Recording actions should append standard steps to the current script")
    if (editor.currentScript.steps[1].params.x != 120 || editor.currentScript.steps[1].params.y != 230)
        throw Error("Recorded click step should preserve captured coordinates")
    if (editor.currentScript.steps[2].params.keyName != "F8")
        throw Error("Recorded keypress step should preserve captured key info")
    if (recorders.calls[1] != "click:456" || recorders.calls[2] != "keypress")
        throw Error("Recording actions should invoke the recorder service with the bound hwnd")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
