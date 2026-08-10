#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk

tempDir := A_ScriptDir "\tmp_config"
if !DirExist(tempDir)
    DirCreate(tempDir)

iniPath := tempDir "\config_bot_sim.ini"
if FileExist(iniPath)
    FileDelete(iniPath)

initialIni :=
(
"[Bot]`r`n"
"Sim=0.85`r`n"
)
FileAppend initialIni, iniPath, "UTF-8-RAW"

cfgObj := Config(iniPath)
cfgObj.SaveBotSim(0.68)

reloadedCfg := Config(iniPath)
if (reloadedCfg.Bot.Sim != 0.68)
    throw Error("Config should reload saved bot sim")

savedText := FileRead(iniPath, "UTF-8")
if !InStr(savedText, "Sim=0.68")
    throw Error("Config should persist bot sim with two decimals")

ExitApp(0)
