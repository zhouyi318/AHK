#Requires AutoHotkey v2.0

class CoordinateNavigator {
    __New(player, ocr, logger := "", nowProvider := "", sleepProvider := "") {
        this.player := player
        this.ocr := ocr
        this.log := logger
        this.nowProvider := nowProvider
        this.sleepProvider := sleepProvider
    }

    MoveTo(hwnd, coordRegion, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx := 200, ocrEveryClicks := 6, tolerance := 1, timeoutMs := 15000, ocrRetryCount := 2, ocrRetryIntervalMs := 150, stuckRounds := 3) {
        startedAt := this.Now()
        bestDistance := ""
        noProgressRounds := 0
        stuckRoundsValue := this.NormalizePositiveInt(stuckRounds, 3)

        loop {
            if (this.Now() - startedAt >= timeoutMs)
                return {ok: false, reason: "TIMEOUT"}

            current := this.ReadCurrentCoordWithRetry(hwnd, coordRegion, ocrRetryCount, ocrRetryIntervalMs)
            if !current.ok
                return current

            if this.IsNearTarget(current.x, current.y, targetX, targetY, tolerance)
                return {ok: true, reason: "ARRIVED", x: current.x, y: current.y, raw: current.raw}

            currentDistance := this.DistanceToTarget(current.x, current.y, targetX, targetY)
            if (bestDistance = "")
                bestDistance := currentDistance
            else if (currentDistance < bestDistance) {
                bestDistance := currentDistance
                noProgressRounds := 0
            } else {
                noProgressRounds += 1
            }

            if (noProgressRounds >= stuckRoundsValue)
                return {ok: false, reason: "STUCK", x: current.x, y: current.y, raw: current.raw}

            batchPlan := this.RunClickBatch(hwnd, current.x, current.y, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx, ocrEveryClicks, tolerance, startedAt, timeoutMs)
            if !batchPlan.ok
                return batchPlan
        }
    }

    RunClickBatch(hwnd, currentX, currentY, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx, ocrEveryClicks, tolerance, startedAt, timeoutMs) {
        batchSize := ocrEveryClicks is Number ? Integer(ocrEveryClicks) : 0
        if (batchSize <= 0)
            return {ok: false, reason: "INVALID_OCR_EVERY_CLICKS"}

        predictedX := currentX
        predictedY := currentY
        clicks := 0
        loop batchSize {
            if this.IsNearTarget(predictedX, predictedY, targetX, targetY, tolerance)
                break

            direction := this.DetermineClickDirection(predictedX, predictedY, targetX, targetY, tolerance)
            if (direction.x = 0 && direction.y = 0)
                break

            clickPoint := this.CalculateClickPoint(playerCenterX, playerCenterY, direction.x, direction.y, clickOffsetPx)
            if !clickPoint.ok
                return clickPoint
            if !this.RunNavigationClick(hwnd, clickPoint)
                return {ok: false, reason: "CLICK_FAILED"}

            predictedX += direction.x * 2
            predictedY += direction.y * 2
            clicks += 1

            if (this.Now() - startedAt >= timeoutMs)
                return {ok: false, reason: "TIMEOUT", x: predictedX, y: predictedY}
        }

        if (clicks <= 0)
            return {ok: false, reason: "NO_CLICK_BATCH"}
        return {ok: true, clicks: clicks, predictedX: predictedX, predictedY: predictedY}
    }

    DetermineClickDirection(currentX, currentY, targetX, targetY, tolerance) {
        return {
            x: this.DirectionComponent(targetX - currentX, tolerance),
            y: this.DirectionComponent(targetY - currentY, tolerance)
        }
    }

    ReadCurrentCoord(hwnd, region, rawText := "") {
        if (rawText = "") {
            result := this.TryReadCoordByTemplate(hwnd, region)
            if !result.ok {
                if (result.reason = "NO_TEMPLATES") {
                    this.LogInfo("模板不存在，回退到 OCR 模式")
                } else if (result.reason = "NO_TEXT") {
                    this.LogWarn("模板匹配未匹配到坐标，回退到 OCR 模式")
                } else {
                    this.LogWarn("模板匹配失败: " result.error "，回退到 OCR 模式")
                }
                result := this.ocr.Recognize(hwnd, region, "", "坐标OCR", true)
                if !result.ok {
                    this.LogWarn("坐标OCR读取失败: 原始=" this.DisplayText(result.text) " 原因=" result.reason)
                    return {ok: false, reason: result.reason, error: result.error, raw: result.text}
                }
                rawText := result.text
            } else {
                rawText := result.text
                if InStr(rawText, "?") {
                    this.LogWarn("模板匹配含缺失数字(?): " this.DisplayText(rawText) "，回退到 OCR 模式")
                    ocrResult := this.ocr.Recognize(hwnd, region, "", "坐标OCR", true)
                    if (ocrResult.ok && !InStr(ocrResult.text, "?"))
                        rawText := ocrResult.text
                }
            }
        }
        parsed := this.ParseCoordText(rawText)
        if parsed.ok
            this.LogInfo("坐标识别: 原始=" this.DisplayText(rawText) " 解析=" parsed.x "," parsed.y)
        else
            this.LogWarn("坐标解析失败: 原始=" this.DisplayText(rawText) " 归一化=" this.DisplayText(parsed.raw))
        return parsed
    }

    TryReadCoordByTemplate(hwnd, region) {
        if !this.ocr.HasProp("ReadCoordByTemplate")
            return {ok: false, reason: "NO_TEMPLATES", error: "模板匹配方法不可用"}
        return this.ocr.ReadCoordByTemplate(hwnd, region)
    }

    ReadCurrentCoordWithRetry(hwnd, region, ocrRetryCount := 2, ocrRetryIntervalMs := 150) {
        retriesRemaining := this.NormalizeNonNegativeInt(ocrRetryCount, 2)
        retryInterval := this.NormalizeNonNegativeInt(ocrRetryIntervalMs, 150)

        loop {
            current := this.ReadCurrentCoord(hwnd, region)
            if current.ok
                return current
            if (retriesRemaining <= 0)
                return current
            retriesRemaining -= 1
            if (retryInterval > 0)
                this.Sleep(retryInterval)
        }
    }

    ParseCoordText(text) {
        normalized := this.NormalizeCoordText(text)
        if InStr(normalized, "?")
            return {ok: false, reason: "MISSING_DIGIT", raw: normalized}
        if RegExMatch(normalized, "(\d{1,4})\D+(\d{1,4})", &m) {
            return {
                ok: true,
                x: Integer(m[1]),
                y: Integer(m[2]),
                raw: normalized
            }
        }
        split := this.TrySplitConcatenatedDigits(normalized)
        if split.ok {
            return {
                ok: true,
                x: split.x,
                y: split.y,
                raw: normalized
            }
        }
        return {ok: false, reason: "PARSE_FAILED", raw: normalized}
    }

    TrySplitConcatenatedDigits(normalized) {
        if !RegExMatch(normalized, "^\d{4,6}$")
            return {ok: false}
        len := StrLen(normalized)
        if (len = 6) {
            return {
                ok: true,
                x: Integer(SubStr(normalized, 1, 3)),
                y: Integer(SubStr(normalized, 4, 3))
            }
        }
        if (len = 5) {
            return {
                ok: true,
                x: Integer(SubStr(normalized, 1, 3)),
                y: Integer(SubStr(normalized, 4, 2))
            }
        }
        if (len = 4) {
            return {
                ok: true,
                x: Integer(SubStr(normalized, 1, 2)),
                y: Integer(SubStr(normalized, 3, 2))
            }
        }
        return {ok: false}
    }

    NormalizeCoordText(text) {
        text := StrUpper(text)
        text := StrReplace(text, "O", "0")
        text := StrReplace(text, "I", "1")
        text := StrReplace(text, "L", "1")
        text := StrReplace(text, "S", "5")
        text := StrReplace(text, "Z", "2")
        text := StrReplace(text, "B", "8")
        text := StrReplace(text, ":", " ")
        text := StrReplace(text, ",", " ")
        text := RegExReplace(text, "\s+", " ")
        text := Trim(text)
        text := StrReplace(text, " ", ",")
        return text
    }

    DisplayText(text) {
        return (text = "" ? "(空)" : StrReplace(text, "`n", "\n"))
    }

    DistanceToTarget(currentX, currentY, targetX, targetY) {
        return Abs(currentX - targetX) + Abs(currentY - targetY)
    }

    IsNearTarget(currentX, currentY, targetX, targetY, tolerance) {
        toleranceValue := tolerance is Number ? Integer(tolerance) : 0
        if (toleranceValue < 0)
            toleranceValue := 0
        return Abs(currentX - targetX) <= toleranceValue && Abs(currentY - targetY) <= toleranceValue
    }

    DirectionComponent(delta, tolerance) {
        toleranceValue := tolerance is Number ? Integer(tolerance) : 0
        if (Abs(delta) <= toleranceValue)
            return 0
        return delta > 0 ? 1 : -1
    }

    CalculateClickPoint(playerCenterX, playerCenterY, dirX, dirY, clickOffsetPx := 200) {
        offsetValue := clickOffsetPx is Number ? Integer(clickOffsetPx) : 0
        if (offsetValue <= 0)
            return {ok: false, reason: "INVALID_CLICK_OFFSET"}

        centerX := playerCenterX is Number ? Float(playerCenterX) : 0
        centerY := playerCenterY is Number ? Float(playerCenterY) : 0
        return {
            ok: true,
            x: Integer(Round(centerX + dirX * offsetValue)),
            y: Integer(Round(centerY + dirY * offsetValue))
        }
    }

    CalibrateMsPerCoord(*) {
        return {ok: false, reason: "UNSUPPORTED_IN_CLICK_MODE"}
    }

    DiagnoseDirectionAdjustment(*) {
        return {ok: false, reason: "UNSUPPORTED_IN_CLICK_MODE"}
    }

    RunNavigationClick(hwnd, clickPoint) {
        return this.player.DoClientClick(hwnd, clickPoint.x, clickPoint.y, "R", 1, 0)
    }

    Now() {
        if IsObject(this.nowProvider)
            return this.nowProvider.Call()
        return A_TickCount
    }

    Sleep(ms) {
        if IsObject(this.sleepProvider) {
            this.sleepProvider.Call(ms)
            return
        }
        Sleep ms
    }

    NormalizeNonNegativeInt(value, defaultValue := 0) {
        normalized := value is Number ? Integer(value) : defaultValue
        return normalized < 0 ? 0 : normalized
    }

    NormalizePositiveInt(value, defaultValue := 1) {
        normalized := value is Number ? Integer(value) : defaultValue
        return normalized < 1 ? 1 : normalized
    }

    LogInfo(msg) {
        if IsObject(this.log)
            this.log.Info(msg)
    }

    LogWarn(msg) {
        if IsObject(this.log)
            this.log.Warn(msg)
    }
}
