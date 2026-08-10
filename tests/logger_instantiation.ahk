#Requires AutoHotkey v2.0

#Include ..\lib\Logger.ahk

logDir := A_ScriptDir "\tmp_logs"
appLogger := Logger(logDir)

if !IsObject(appLogger)
    throw Error("Logger() did not return an object")

ExitApp(0)
