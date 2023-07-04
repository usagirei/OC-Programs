local Enum = require("libapp.enum")

---@class BorderStyle
local E = {}

E.None = { "", "", "", "", "", "", "", "" }
E.Thin = { "│", "│", "─", "─", "┌", "┐", "└", "┘" }
E.Thin_DoubleTop = { "│", "│", "═", "─", "╒", "╕", "└", "┘" }
E.Round = { "│", "│", "─", "─", "╭", "╮", "╰", "╯" }
E.Underline = { "", "", "", "─", "", "", "", "" }
E.Popup_Round = { "│", "│", "", "─", "╮", "╭", "╰", "╯" }
E.Popup_Solid = { "▐", "▌", "", "▀", "▐", "▌", "▝", "▘" }
E.Popup_SolidShadow = { "█", "█", "", "\u{1fb91}", "▄", "▄", "\u{1fb91}", "\u{1fb91}" }
E.Solid = { "\u{2590}", "\u{258c}", "\u{1fb2d}", "\u{1fb02}", "\u{1fb1e}", "\u{1fb0f}", "\u{1fb01}", "\u{1fb00}" }
E.SolidShadow = { "█", "█", "\u{1fb39}", "\u{1fb91}", "\u{1fb39}", "\u{1fb39}", "\u{1fb91}", "\u{1fb91}" }

Enum.NewEnum("BorderStyle", E)
return E
