; ===== 脚本与配置 JSON 持久化模块 =====
; 保存/加载录制的脚本（进图脚本等）和存仓配置
; AHK v2 无内置 JSON，手写简易序列化/反序列化

class ScriptStore {
    __New(scriptsDir) {
        this.scriptsDir := scriptsDir
        if !DirExist(scriptsDir)
            DirCreate(scriptsDir)
        this.storeCfgFile := scriptsDir "\store_config.json"
    }

    ; ===== 脚本管理 =====

    ; 保存脚本（覆盖写入，script 含 name, targetMapImage, steps）
    SaveScript(script) {
        path := this.scriptsDir "\" script.name ".json"
        if FileExist(path)
            FileDelete(path)
        json := this.ToJson(script)
        FileAppend json, path, "UTF-8"
    }

    ; 加载脚本，返回脚本对象；不存在返回 ""
    LoadScript(name) {
        path := this.scriptsDir "\" name ".json"
        if !FileExist(path)
            return ""
        str := FileRead(path, "UTF-8")
        return this.ParseJson(str)
    }

    ; 列出所有脚本名（排除 store_config.json）
    ListScripts() {
        list := []
        loop files, this.scriptsDir "\*.json" {
            fname := A_LoopFileName
            ; 去掉 .json 后缀
            name := SubStr(fname, 1, StrLen(fname) - 5)
            if (name != "store_config")
                list.Push(name)
        }
        return list
    }

    ; 删除脚本
    DeleteScript(name) {
        path := this.scriptsDir "\" name ".json"
        if FileExist(path)
            FileDelete(path)
    }

    ; ===== 存仓配置 =====

    SaveStoreConfig(cfg) {
        if FileExist(this.storeCfgFile)
            FileDelete(this.storeCfgFile)
        json := this.ToJson(cfg)
        FileAppend json, this.storeCfgFile, "UTF-8"
    }

    LoadStoreConfig() {
        if !FileExist(this.storeCfgFile)
            return {intervalMinutes: 60, itemNames: []}
        str := FileRead(this.storeCfgFile, "UTF-8")
        cfg := this.ParseJson(str)
        if !cfg.HasProp("intervalMinutes")
            cfg.intervalMinutes := 60
        if !cfg.HasProp("itemNames")
            cfg.itemNames := []
        return cfg
    }

    ; ===== JSON 序列化 =====

    ToJson(val) {
        if (Type(val) = "String")
            return this.QuoteString(val)
        if (val is Integer)
            return String(val)
        if (val is Float)
            return String(val)
        if (val = true)
            return "true"
        if (val = false)
            return "false"
        if (val is Array) {
            out := "["
            for i, v in val {
                if (i > 1)
                    out .= ","
                out .= this.ToJson(v)
            }
            return out "]"
        }
        if (val is Map) {
            out := "{"
            first := true
            for k, v in val {
                if (!first)
                    out .= ","
                out .= this.QuoteString(String(k)) ":" this.ToJson(v)
                first := false
            }
            return out "}"
        }
        if (IsObject(val)) {
            out := "{"
            first := true
            for k, v in val.OwnProps() {
                if (!first)
                    out .= ","
                out .= this.QuoteString(String(k)) ":" this.ToJson(v)
                first := false
            }
            return out "}"
        }
        return "null"
    }

    QuoteString(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }

    ; ===== JSON 反序列化（递归下降解析器）=====

    ParseJson(str) {
        p := {str: str, pos: 1}
        return this.ParseValue(p)
    }

    ParseValue(p) {
        this.SkipSpace(p)
        if (p.pos > StrLen(p.str))
            return ""
        ch := SubStr(p.str, p.pos, 1)
        if (ch = "{")
            return this.ParseObject(p)
        if (ch = "[")
            return this.ParseArray(p)
        if (ch = '"')
            return this.ParseString(p)
        return this.ParseNumber(p)
    }

    SkipSpace(p) {
        while (p.pos <= StrLen(p.str)) {
            ch := SubStr(p.str, p.pos, 1)
            if (ch = " " || ch = "`t" || ch = "`n" || ch = "`r")
                p.pos += 1
            else
                break
        }
    }

    ParseObject(p) {
        obj := {}
        p.pos += 1  ; 跳过 {
        this.SkipSpace(p)
        if (SubStr(p.str, p.pos, 1) = "}") {
            p.pos += 1
            return obj
        }
        loop {
            this.SkipSpace(p)
            key := this.ParseString(p)
            this.SkipSpace(p)
            p.pos += 1  ; 跳过 :
            val := this.ParseValue(p)
            obj.%key% := val
            this.SkipSpace(p)
            ch := SubStr(p.str, p.pos, 1)
            if (ch = "}") {
                p.pos += 1
                break
            }
            if (ch = ",") {
                p.pos += 1
                continue
            }
            break
        }
        return obj
    }

    ParseArray(p) {
        arr := []
        p.pos += 1  ; 跳过 [
        this.SkipSpace(p)
        if (SubStr(p.str, p.pos, 1) = "]") {
            p.pos += 1
            return arr
        }
        loop {
            val := this.ParseValue(p)
            arr.Push(val)
            this.SkipSpace(p)
            ch := SubStr(p.str, p.pos, 1)
            if (ch = "]") {
                p.pos += 1
                break
            }
            if (ch = ",") {
                p.pos += 1
                continue
            }
            break
        }
        return arr
    }

    ParseString(p) {
        p.pos += 1  ; 跳过 "
        out := ""
        loop {
            ch := SubStr(p.str, p.pos, 1)
            if (ch = "") {
                break
            }
            if (ch = '"') {
                p.pos += 1
                break
            }
            if (ch = "\") {
                p.pos += 1
                esc := SubStr(p.str, p.pos, 1)
                if (esc = "n")
                    out .= "`n"
                else if (esc = "t")
                    out .= "`t"
                else if (esc = "r")
                    out .= "`r"
                else if (esc = '"')
                    out .= '"'
                else if (esc = "\")
                    out .= "\"
                else if (esc = "/")
                    out .= "/"
                else if (esc = "u") {
                    hex := SubStr(p.str, p.pos + 1, 4)
                    p.pos += 4
                    try code := Integer("0x" hex)
                    if (code)
                        out .= Chr(code)
                } else
                    out .= esc
                p.pos += 1
            } else {
                out .= ch
                p.pos += 1
            }
        }
        return out
    }

    ParseNumber(p) {
        this.SkipSpace(p)
        ; true / false / null
        if (SubStr(p.str, p.pos, 4) = "true") {
            p.pos += 4
            return true
        }
        if (SubStr(p.str, p.pos, 5) = "false") {
            p.pos += 5
            return false
        }
        if (SubStr(p.str, p.pos, 4) = "null") {
            p.pos += 4
            return ""
        }
        ; 数字
        start := p.pos
        while (p.pos <= StrLen(p.str)) {
            ch := SubStr(p.str, p.pos, 1)
            if (InStr("0123456789-+.", ch))
                p.pos += 1
            else
                break
        }
        num := SubStr(p.str, start, p.pos - start)
        if (InStr(num, "."))
            return Float(num)
        return Integer(num)
    }
}
