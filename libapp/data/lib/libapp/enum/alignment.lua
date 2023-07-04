local Enum = require("libapp.enum")

---@enum Alignment
local E = {
    Near = -1,
    Center = 0,
    Far = 1
}

Enum.NewEnum("SizeMode", E)
return E

