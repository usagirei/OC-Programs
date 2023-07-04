local Enum = require("libapp.enum")

---@class SeparatorStyle
local E = {}
E.Single = {
    left = { "╶", "─", "╴", false },
    down = { "╷", "│", "╵", false }
}
E.Single_Tee = {
    left = { "├", "─", "┤", false },
    down = { "┬", "│", "┴", false }
}

Enum.NewEnum("SeparatorStyle", E)
return E
