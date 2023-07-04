local Enum = require("libapp.enum")

---@enum LabelMode
local E = {
    None = 0,
    Default = 1,
    Border = 2,
    Content = 3,
    Prefix = 4,
    Ghost = 5,
}

Enum.NewEnum("SizeMode", E)
return E

