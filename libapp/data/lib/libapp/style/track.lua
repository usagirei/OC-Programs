local Enum = require("libapp.enum")

---@class TrackStyle
local E = {}
E.Shade = {
    down = { "░", "█", "░", false },
    left = 'down',
    right = 'down',
    up = 'down'
}
E.Shade2 = {
    left = { "\u{1FB8E}", "▀", "\u{1FB8E}", false },
    down = { "\u{1FB90}", "█", "\u{1FB90}", false },
    right = 'left',
    up = 'down'
}

Enum.NewEnum("TrackStyle", E)
return E
