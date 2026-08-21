#Requires AutoHotkey v2.0

class CoordinateNavigator {
    __New(player, ocr, logger := "", nowProvider := "", sleepProvider := "") {
        this.player := player
        this.ocr := ocr
        this.log := logger
        this.nowProvider := nowProvider
        this.sleepProvider := sleepProvider
    }

    MoveTo(hwnd, coordRegion, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx := 200, ocrEveryClicks := 6, tolerance := 1, timeoutMs := 15000, ocrRetryCount := 2, ocrRetryIntervalMs := 150, stuckRounds := 3, arriveSettleMs := 600) {
        startedAt := this.Now()
        bestDistance := ""
        lastCoord := ""
        lastRound := ""
        noProgressRounds := 0
        stuckRoundsValue := this.NormalizePositiveInt(stuckRounds, 3)
        escapeAttempts := 0
        escapeMode := ""
        clickIntervalMs := 0
        ; timeoutMs<=0 启用自动超时：按目标距离动态估算，停滞时不再顺延，由估算值兜底
        autoTimeout := (timeoutMs <= 0)
        if (autoTimeout)
            timeoutMs := 15000

        loop {
            if (this.Now() - startedAt >= timeoutMs) {
                this.LogWarn("导航超时 TIMEOUT: 目标=" targetX "," targetY " 已用时>=" timeoutMs "ms" (autoTimeout ? "（自动估算）" : ""))
                return {ok: false, reason: "TIMEOUT"}
            }

            current := this.ReadCurrentCoordWithRetry(hwnd, coordRegion, ocrRetryCount, ocrRetryIntervalMs)
            if !current.ok
                return current

            ; 过滤模板误读：角色一回合最多走 ocrEveryClicks 步，跳变超过阈值的读数视为误读并重读
            if (lastCoord != "" && this.IsJumpImplausible(lastCoord.x, lastCoord.y, current.x, current.y, ocrEveryClicks)) {
                this.LogWarn("坐标读数跳变异常: " lastCoord.x "," lastCoord.y " -> " current.x "," current.y "，判定为模板误读，重新读取")
                reread := this.ReadCurrentCoordWithRetry(hwnd, coordRegion, ocrRetryCount, ocrRetryIntervalMs)
                if (reread.ok && !this.IsJumpImplausible(lastCoord.x, lastCoord.y, reread.x, reread.y, ocrEveryClicks))
                    current := reread
                else {
                    this.LogWarn("重读仍异常，沿用上回合坐标 " lastCoord.x "," lastCoord.y)
                    continue
                }
            }

            ; 走路节奏自适应：点击多次但位移小 → 点击间加间隔（避免连发被游戏丢弃）；点击全生效 → 收回间隔
            if (IsObject(lastRound) && lastRound.clicks > 0) {
                moved := Abs(current.x - lastCoord.x) + Abs(current.y - lastCoord.y)
                newInterval := moved < lastRound.clicks
                    ? Min(clickIntervalMs + 100, 300)
                    : Max(clickIntervalMs - 100, 0)
                if (newInterval != clickIntervalMs) {
                    this.LogInfo("走路节奏自适应: 上回合位移=" moved "格 点击=" lastRound.clicks "次，点击间隔 " clickIntervalMs "->" newInterval "ms")
                    clickIntervalMs := newInterval
                }
            }
            lastCoord := current
            lastRound := ""

            if this.IsNearTarget(current.x, current.y, targetX, targetY, tolerance) {
                ; 等走路动画结束，避免后续点击被游戏忽略
                settle := this.NormalizeNonNegativeInt(arriveSettleMs, 600)
                if (settle > 0) {
                    this.LogInfo("导航到达 " current.x "," current.y "，稳定等待 " settle "ms")
                    this.Sleep(settle)
                }
                return {ok: true, reason: "ARRIVED", x: current.x, y: current.y, raw: current.raw}
            }

            currentDistance := this.DistanceToTarget(current.x, current.y, targetX, targetY)
            if (bestDistance = "") {
                bestDistance := currentDistance
                ; 自动超时估算：按剩余距离给出长途余量（估算值只会放大，停滞时不再顺延）
                if (autoTimeout) {
                    estimated := 10000 + currentDistance * 400
                    if (estimated > timeoutMs) {
                        timeoutMs := estimated
                        this.LogInfo("自动超时估算: 距离=" currentDistance "格，超时放宽至 " timeoutMs "ms")
                    }
                }
            } else if (currentDistance < bestDistance) {
                bestDistance := currentDistance
                noProgressRounds := 0
                ; 取得新进展说明脱困成功，恢复常规走法并重置脱困预算（后续再卡可再次脱困）
                if (escapeMode != "" || escapeAttempts > 0) {
                    this.LogInfo("导航恢复进展，退出脱困模式")
                    escapeMode := ""
                    escapeAttempts := 0
                }
            } else {
                noProgressRounds += 1
            }

            if (noProgressRounds >= stuckRoundsValue) {
                if (escapeAttempts < 2) {
                    escapeAttempts += 1
                    dx := targetX - current.x
                    dy := targetY - current.y
                    primaryAxis := Abs(dx) >= Abs(dy) ? "X" : "Y"
                    escapeMode := (escapeAttempts = 1) ? primaryAxis : (primaryAxis = "X" ? "Y" : "X")
                    this.LogWarn("导航停滞 " noProgressRounds " 回合，自动脱困 #" escapeAttempts ": 切换" (escapeMode = "X" ? "横轴" : "纵轴") "单轴走法")
                    noProgressRounds := 0
                } else {
                    this.LogWarn("导航停滞 STUCK: 脱困后仍连续 " noProgressRounds " 回合无进展 当前=" current.x "," current.y " 目标=" targetX "," targetY)
                    return {ok: false, reason: "STUCK", x: current.x, y: current.y, raw: current.raw}
                }
            }

            batchPlan := this.RunClickBatch(hwnd, current.x, current.y, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx, ocrEveryClicks, tolerance, startedAt, timeoutMs, clickIntervalMs, escapeMode)
            if !batchPlan.ok {
                if (batchPlan.reason = "CLICK_FAILED")
                    this.LogWarn("导航点击失败 CLICK_FAILED: 当前=" current.x "," current.y)
                return batchPlan
            }
            lastRound := {clicks: batchPlan.clicks}
        }
    }

    ; 单轴最大位移 = 点击次数（每点一步）+ 少量容错（怪物推挤/延迟补步）
    IsJumpImplausible(prevX, prevY, curX, curY, ocrEveryClicks) {
        batchSize := ocrEveryClicks is Number ? Integer(ocrEveryClicks) : 0
        maxJump := (batchSize > 0 ? batchSize : 6) + 8
        return Abs(curX - prevX) > maxJump || Abs(curY - prevY) > maxJump
    }

    ; 长途跑图时加大点击偏移（点更远让角色一次寻路走更多格），接近目标时收回原值
    ResolveClickOffsetPx(clickOffsetPx, currentX, currentY, targetX, targetY) {
        offsetValue := clickOffsetPx is Number ? Integer(clickOffsetPx) : 200
        if (offsetValue <= 0)
            offsetValue := 200
        remainingTiles := Abs(targetX - currentX) + Abs(targetY - currentY)
        if (remainingTiles <= 4)
            return offsetValue
        ; 每多 1 格距离加 12px，上限 350px（约 7 格屏幕距离）
        desired := offsetValue + (remainingTiles - 4) * 12
        return Min(desired, 350)
    }

    ; 把点击点夹回客户区安全范围，避免偏移自适应后点到窗口边缘/外部（上下各留 30px 避开 HUD）
    ClampClickPointToClient(hwnd, point) {
        try
            WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        catch
            return false
        if (cw <= 0 || ch <= 0)
            return false
        point.x := Integer(Min(Max(point.x, 30), cw - 30))
        point.y := Integer(Min(Max(point.y, 30), ch - 30))
        return true
    }

    RunClickBatch(hwnd, currentX, currentY, targetX, targetY, playerCenterX, playerCenterY, clickOffsetPx, ocrEveryClicks, tolerance, startedAt, timeoutMs, clickIntervalMs := 0, escapeMode := "") {
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
            ; 停滞脱困：临时锁定单轴，避开斜向卡位
            if (escapeMode = "X" && direction.x != 0)
                direction := {x: direction.x, y: 0}
            else if (escapeMode = "Y" && direction.y != 0)
                direction := {x: 0, y: direction.y}
            if (direction.x = 0 && direction.y = 0)
                break

            ; 点击偏移自适应：距离越远点得越远，让角色一次寻路走更多格；接近目标时收回
            effectiveOffset := this.ResolveClickOffsetPx(clickOffsetPx, predictedX, predictedY, targetX, targetY)

            clickPoint := this.CalculateClickPoint(playerCenterX, playerCenterY, direction.x, direction.y, effectiveOffset)
            if !clickPoint.ok
                return clickPoint
            this.ClampClickPointToClient(hwnd, clickPoint)
            if !this.RunNavigationClick(hwnd, clickPoint)
                return {ok: false, reason: "CLICK_FAILED"}
            if (clickIntervalMs > 0)
                this.Sleep(clickIntervalMs)

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
            if (!result.ok || Trim(result.text) = "") {
                if (result.reason = "NO_TEMPLATES") {
                    this.LogInfo("模板不存在，回退到 OCR 模式")
                } else if (result.reason = "NO_TEXT" || Trim(result.text) = "") {
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
