#Requires AutoHotkey v2.0

#Include ..\lib\StepRunner.ahk

class FakePlayer {
    __New() {
        this.calls := []
    }

    DoClientClick(hwnd, x, y, button) {
        this.calls.Push("click:" x ":" y ":" button)
        return true
    }

    FindPic(imageName, hwnd, &outX, &outY, region := "", logLabel := "", simOverride := "") {
        this.calls.Push("find:" imageName)
        outX := 100
        outY := 120
        return imageName = "ok.bmp"
    }

    ClickPic(imageName, hwnd, region := "", logLabel := "") {
        this.calls.Push("click_image:" imageName)
        return imageName = "ok.bmp"
    }
}

class FakeOcr {
    __New() {
        this.calls := []
    }

    Recognize(hwnd, region, targetText := "", logLabel := "") {
        this.calls.Push("ocr:" targetText)
        return {ok: true, matched: targetText = "开始", text: "开始", reason: ""}
    }
}

player := FakePlayer()
ocr := FakeOcr()
runner := StepRunner(player, ocr, "")

clickOk := runner.RunSingleStep({id: "c1", type: "click", params: {x: 10, y: 20, button: "R", delay: 0}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if !clickOk.ok
    throw Error("click step should delegate to Player.DoClientClick")

findOk := runner.RunSingleStep({id: "f1", type: "find_image", params: {image: "ok.bmp", region: "", sim: 0.7, timeout: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if !findOk.ok
    throw Error("find_image step should succeed when Player.FindPic finds the image")

findFail := runner.RunSingleStep({id: "f2", type: "find_image", params: {image: "missing.bmp", region: "", sim: 0.7, timeout: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if findFail.ok
    throw Error("find_image step should fail when Player.FindPic misses the image")

clickImageOk := runner.RunSingleStep({id: "ci1", type: "click_image", params: {image: "ok.bmp", region: "", sim: 0.7, timeout: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if !clickImageOk.ok
    throw Error("click_image step should delegate to Player.ClickPic")

ocrOk := runner.RunSingleStep({id: "o1", type: "ocr_match", params: {targetText: "开始", region: "", timeout: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if !ocrOk.ok
    throw Error("ocr_match step should succeed when OCR matches target text")

ocrFail := runner.RunSingleStep({id: "o2", type: "ocr_match", params: {targetText: "停止", region: "", timeout: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}, 123)
if ocrFail.ok
    throw Error("ocr_match step should fail when OCR does not match target text")

ExitApp(0)
