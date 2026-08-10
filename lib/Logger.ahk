; ===== 日志模块 =====
; 每次运行生成一个带时间戳的日志文件，记录状态切换/失败/停止原因

class Logger {
    __New(logDir) {
        this.logDir := logDir
        if !DirExist(logDir)
            DirCreate(logDir)

        ts := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        this.logPath := logDir "\bot_" ts ".log"
        this.Write("=== BOT LOG START ===")
    }

    Write(msg) {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" ts "] " msg
        try FileAppend line "`n", this.logPath, "UTF-8"
    }

    Info(msg) {
        this.Write("[INFO] " msg)
    }

    Warn(msg) {
        this.Write("[WARN] " msg)
    }

    Error(msg) {
        this.Write("[ERROR] " msg)
    }

    State(stateName) {
        this.Write("[STATE] -> " stateName)
    }
}
