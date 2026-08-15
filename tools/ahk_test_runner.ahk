#Requires AutoHotkey v2.0

if (A_Args.Length < 2)
    ExitApp(2)

testPath := A_Args[1]
statusPath := A_Args[2]
timeoutMs := (A_Args.Length >= 3 ? Integer(A_Args[3]) : 120000)

try {
    if FileExist(statusPath)
        FileDelete(statusPath)
}

try {
    Run('"' A_AhkPath '" "' testPath '" "' statusPath '"', , , &pid)
} catch {
    FileAppend("EXIT=-1", statusPath, "UTF-8")
    ExitApp(1)
}

deadline := A_TickCount + timeoutMs
while (A_TickCount < deadline) {
    if FileExist(statusPath)
        ExitApp(0)
    if !ProcessExist(pid)
        break
    Sleep 50
}

if ProcessExist(pid) {
    try ProcessClose(pid)
    FileAppend("EXIT=-2", statusPath, "UTF-8")
    ExitApp(1)
}

FileAppend("EXIT=-1", statusPath, "UTF-8")
ExitApp(1)
