#Requires AutoHotkey v2.0

#Include ..\lib\GuiHelper.ahk
#Include ..\lib\ManualTools.ahk

DummyBotSimChanged(*) {
}

try {
    tools := ManualTools(Map())
    boundFn := ObjBindMethod(tools, "BuildSimSweepList", 0.75)
    if !IsObject(boundFn)
        throw Error("ManualTools instances should support ObjBindMethod without invalid base errors")

    callbackOnlyTools := ManualTools(Map("onBotSimChanged", "DummyBotSimChanged"))
    if !IsObject(callbackOnlyTools)
        throw Error("ManualTools should allow storing the onBotSimChanged callback dependency")

    sims := tools.BuildSimSweepList(0.75)
    if (sims.Length != 8)
        throw Error("BuildSimSweepList should return the base value plus fallback similarity values")
    if (tools.JoinSimValues(sims) != "0.75, 0.70, 0.65, 0.60, 0.55, 0.50, 0.40, 0.30")
        throw Error("JoinSimValues should format similarity values with two decimals")

    normalized := tools.NormalizeRegionObject({x1: 80, y1: 120, x2: 20, y2: 40})
    if (normalized.x1 != 20 || normalized.y1 != 40 || normalized.x2 != 80 || normalized.y2 != 120)
        throw Error("NormalizeRegionObject should reorder region coordinates")
    if (tools.RegionSummary(normalized) != "(20,40)-(80,120)")
        throw Error("RegionSummary should format normalized regions")
    if (tools.RegionSummary("") != "(全窗口)")
        throw Error("RegionSummary should describe an empty region as the full window")

    ExitApp(0)
} catch {
    ExitApp(1)
}
