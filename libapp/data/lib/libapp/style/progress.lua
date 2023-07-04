local Enum = require("libapp.enum")

---@class ProgressBarStyle
local E = {}
E.Solid = {
    left = { "█", "▉", "▊", "▋", "▌", "▍", "▎", "▏", " ", true },
    right = { " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█", false },
    up = { " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", false },
    down = { "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " ", true }
}
E.Shaded = {
    left = { " ", "░", "▒", "▓", "█", false },
    right = 'left',
    up = 'left',
    down = 'left'
}

Enum.NewEnum("ProgressStyle", E)
return E
