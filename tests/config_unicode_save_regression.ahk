#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk

resultPath := A_ScriptDir "\tmp_config\config_unicode_result.txt"

try {
    tempDir := A_ScriptDir "\tmp_config"
    if !DirExist(tempDir)
        DirCreate(tempDir)

    iniPath := tempDir "\config_unicode.ini"
    if FileExist(iniPath)
        FileDelete(iniPath)
    if FileExist(resultPath)
        FileDelete(resultPath)

    initialIni :=
    (
    "; test config`r`n"
    "`r`n"
    "[Window]`r`n"
    "ExeName=old.exe`r`n"
    "Title=Old Title`r`n"
    "Hwnd=1`r`n"
    "ExpectedWidth=1280`r`n"
    "ExpectedHeight=720`r`n"
    )
    FileAppend initialIni, iniPath, "UTF-8-RAW"

    expectedTitle := "火山方舟 - Coding Plan - Google Chrome"
    cfgObj := Config(iniPath)
    cfgObj.SaveWindow("chrome.exe", expectedTitle, 330282, 1931, 1111)

    savedText := FileRead(iniPath, "UTF-8")
    if !InStr(savedText, "Title=" expectedTitle)
        throw Error("Config.SaveWindow() should preserve UTF-8 title text")

    reloadedCfg := Config(iniPath)
    if (reloadedCfg.Window.Title != expectedTitle)
        throw Error("Config should reload saved UTF-8 title correctly")

    FileAppend "PASS", resultPath, "UTF-8-RAW"
    ExitApp(0)
} catch as err {
    FileAppend "FAIL: " err.Message, resultPath, "UTF-8-RAW"
    ExitApp(1)
}
