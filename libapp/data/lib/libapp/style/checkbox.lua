local Enum = require("libapp.enum")

---@class ToggleStyle
local E = {}
E.Circle = {
    [false] = "○",
    [true] = "◉"
}
E.Square = {
    [false] = "□",
    [true] = "▣"
}
E.Cross = {
    [false] = "☐",
    [true] = "☒"
}
E.Check = {
    [false] = "☐",
    [true] = "☑"
}

Enum.NewEnum("ToggleStyle", E)
return E
