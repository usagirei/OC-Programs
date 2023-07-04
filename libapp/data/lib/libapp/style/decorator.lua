local Enum = require("libapp.enum")

---@class DecoratorStyle
local E = {}
E.None = {
    left = { "", "", false },
    right = 'left',
    up = 'left',
    down = 'left'
}
E.Double = {
    left = { "╨", "╥", false },
    up = { "╡", "╞", false },
    right = 'left',
    down = 'up'
}
E.Single = {
    left = { "┴", "┬", false },
    up = { "┤", "├", false },
    right = 'left',
    down = 'up'
}
E.Cap = {
    left = { "╵", "╷", false },
    up = { "╴", "╶", false },
    right = 'left',
    down = 'up'
}
E.Solid = {
    left = { "\u{1fb45}", "\u{1fb56}", true },
    right = { "\u{1fb50}", "\u{1fb61}", true },
    up = { "\u{1fb44}", "\u{1fb4f}", true },
    down = { "\u{1fb55}", "\u{1fb60}", true }
}
E.SolidShadow = {
    left = { "", "", true },
    right = { "", "", true },
    up = { "\u{1fb42}", "\u{1fb4d}", true },
    down = { "█", "█", true }
}

Enum.NewEnum("DecoratorStyle", E)
return E
