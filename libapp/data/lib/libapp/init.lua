local lib = {}

lib.Application = require("libapp.gui.application")
lib.Window = require("libapp.gui.window")

lib.Enums = require("libapp.enums")
lib.Styles = require("libapp.styles")
lib.GUI = require("libapp.gui")
lib.Graphics = require("libapp.gfx.graphics")

---@param en boolean
function lib.enableTypeChecks(en)
    require("libapp.util.args").setActive(en)
end

return lib