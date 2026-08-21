#Requires AutoHotkey v2.0

#Include ..\lib\CoordinateNavigator.ahk

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
    __New() {
        this.messages := []
    }

    Info(msg) {
        this.messages.Push("INFO:" . msg)
    }

    Warn(msg) {
        this.messages.Push("WARN:" . msg)
    }
}

class FakePlayer {
    __New() {
        this.clicks := []
        this.physicalHolds := []
        this.physicalUpdates := []
        this.physicalReleases := []
    }

    DoClientClick(hwnd, x, y, button, repeat := 1, intervalMs := 0) {
        this.clicks.Push({
            hwnd: hwnd,
            x: x,
            y: y,
            button: button,
            repeat: repeat,
            intervalMs: intervalMs
        })
        return true
    }

    BeginPhysicalClientMouseHold(hwnd, x, y, button := "R") {
        this.physicalHolds.Push({hwnd: hwnd, x: x, y: y, button: button})
        return true
    }

    UpdatePhysicalClientMouseHold(hwnd, x, y) {
        this.physicalUpdates.Push({hwnd: hwnd, x: x, y: y})
        return true
    }

    EndPhysicalMouseHold(button := "R") {
        this.physicalReleases.Push({button: button})
        return true
    }
}

class FakeOcr {
    __New(results) {
        this.results := results
        this.calls := []
        this.index := 0
    }

    Recognize(hwnd, region, targetText := "", logLabel := "", preprocess := false) {
        this.calls.Push({
            hwnd: hwnd,
            region: region,
            targetText: targetText,
            logLabel: logLabel,
            preprocess: preprocess
        })
        this.index += 1
        if (this.index > this.results.Length)
            return {ok: false, error: "NO_MORE_RESULTS", reason: "NO_MORE_RESULTS", text: ""}
        return this.results[this.index]
    }
}

class FakeClock {
    __New(values) {
        this.values := values
        this.index := 0
        this.lastValue := values.Length > 0 ? values[1] : 0
    }

    Call() {
        this.index += 1
        if (this.index <= this.values.Length) {
            this.lastValue := this.values[this.index]
            return this.lastValue
        }
        return this.lastValue
    }
}

class FakeSleeper {
    __New() {
        this.calls := []
    }

    Call(ms) {
        this.calls.Push(ms)
    }
}

try {
    logger := FakeLogger()

    parseNavigator := CoordinateNavigator(FakePlayer(), FakeOcr([]), logger)
    parsed := parseNavigator.ReadCurrentCoord(101, {x1: 1, y1: 2, x2: 3, y2: 4}, "123,456")
    if !parsed.ok
        throw Error("ReadCurrentCoordText should parse a simple numeric coordinate pair")
    if (parsed.x != 123 || parsed.y != 456)
        throw Error("ReadCurrentCoordText should return the parsed x/y values")

    reachPlayer := FakePlayer()
    reachOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "334,333", error: "", reason: "TEXT_ONLY"}
    ])
    reachClock := FakeClock([0, 100, 200, 300])
    reachNavigator := CoordinateNavigator(reachPlayer, reachOcr, logger, reachClock.Call.Bind(reachClock))
    reachResult := reachNavigator.MoveTo(555, {x1: 10, y1: 20, x2: 40, y2: 50}, 334, 333, 500, 400, 200, 2, 1, 5000)

    if !reachResult.ok
        throw Error("MoveTo should succeed when click-based navigation reaches the target coordinate")
    if (reachPlayer.clicks.Length != 2)
        throw Error("MoveTo should use right-click navigation steps instead of physical hold segments")
    if (reachPlayer.clicks[1].x != 700 || reachPlayer.clicks[1].y != 400)
        throw Error("MoveTo should click to the right of the player center when targetX is larger and targetY is aligned")
    if (reachPlayer.physicalHolds.Length != 0 || reachPlayer.physicalReleases.Length != 0)
        throw Error("MoveTo should no longer use physical mouse holds in click-navigation mode")
    if (reachOcr.calls.Length != 2)
        throw Error("MoveTo should read OCR once at start and once after one click batch")
    if !reachOcr.calls[1].preprocess
        throw Error("MoveTo should enable OCR preprocessing for coordinate recognition")
    if !HasLogMessage(logger.messages, "INFO:坐标识别: 原始=330,333 解析=330,333")
        throw Error("MoveTo should log the recognized coordinate text and parsed coordinate values")

    predictivePlayer := FakePlayer()
    predictiveOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "334,337", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "336,337", error: "", reason: "TEXT_ONLY"}
    ])
    predictiveClock := FakeClock([0, 100, 200, 300, 400, 500])
    predictiveNavigator := CoordinateNavigator(predictivePlayer, predictiveOcr, logger, predictiveClock.Call.Bind(predictiveClock))
    predictiveResult := predictiveNavigator.MoveTo(556, {x1: 10, y1: 20, x2: 40, y2: 50}, 336, 337, 500, 400, 200, 3, 1, 5000)

    if !predictiveResult.ok
        throw Error("MoveTo should keep navigating after OCR revises the predicted coordinate")
    if (predictivePlayer.clicks.Length != 4)
        throw Error("MoveTo should continue from corrected OCR coordinates after each click batch")
    if (predictivePlayer.clicks[1].x != 772 || predictivePlayer.clicks[1].y != 672)
        throw Error("MoveTo should enlarge the click offset when far from the target (offset auto-scaling)")
    if (predictivePlayer.clicks[3].x != 700 || predictivePlayer.clicks[3].y != 400)
        throw Error("MoveTo should switch to single-axis clicks after one axis enters the tolerance range")

    retryPlayer := FakePlayer()
    retryOcr := FakeOcr([
        {ok: false, text: "", error: "OCR_BUSY", reason: "OCR_BUSY"},
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"}
    ])
    retryClock := FakeClock([0, 100, 200, 300, 400])
    retrySleeper := FakeSleeper()
    retryNavigator := CoordinateNavigator(retryPlayer, retryOcr, logger, retryClock.Call.Bind(retryClock), retrySleeper.Call.Bind(retrySleeper))
    retryResult := retryNavigator.MoveTo(557, {x1: 10, y1: 20, x2: 40, y2: 50}, 332, 333, 500, 400, 200, 2, 1, 5000, 1, 120, 3)

    if !retryResult.ok
        throw Error("MoveTo should retry OCR once when the first coordinate read fails transiently")
    if (retryOcr.calls.Length != 3)
        throw Error("MoveTo should retry the failed OCR read before giving up")
    if (retrySleeper.calls.Length < 1 || retrySleeper.calls[1] != 120)
        throw Error("MoveTo should wait for ocrRetryIntervalMs before retrying coordinate OCR (arrival settle sleep may follow)")
    if (retryPlayer.clicks.Length != 1)
        throw Error("MoveTo should resume click navigation after a successful OCR retry")

    timeoutPlayer := FakePlayer()
    timeoutOcr := FakeOcr([
        {ok: true, text: "10,10", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "12,10", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "14,10", error: "", reason: "TEXT_ONLY"}
    ])
    timeoutClock := FakeClock([0, 200, 600, 900])
    timeoutNavigator := CoordinateNavigator(timeoutPlayer, timeoutOcr, logger, timeoutClock.Call.Bind(timeoutClock))
    timeoutResult := timeoutNavigator.MoveTo(777, {x1: 1, y1: 1, x2: 9, y2: 9}, 50, 50, 320, 240, 200, 2, 1, 500)

    if timeoutResult.ok
        throw Error("MoveTo should fail when the target is not reached before timeout")
    if (timeoutResult.reason != "TIMEOUT")
        throw Error("MoveTo should report TIMEOUT when navigation exceeds timeoutMs")
    if (timeoutPlayer.clicks.Length < 1)
        throw Error("MoveTo should still attempt click navigation before timing out")

    stuckPlayer := FakePlayer()
    stuckOcr := FakeOcr([
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "33,44", error: "", reason: "TEXT_ONLY"}
    ])
    stuckClock := FakeClock([0, 100, 200, 300, 400, 500, 600, 700, 800, 900])
    stuckNavigator := CoordinateNavigator(stuckPlayer, stuckOcr, logger, stuckClock.Call.Bind(stuckClock))
    stuckResult := stuckNavigator.MoveTo(888, {x1: 2, y1: 2, x2: 8, y2: 8}, 99, 99, 320, 240, 200, 2, 1, 5000)

    if stuckResult.ok
        throw Error("MoveTo should fail when OCR coordinates stay unchanged for too long")
    if (stuckResult.reason != "STUCK")
        throw Error("MoveTo should report STUCK when the character stops making coordinate progress")
    if !HasLogMessage(logger.messages, "自动脱困")
        throw Error("MoveTo should try axis-locked escape maneuvers before declaring STUCK")
    if (stuckPlayer.clicks.Length < 1)
        throw Error("MoveTo should attempt click navigation before giving up on a stuck character")

    driftPlayer := FakePlayer()
    driftOcr := FakeOcr([
        {ok: true, text: "10,10", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "12,12", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "14,14", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "16,16", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "18,18", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "20,20", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "22,22", error: "", reason: "TEXT_ONLY"}
    ])
    driftClock := FakeClock([0, 100, 200, 300, 400, 500, 600, 700])
    driftNavigator := CoordinateNavigator(driftPlayer, driftOcr, logger, driftClock.Call.Bind(driftClock))
    driftResult := driftNavigator.MoveTo(889, {x1: 2, y1: 2, x2: 8, y2: 8}, 0, 0, 320, 240, 200, 1, 1, 5000, 0, 0, 2)

    if driftResult.ok
        throw Error("MoveTo should fail when each OCR batch drifts farther from the target")
    if (driftResult.reason != "STUCK")
        throw Error("MoveTo should use progress-based stuck detection instead of only repeated identical coordinates")
    if (driftPlayer.clicks.Length != 6)
        throw Error("MoveTo should keep escaping until both axis-locked maneuvers fail before declaring STUCK")

    misreadPlayer := FakePlayer()
    misreadOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "789,433", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "334,333", error: "", reason: "TEXT_ONLY"}
    ])
    misreadLogger := FakeLogger()
    misreadClock := FakeClock([0, 100, 200, 300, 400, 500])
    misreadNavigator := CoordinateNavigator(misreadPlayer, misreadOcr, misreadLogger, misreadClock.Call.Bind(misreadClock))
    misreadResult := misreadNavigator.MoveTo(890, {x1: 2, y1: 2, x2: 8, y2: 8}, 334, 333, 500, 400, 200, 2, 1, 5000)

    if !misreadResult.ok
        throw Error("MoveTo should recover when a template misread is followed by a plausible reading")
    if !HasLogMessage(misreadLogger.messages, "坐标读数跳变异常")
        throw Error("MoveTo should log when a coordinate reading jumps farther than one batch of clicks can travel")

    misreadStuckPlayer := FakePlayer()
    misreadStuckOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "789,433", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "788,432", error: "", reason: "TEXT_ONLY"}
    ])
    misreadStuckClock := FakeClock([0, 100, 200, 300, 6000])
    misreadStuckNavigator := CoordinateNavigator(misreadStuckPlayer, misreadStuckOcr, FakeLogger(), misreadStuckClock.Call.Bind(misreadStuckClock))
    misreadStuckResult := misreadStuckNavigator.MoveTo(891, {x1: 2, y1: 2, x2: 8, y2: 8}, 334, 333, 500, 400, 200, 2, 1, 5000)

    if misreadStuckResult.ok
        throw Error("MoveTo should not navigate using repeatedly implausible readings")
    if (misreadStuckResult.reason != "TIMEOUT")
        throw Error("MoveTo should keep waiting for a plausible reading until timeout instead of trusting misreads")

    ; 脱困成功：停滞切换单轴后恢复进展，最终到达
    escapePlayer := FakePlayer()
    escapeOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "332,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "338,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "340,333", error: "", reason: "TEXT_ONLY"}
    ])
    escapeLogger := FakeLogger()
    escapeClock := FakeClock([0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000])
    escapeNavigator := CoordinateNavigator(escapePlayer, escapeOcr, escapeLogger, escapeClock.Call.Bind(escapeClock))
    escapeResult := escapeNavigator.MoveTo(892, {x1: 2, y1: 2, x2: 8, y2: 8}, 340, 333, 500, 400, 200, 2, 1, 5000)

    if !escapeResult.ok
        throw Error("MoveTo should recover from stalling via axis-locked escape and still reach the target")
    if !HasLogMessage(escapeLogger.messages, "自动脱困")
        throw Error("MoveTo should switch to axis-locked clicks after stuckRounds without progress")
    if !HasLogMessage(escapeLogger.messages, "导航恢复进展，退出脱困模式")
        throw Error("MoveTo should leave escape mode once navigation makes progress again")

    ; 自动超时：timeoutMs=0 时按距离放宽，长途不再被固定 15s 杀死
    autoTimeoutPlayer := FakePlayer()
    autoTimeoutOcr := FakeOcr([
        {ok: true, text: "100,100", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "105,100", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "110,100", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "115,100", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "120,100", error: "", reason: "TEXT_ONLY"}
    ])
    autoTimeoutLogger := FakeLogger()
    autoTimeoutClock := FakeClock([100, 200, 300, 4100, 4200, 4300, 8100, 8200, 8300, 12100, 12200, 12300, 16100])
    autoTimeoutNavigator := CoordinateNavigator(autoTimeoutPlayer, autoTimeoutOcr, autoTimeoutLogger, autoTimeoutClock.Call.Bind(autoTimeoutClock))
    autoTimeoutResult := autoTimeoutNavigator.MoveTo(893, {x1: 2, y1: 2, x2: 8, y2: 8}, 120, 100, 500, 400, 200, 2, 1, 0)

    if !autoTimeoutResult.ok
        throw Error("MoveTo with timeoutMs=0 should auto-estimate the timeout by distance instead of the 15s default")
    if !HasLogMessage(autoTimeoutLogger.messages, "自动超时估算")
        throw Error("MoveTo with timeoutMs=0 should log the auto-estimated timeout")

    ; 走路节奏自适应：点击多但位移小 → 自动加点击间隔
    rhythmPlayer := FakePlayer()
    rhythmOcr := FakeOcr([
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "330,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "334,333", error: "", reason: "TEXT_ONLY"},
        {ok: true, text: "336,333", error: "", reason: "TEXT_ONLY"}
    ])
    rhythmLogger := FakeLogger()
    rhythmClock := FakeClock([0, 100, 200, 300, 400, 500, 600, 700, 800, 900])
    rhythmNavigator := CoordinateNavigator(rhythmPlayer, rhythmOcr, rhythmLogger, rhythmClock.Call.Bind(rhythmClock))
    rhythmResult := rhythmNavigator.MoveTo(894, {x1: 2, y1: 2, x2: 8, y2: 8}, 336, 333, 500, 400, 200, 2, 1, 5000)

    if !rhythmResult.ok
        throw Error("MoveTo should still reach the target while adapting the click rhythm")
    if !HasLogMessage(rhythmLogger.messages, "走路节奏自适应")
        throw Error("MoveTo should adjust the inter-click interval when clicks are being dropped by the game")

    parseFailLogger := FakeLogger()
    parseFailNavigator := CoordinateNavigator(FakePlayer(), FakeOcr([]), parseFailLogger)
    parseFailResult := parseFailNavigator.ReadCurrentCoord(990, {x1: 1, y1: 2, x2: 3, y2: 4}, "abc")
    if parseFailResult.ok
        throw Error("ReadCurrentCoord should fail when OCR text is completely non-numeric")
    if !HasLogMessage(parseFailLogger.messages, "坐标解析失败")
        throw Error("ReadCurrentCoord should log the OCR text when coordinate parsing fails")

    concatParseNavigator := CoordinateNavigator(FakePlayer(), FakeOcr([]), logger)
    concatResult := concatParseNavigator.ReadCurrentCoord(991, {x1: 1, y1: 2, x2: 3, y2: 4}, "331333")
    if !concatResult.ok
        throw Error("ReadCurrentCoord should parse concatenated 6-digit coordinate as 3+3 split")
    if (concatResult.x != 331 || concatResult.y != 333)
        throw Error("ReadCurrentCoord should split 331333 into 331,333")

    colonResult := concatParseNavigator.ReadCurrentCoord(992, {x1: 1, y1: 2, x2: 3, y2: 4}, "331:333")
    if !colonResult.ok
        throw Error("ReadCurrentCoord should parse colon-separated coordinates")
    if (colonResult.x != 331 || colonResult.y != 333)
        throw Error("ReadCurrentCoord should parse 331:333 as 331,333")

    spaceResult := concatParseNavigator.ReadCurrentCoord(993, {x1: 1, y1: 2, x2: 3, y2: 4}, "331 333")
    if !spaceResult.ok
        throw Error("ReadCurrentCoord should parse space-separated coordinates")
    if (spaceResult.x != 331 || spaceResult.y != 333)
        throw Error("ReadCurrentCoord should parse 331 333 as 331,333")

    charConfuseLogger := FakeLogger()
    charConfuseNavigator := CoordinateNavigator(FakePlayer(), FakeOcr([]), charConfuseLogger)
    charResult := charConfuseNavigator.ReadCurrentCoord(994, {x1: 1, y1: 2, x2: 3, y2: 4}, "33l 3O3")
    if !charResult.ok
        throw Error("ReadCurrentCoord should normalize OCR character confusion before parsing")
    if (charResult.x != 331 || charResult.y != 303)
        throw Error("ReadCurrentCoord should convert l->1 and O->0 when parsing coordinates")

    fiveDigitResult := concatParseNavigator.ReadCurrentCoord(995, {x1: 1, y1: 2, x2: 3, y2: 4}, "33133")
    if !fiveDigitResult.ok
        throw Error("ReadCurrentCoord should attempt to split 5-digit concatenated coordinates")
    if (fiveDigitResult.x != 331 || fiveDigitResult.y != 33)
        throw Error("ReadCurrentCoord should prefer 3+2 split for 5-digit coordinates")

    fourDigitResult := concatParseNavigator.ReadCurrentCoord(996, {x1: 1, y1: 2, x2: 3, y2: 4}, "1234")
    if !fourDigitResult.ok
        throw Error("ReadCurrentCoord should split 4-digit concatenated coordinates as 2+2")
    if (fourDigitResult.x != 12 || fourDigitResult.y != 34)
        throw Error("ReadCurrentCoord should split 1234 into 12,34")

    invalidNavigator := CoordinateNavigator(FakePlayer(), FakeOcr([]), logger)
    invalidRunPoint := invalidNavigator.CalculateClickPoint(320, 240, 0, 0, 0)
    if invalidRunPoint.ok
        throw Error("CalculateClickPoint should fail when clickOffsetPx is invalid")
    if (invalidRunPoint.reason != "INVALID_CLICK_OFFSET")
        throw Error("CalculateClickPoint should report INVALID_CLICK_OFFSET for a non-positive click offset")

    WriteStatus(0)
    ExitApp(0)
} catch as err {
    WriteStatus(1)
    WriteFailure(err.Message)
    ExitApp(1)
}

HasLogMessage(messages, expected) {
    for _, msg in messages {
        if InStr(msg, expected)
            return true
    }
    return false
}
