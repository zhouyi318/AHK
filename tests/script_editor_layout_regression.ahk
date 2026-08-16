#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

statusPath := A_ScriptDir "\tmp_script_editor_layout_status.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

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
    editor.lstScripts.GetPos(&scriptListX, &scriptListY, &scriptListW, &scriptListH)
    editor.txtWindowSummary.GetPos(&summaryX, &summaryY, &summaryW, &summaryH)
    editor.edtLog.GetPos(&logX, &logY, &logW, &logH)
    editor.btnAddMoveToCoord.GetPos(&addNavX, &addNavY, &addNavW, &addNavH)
    editor.btnPickMoveCoordRegion.GetPos(&pickRegionX, &pickRegionY, &pickRegionW, &pickRegionH)
    editor.btnTestMoveToCoord.GetPos(&testMoveX, &testMoveY, &testMoveW, &testMoveH)
    editor.pnlProps.GetPos(&propsX, &propsY, &propsW, &propsH)

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
    if (statusW >= 250)
        throw Error("The status column should be tightened compared with the earlier wide layout")
    if (scriptListW >= 170)
        throw Error("The script list should be narrowed to free more room for the step workspace")
    if (pickRegionY <= addNavY)
        throw Error("Move-to-coord helper actions should move onto a new row below the +导航 entry button")
    if (testMoveY != pickRegionY)
        throw Error("The simplified navigation helper tools should stay on one aligned row")
    if (propsY <= pickRegionY)
        throw Error("The step summary panel should sit below the navigation helper rows instead of crowding their right side")

    guiObj.Destroy()
    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    FileAppend("FAIL: " . err.Message . " | what=" . err.What . " | file=" . err.File . " | line=" . err.Line, statusPath, "UTF-8")
    ExitApp(1)
}
