#Requires AutoHotkey v2.0

class Holder {
    __New(callback) {
        this.callback := callback
    }

    Trigger() {
        this.callback.Call("ok")
    }
}

ResultSink(value) {
    if (value != "ok")
        throw Error("Unexpected callback value: " value)
}

callbackHolder := Holder(ResultSink)
callbackHolder.Trigger()
ExitApp(0)
