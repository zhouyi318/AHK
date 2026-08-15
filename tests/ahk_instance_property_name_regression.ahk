#Requires AutoHotkey v2.0

class FakeLogger {
}

class Holder {
    __New(v) {
        this.appLogger := v
    }
}

try {
    loggerValue := FakeLogger()
    holderObj := Holder(loggerValue)
    if !IsObject(holderObj.appLogger)
        throw Error("Instance properties should allow storing objects under non-conflicting names")
    ExitApp(0)
} catch {
    ExitApp(1)
}
