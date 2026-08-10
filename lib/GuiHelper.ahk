#Requires AutoHotkey v2.0

class GuiHelper {
    static DestroyOwner(target) {
        if !target
            return
        try {
            if target.HasProp("Gui") {
                target.Gui.Destroy()
                return
            }
        }
        try target.Destroy()
    }
}
