#Requires AutoHotkey v2.0

class StepSchema {
    static CreateStep(type) {
        return {
            id: "step_" A_TickCount,
            type: type,
            name: this.DefaultName(type),
            enabled: true,
            params: this.DefaultParams(type),
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }

    static DefaultName(type) {
        switch type {
            case "click":
                return "点击"
            case "wait":
                return "等待"
            case "keypress":
                return "按键"
            case "mouse_action":
                return "按住"
            case "mouse_move":
                return "移动鼠标"
            case "mouse_wheel":
                return "滚轮"
            case "find_image":
                return "区域找图"
            case "click_image":
                return "图片点击"
            case "ocr_match":
                return "OCR 识别"
            case "branch":
                return "条件分支"
            default:
                return type
        }
    }

    static DefaultParams(type) {
        switch type {
            case "click":
                return {x: 0, y: 0, button: "L", delay: 0, repeat: 1, intervalMs: 0}
            case "wait":
                return {ms: 1000}
            case "keypress":
                return {keyName: "", repeat: 1}
            case "mouse_action":
                return {x: 0, y: 0, button: "R", action: "hold", holdMs: 0, delay: 0}
            case "mouse_move":
                return {x: 0, y: 0, speed: 0}
            case "mouse_wheel":
                return {direction: "Down", amount: 1}
            case "find_image":
                return {image: "", region: "", sim: 0.7, timeout: 10000}
            case "click_image":
                return {image: "", region: "", sim: 0.7, timeout: 10000, button: "L"}
            case "ocr_match":
                return {targetText: "", region: "", timeout: 10000, matchMode: "contains"}
            case "branch":
                return {conditionType: "ocr_match", targetText: "", image: "", region: "", sim: 0.7, timeout: 10000, matchMode: "contains"}
            default:
                return {}
        }
    }

    static ValidateJumpTargets(script) {
        ids := Map()
        for _, step in script.steps
            ids[step.id] := true

        for _, step in script.steps {
            for _, branch in [step.onSuccess, step.onFailure] {
                if (branch.action = "jump" && !ids.Has(branch.targetStepId))
                    return "Missing jump target: " branch.targetStepId
            }
        }
        return ""
    }
}
