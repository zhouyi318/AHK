#Requires AutoHotkey v2.0

class FlowRunner {
    __New(stepRunner, scriptRepo, logger := "") {
        this.stepRunner := stepRunner
        this.scriptRepo := scriptRepo
        this.log := logger
    }

    RunFlow(flow, hwnd, startNodeId := "", maxTransitions := 200) {
        if !IsObject(flow) || !flow.HasProp("nodes") || flow.nodes.Length = 0
            return {ok: false, failedNodeId: "", error: "FLOW_EMPTY"}

        index := this.ResolveStartIndex(flow, startNodeId)
        if (index = 0)
            return {ok: false, failedNodeId: "", error: "FLOW_ENTRY_MISSING"}

        transitions := 0
        lastNodeId := ""
        while (index >= 1 && index <= flow.nodes.Length) {
            if (transitions >= maxTransitions)
                return {ok: false, failedNodeId: lastNodeId, lastNodeId: lastNodeId, error: "FLOW_LIMIT"}
            transitions += 1

            node := flow.nodes[index]
            if (node.HasProp("enabled") && !node.enabled) {
                index += 1
                continue
            }

            script := this.scriptRepo.LoadScript(node.scriptName)
            if !script
                return {ok: false, failedNodeId: node.id, lastNodeId: lastNodeId, error: "SCRIPT_MISSING"}

            result := this.stepRunner.RunScript(script, hwnd, 1)
            lastNodeId := node.id
            ok := result.HasProp("ok") ? result.ok : false
            branch := ok ? node.onSuccess : node.onFailure
            if !ok && branch.action = "stop"
                return {ok: false, failedNodeId: node.id, lastNodeId: lastNodeId}

            nextIndex := this.ResolveNextIndex(flow.nodes, index, branch)
            if (nextIndex = 0)
                return {ok: true, lastNodeId: lastNodeId}
            index := nextIndex
        }

        return {ok: true, lastNodeId: lastNodeId}
    }

    ResolveStartIndex(flow, startNodeId := "") {
        targetId := (startNodeId = "" ? flow.entryNodeId : startNodeId)
        if (targetId = "" && flow.nodes.Length > 0)
            return 1
        return this.FindNodeIndexById(flow.nodes, targetId)
    }

    ResolveNextIndex(nodes, currentIndex, branch) {
        if !IsObject(branch) || !branch.HasProp("action")
            return currentIndex + 1
        switch branch.action {
            case "next":
                return currentIndex + 1
            case "goto":
                return this.FindNodeIndexById(nodes, branch.HasProp("targetNodeId") ? branch.targetNodeId : "")
            case "repeat":
                return currentIndex
            case "stop":
                return 0
            default:
                return currentIndex + 1
        }
    }

    FindNodeIndexById(nodes, nodeId) {
        if (nodeId = "")
            return 0
        for index, node in nodes {
            if (node.id = nodeId)
                return index
        }
        return 0
    }
}
