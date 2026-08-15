#Requires AutoHotkey v2.0

#Include ScriptStore.ahk

class ScriptRepository extends ScriptStore {
    CreateScript(name, type := "enter_map") {
        return {
            id: "script_" name,
            name: name,
            type: type,
            enabled: true,
            metadata: {
                targetMapImage: "",
                targetMapRegion: "",
                notes: ""
            },
            steps: []
        }
    }

    LoadScript(name) {
        raw := super.LoadScript(name)
        if !raw
            return ""
        return this.NormalizeScript(raw, name)
    }

    SaveScript(script) {
        normalized := this.NormalizeScript(script)
        raw := {
            id: normalized.id,
            name: normalized.name,
            type: normalized.type,
            enabled: normalized.enabled,
            metadata: normalized.metadata,
            steps: normalized.steps
        }
        super.SaveScript(raw)
    }

    ListScriptsByType(type) {
        names := []
        for _, name in this.ListScripts() {
            script := this.LoadScript(name)
            if (script && script.type = type)
                names.Push(name)
        }
        return names
    }

    SaveStoreConfig(cfg) {
        if !cfg.HasProp("flowScriptName")
            cfg.flowScriptName := ""
        super.SaveStoreConfig(cfg)
    }

    LoadStoreConfig() {
        cfg := super.LoadStoreConfig()
        if !cfg.HasProp("flowScriptName")
            cfg.flowScriptName := ""
        return cfg
    }

    NormalizeScript(raw, fallbackName := "") {
        if (raw.HasProp("type") && raw.HasProp("metadata"))
            return raw

        name := raw.HasProp("name") ? raw.name : fallbackName
        return {
            id: "script_" name,
            name: name,
            type: "enter_map",
            enabled: true,
            metadata: {
                targetMapImage: raw.HasProp("targetMapImage") ? raw.targetMapImage : "",
                targetMapRegion: raw.HasProp("targetMapRegion") ? raw.targetMapRegion : "",
                notes: ""
            },
            steps: this.NormalizeLegacySteps(raw.HasProp("steps") ? raw.steps : [])
        }
    }

    NormalizeLegacySteps(steps) {
        normalized := []
        for index, step in steps {
            params := {}
            stepType := step.HasProp("type") ? step.type : "unknown"
            for key, value in step.OwnProps() {
                if (key = "type")
                    continue
                params.%key% := value
            }
            normalized.Push({
                id: "step_" index,
                type: stepType,
                name: stepType " " index,
                enabled: true,
                params: params,
                onSuccess: {action: "next"},
                onFailure: {action: "stop"}
            })
        }
        return normalized
    }
}
