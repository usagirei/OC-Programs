local Enum = require("libapp.enum")

---@enum Direction4
local E = {
    Up = 0,
    Down = 1,
    Left = 2,
    Right = 3
}

Enum.NewEnum("Direction4", E)
return E
