local Enum = require("libapp.enum")

---@alias Color ColorKey|integer

---@enum ColorKey
local E = {
    Foreground = 'foreground',
    Background = 'background',
    ControlForeground = 'controlForeground',
    ControlBackground = 'controlBackground',
    AccentForeground = 'accentForeground',
    AccentBackground = 'accentBackground',
    ErrorForeground = 'errorForeground',
    ErrorBackground = 'errorBackground'
}

Enum.NewEnum("ColorKey", E)
return E
