local Enum = require("libapp.enum")

---@enum SizeMode
local E = {
    Fixed = 0,
    Automatic = 1,
    Stretch = 2
}

Enum.NewEnum("SizeMode", E)
return E

