#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk
#Include ..\lib\Bot.ahk
#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

WriteStatus(exitCode) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    try {
        if FileExist(statusPath)
            FileDelete(statusPath)
    }
    FileAppend("EXIT=" exitCode, statusPath, "UTF-8")
}

WriteFailure(message) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    FileAppend("`nFAIL=" message, statusPath, "UTF-8")
}

class FakeLogger {
    Info(*) {
    }
    Warn(*) {
    }
    Error(*) {
    }
    State(*) {
    }
}

class FakePlayer {
    Play(*) {
        return true
    }
}

class FakeStore {
    ListScriptsByType(type) {
        return []
    }
    LoadScript(name) {
        return ""
    }
    LoadStoreConfig() {
        return {intervalMinutes: 60, itemNames: [], flowScriptName: ""}
    }
}

class FakeRunner {
    RunScript(script, hwnd, startIndex := 1) {
        return {ok: true}
    }
}

try {
    ; ===== 场景 1：Config.SaveBotSettings 写 ini 并刷新内存 =====
    tmpDir := A_ScriptDir "\tmp_config"
    if !DirExist(tmpDir)
        DirCreate(tmpDir)
    iniPath := tmpDir "\settings_page.ini"
    if FileExist(iniPath)
        FileDelete(iniPath)
    FileAppend("[Bot]`r`nTickMs=500`r`nSim=0.85`r`n", iniPath, "UTF-8-RAW")

    cfg := Config(iniPath)
    if !cfg.SaveBotSettings({TickMs: 700, Sim: 0.66, VerifyMapRetry: 8})
        throw Error("SaveBotSettings should return true for valid values")
    if (cfg.Bot.TickMs != 700 || cfg.Bot.Sim != 0.66 || cfg.Bot.VerifyMapRetry != 8)
        throw Error("SaveBotSettings should refresh in-memory config values")
    reloaded := Config(iniPath)
    if (reloaded.Bot.TickMs != 700 || reloaded.Bot.VerifyMapRetry != 8)
        throw Error("SaveBotSettings should persist values into config.ini")
    if reloaded.SaveBotSettings({Sim: "not-a-number"})
        throw Error("SaveBotSettings with only invalid fields should return false")
    if (reloaded.Bot.Sim != 0.66)
        throw Error("SaveBotSettings should not change Sim when the value is not a number")

    ; ===== 场景 2：设置页控件存在并可从配置加载 =====
    editor := ScriptEditor(Map("cfg", cfg))
    guiObj := editor.Build()
    for _, propName in ["edtSettingsTickMs", "edtSettingsAutoFightRetry", "edtSettingsStoreIntervalMin", "edtSettingsMonitorInterval",
        "edtSettingsSim", "edtSettingsVerifyMapRetry", "edtSettingsVerifyMapInterval", "edtSettingsCheckTownTimeout",
        "edtSettingsScriptMaxFails", "edtSettingsScriptCooldown", "btnSaveSettings", "btnResetSettings"] {
        if !editor.HasProp(propName)
            throw Error("Settings page should expose control " propName)
    }
    if !editor.ShowPage("挂机设置")
        throw Error("ShowPage should accept the settings page")
    if (editor.edtSettingsTickMs.Value != "700")
        throw Error("Entering the settings page should load TickMs from config, got " editor.edtSettingsTickMs.Value)
    if (editor.edtSettingsVerifyMapRetry.Value != "8")
        throw Error("Entering the settings page should load VerifyMapRetry from config")
    if (editor.edtSettingsSim.Value != "0.66")
        throw Error("Entering the settings page should load Sim formatted with two decimals")

    ; ===== 场景 3：保存时非法/越界输入被钳制并持久化 =====
    editor.edtSettingsVerifyMapRetry.Value := "99"
    editor.edtSettingsSim.Value := "5"
    editor.edtSettingsTickMs.Value := "abc"
    editor.HandleSaveSettings()
    if (cfg.Bot.VerifyMapRetry != 20)
        throw Error("Save should clamp VerifyMapRetry to its maximum, got " cfg.Bot.VerifyMapRetry)
    if (cfg.Bot.Sim != 1.00)
        throw Error("Save should clamp Sim to 1.00, got " cfg.Bot.Sim)
    if (cfg.Bot.TickMs != 500)
        throw Error("Save should fall back to default TickMs for invalid input, got " cfg.Bot.TickMs)
    if (editor.edtSettingsVerifyMapRetry.Value != "20")
        throw Error("Save should echo the clamped value back into the edit box")
    if (editor.txtSettingsSaveHint.Text != "已保存到 config.ini，立即生效")
        throw Error("Save should show a success hint")

    ; ===== 场景 4：恢复默认只填默认值不落盘 =====
    persistedTickMs := Config(iniPath).Bot.TickMs
    editor.HandleResetSettings()
    if (editor.edtSettingsVerifyMapRetry.Value != "5" || editor.edtSettingsSim.Value != "0.75")
        throw Error("Reset should fill the default values into the edit boxes")
    if (Config(iniPath).Bot.TickMs != persistedTickMs)
        throw Error("Reset should not write to config.ini until the user saves")

    ; ===== 场景 5：主页运行信息卡可动态更新 =====
    editor.SetBotOverview("运行信息`n状态: 测试中")
    if !InStr(editor.txtHomeTaskCard.Text, "状态: 测试中")
        throw Error("SetBotOverview should update the home task card text")

    ; ===== 场景 6：ParseSettingsNumber 钳制规则 =====
    if (editor.ParseSettingsNumber("abc", 1, 10, 5) != 5)
        throw Error("ParseSettingsNumber should use the fallback for non-numeric input")
    if (editor.ParseSettingsNumber("99", 1, 10, 5) != 10)
        throw Error("ParseSettingsNumber should clamp to the maximum")
    if (editor.ParseSettingsNumber("-3", 1, 10, 5) != 1)
        throw Error("ParseSettingsNumber should clamp to the minimum")
    if (editor.ParseSettingsNumber("0.5", 0.10, 1.00, 0.75, true) != 0.5)
        throw Error("ParseSettingsNumber should parse floats when requested")
    if (editor.ParseSettingsNumber("", 1, 10, 5) != 5)
        throw Error("ParseSettingsNumber should use the fallback for empty input")

    ; ===== 场景 7：Bot.GetRunOverview 汇总运行状态 =====
    botObj := Bot(cfg, FakeLogger(), FakePlayer(), FakeStore(), FakeRunner())
    overview := botObj.GetRunOverview()
    if (overview.state != "Idle" || overview.scriptName != "" || overview.failText != "" || overview.coolText != "")
        throw Error("GetRunOverview should return empty details for a fresh bot")
    botObj.currentScript := {name: "图1"}
    botObj.scriptFailCounts := Map("图1", 2)
    botObj.scriptCooldowns := Map("图2", A_TickCount + 300000, "过期图", A_TickCount - 1000)
    detail := botObj.GetRunOverview()
    if (detail.scriptName != "图1")
        throw Error("GetRunOverview should report the current script name")
    if !InStr(detail.failText, "图1 x2")
        throw Error("GetRunOverview should report consecutive failure counts")
    if !InStr(detail.coolText, "图2")
        throw Error("GetRunOverview should report scripts still cooling down")
    if InStr(detail.coolText, "过期图")
        throw Error("GetRunOverview should not report expired cooldowns")

    guiObj.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    WriteStatus(1)
    WriteFailure(err.Message)
    ExitApp(1)
}
