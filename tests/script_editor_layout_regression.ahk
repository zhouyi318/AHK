#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

GetBottom(ctrl) {
    ctrl.GetPos(, &y, , &h)
    return y + h
}

try {
    editor := ScriptEditor(Map())
    guiObj := editor.Build()

    editor.pnlNav.GetPos(&navX, &navY, &navW, &navH)
    editor.pnlWorkspace.GetPos(&workX, &workY, &workW, &workH)
    editor.pnlStatus.GetPos(&statusX, &statusY, &statusW, &statusH)
    editor.txtWindowSummary.GetPos(&summaryX, &summaryY, &summaryW, &summaryH)
    editor.edtLog.GetPos(&logX, &logY, &logW, &logH)

    if !(navX < workX && workX < statusX)
        throw Error("The redesigned layout should keep navigation, workspace, and status columns in order")
    if (summaryX < statusX || summaryX > statusX + statusW)
        throw Error("Window summary should live inside the status column")
    if (logX < statusX || logX > statusX + statusW)
        throw Error("Log summary should live inside the status column")
    if (logY <= summaryY)
        throw Error("Log summary should be placed below the status summary controls")
    if (workW <= statusW)
        throw Error("The workspace column should stay wider than the status column")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
