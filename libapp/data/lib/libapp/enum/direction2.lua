local Enum = require("libapp.enum")

---@enum Direction2
local E = {
    Horizontal = 0,
    Vertical = 1,
}

Enum.NewEnum("SizeMode", E)
return E

