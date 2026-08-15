#Requires AutoHotkey v2.0

#Include ScriptStore.ahk

class FlowRepository extends ScriptStore {
    CreateFlow(name) {
        return {
            id: "flow_" name,
            name: name,
            entryNodeId: "",
            enabled: true,
            nodes: []
        }
    }

    LoadFlow(name) {
        raw := super.LoadScript(name)
        if !raw
            return ""
        return this.NormalizeFlow(raw, name)
    }

    SaveFlow(flow) {
        normalized := this.NormalizeFlow(flow)
        raw := {
            id: normalized.id,
            name: normalized.name,
            entryNodeId: normalized.entryNodeId,
            enabled: normalized.enabled,
            nodes: normalized.nodes
        }
        super.SaveScript(raw)
    }

    DeleteFlow(name) {
        super.DeleteScript(name)
    }

    ListFlows() {
        return super.ListScripts()
    }

    NormalizeFlow(raw, fallbackName := "") {
        name := raw.HasProp("name") ? raw.name : fallbackName
        flow := {
            id: raw.HasProp("id") ? raw.id : "flow_" name,
            name: name,
            entryNodeId: raw.HasProp("entryNodeId") ? raw.entryNodeId : "",
            enabled: !raw.HasProp("enabled") || raw.enabled,
            nodes: []
        }
        sourceNodes := raw.HasProp("nodes") ? raw.nodes : []
        for index, node in sourceNodes
            flow.nodes.Push(this.NormalizeNode(node, index))
        if (flow.entryNodeId = "" && flow.nodes.Length > 0)
            flow.entryNodeId := flow.nodes[1].id
        return flow
    }

    NormalizeNode(raw, index) {
        id := raw.HasProp("id") ? raw.id : "node_" index
        return {
            id: id,
            name: raw.HasProp("name") ? raw.name : "节点 " index,
            enabled: !raw.HasProp("enabled") || raw.enabled,
            scriptName: raw.HasProp("scriptName") ? raw.scriptName : "",
            onSuccess: this.NormalizeBranch(raw.HasProp("onSuccess") ? raw.onSuccess : {action: "next"}),
            onFailure: this.NormalizeBranch(raw.HasProp("onFailure") ? raw.onFailure : {action: "stop"}),
            maxLoops: raw.HasProp("maxLoops") ? raw.maxLoops : 0
        }
    }

    NormalizeBranch(branch) {
        action := branch.HasProp("action") ? branch.action : "next"
        normalized := {action: action}
        if branch.HasProp("targetNodeId")
            normalized.targetNodeId := branch.targetNodeId
        return normalized
    }
}
