local Class = require("libapp.class")

---@class Window : Object
local Window = Class.NewClass(nil, "Window")

---@return Window
function Window.new()
	return Class.NewObj(Window)
end

---@param app Application # Application
---@param w integer # Width
---@param h integer # Height
---@return Widget
function Window:inflate(app, w, h)
	error("not implemented" .. Class.TypeName(self))
end

---@param elapsedTime number
function Window:onUpdate(elapsedTime) end

function Window:onLoaded() end

function Window:onClosed() end

function Window:onClosing() return true end

return Window
