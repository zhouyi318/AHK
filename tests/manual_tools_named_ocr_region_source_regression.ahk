#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\lib\ManualTools.ahk", "UTF-8")

    if !InStr(source, '保存为命名 OCR 区域')
        throw Error("ManualTools should allow saving an OCR preview region as a named OCR region")
    if !InStr(source, '引用已保存区域')
        throw Error("ManualTools should allow reusing a saved OCR region by name in the OCR dialog")
    if !InStr(source, "SaveNamedOcrRegion(")
        throw Error("ManualTools should expose a helper to save named OCR regions")
    if !InStr(source, "ChooseNamedOcrRegion(")
        throw Error("ManualTools should expose a helper to choose named OCR regions")
    if !InStr(source, "ShowNamedOcrRegionManager(")
        throw Error("ManualTools should expose a manager dialog for saved OCR regions")
    if !InStr(source, "DeleteNamedOcrRegion(")
        throw Error("ManualTools should support deleting saved OCR regions")
    if !InStr(source, "RenameNamedOcrRegion(")
        throw Error("ManualTools should support renaming saved OCR regions")
    if !InStr(source, '管理已保存区域')
        throw Error("The named-region chooser should link to the manager dialog")

    ExitApp(0)
} catch {
    ExitApp(1)
}
