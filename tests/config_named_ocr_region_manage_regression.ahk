#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk

resultPath := A_ScriptDir "\tmp_config\config_named_ocr_region_manage_result.txt"

try {
    tempDir := A_ScriptDir "\tmp_config"
    if !DirExist(tempDir)
        DirCreate(tempDir)

    iniPath := tempDir "\config_named_ocr_region_manage.ini"
    if FileExist(iniPath)
        FileDelete(iniPath)
    if FileExist(resultPath)
        FileDelete(resultPath)

    FileAppend "[Window]`r`nHwnd=123`r`n", iniPath, "UTF-8-RAW"

    cfgObj := Config(iniPath)
    cfgObj.SaveNamedOcrRegion("人物坐标", {x1: 10, y1: 20, x2: 100, y2: 60})
    cfgObj.SaveNamedOcrRegion("NPC名称", {x1: 5, y1: 6, x2: 60, y2: 30})

    if !cfgObj.DeleteNamedOcrRegion("人物坐标")
        throw Error("DeleteNamedOcrRegion should return true for an existing region")
    if cfgObj.OcrRegions.Has("人物坐标")
        throw Error("DeleteNamedOcrRegion should remove the region from memory")
    if cfgObj.DeleteNamedOcrRegion("人物坐标")
        throw Error("DeleteNamedOcrRegion should return false for a missing region")

    if !cfgObj.RenameNamedOcrRegion("NPC名称", "背包金币")
        throw Error("RenameNamedOcrRegion should return true for an existing region")
    if !cfgObj.OcrRegions.Has("背包金币")
        throw Error("RenameNamedOcrRegion should expose the new name in memory")
    if cfgObj.OcrRegions.Has("NPC名称")
        throw Error("RenameNamedOcrRegion should remove the old name from memory")
    if (cfgObj.OcrRegions["背包金币"].x1 != 5 || cfgObj.OcrRegions["背包金币"].y2 != 30)
        throw Error("RenameNamedOcrRegion should keep the region coordinates")
    if cfgObj.RenameNamedOcrRegion("不存在", "随便")
        throw Error("RenameNamedOcrRegion should return false for a missing source name")
    if cfgObj.RenameNamedOcrRegion("背包金币", "")
        throw Error("RenameNamedOcrRegion should reject empty target names")

    cfgObj.SaveNamedOcrRegion("血量", {x1: 1, y1: 2, x2: 9, y2: 8})
    if cfgObj.RenameNamedOcrRegion("背包金币", "血量")
        throw Error("RenameNamedOcrRegion should refuse overwriting an existing target name")

    savedText := FileRead(iniPath, "UTF-8")
    if InStr(savedText, "人物坐标")
        throw Error("DeleteNamedOcrRegion should remove the key from the ini file")
    if InStr(savedText, "NPC名称")
        throw Error("RenameNamedOcrRegion should remove the old key from the ini file")
    if !InStr(savedText, "背包金币=5,6,60,30")
        throw Error("RenameNamedOcrRegion should persist the renamed key")
    if !InStr(savedText, "血量=1,2,9,8")
        throw Error("RenameNamedOcrRegion should keep other regions untouched")

    reloaded := Config(iniPath)
    names := reloaded.ListNamedOcrRegionNames()
    if (names.Length != 2)
        throw Error("Reloaded config should list two named regions")
    if (names[1] != "背包金币" || names[2] != "血量")
        throw Error("Reloaded config should list regions sorted by name")
    if (reloaded.OcrRegions["背包金币"].x1 != 5)
        throw Error("Reloaded renamed region mismatch")

    FileAppend "PASS", resultPath, "UTF-8-RAW"
    ExitApp(0)
} catch as err {
    FileAppend "FAIL: " err.Message, resultPath, "UTF-8-RAW"
    ExitApp(1)
}
