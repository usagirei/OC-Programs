local Class = require("libapp.class")
local Args = require("libapp.util.args")
local Rect = require("libapp.struct.rect")

local Super = require("libapp.gui.widget.container.layout")
---@class CanvasLayout : Layout
local CanvasLayout = Class.NewClass(Super, "CanvasLayout")

---@param w integer
---@param h integer
---@return CanvasLayout
function CanvasLayout.new(w, h) 
	return Class.NewObj(CanvasLayout, w, h) 
end

---@param w integer
---@param h integer
---@private
function CanvasLayout:init(w, h)
	Super.init(self, w, h)

	self.m_ChildPos = setmetatable({}, { __mode = 'k' })
end

---@param c Widget
---@param x integer # X Position
---@param y integer # Y Position
function CanvasLayout:addChild(c, x, y)
	Args.isInteger(2, x)
	Args.isInteger(3, y)

	self:setChildPosition(c, x, y)
	Super.addChild(self, c)
end

---@param c Widget
---@param x integer # X Position
---@param y integer # Y Position
function CanvasLayout:setChildPosition(c, x, y)
	Args.isClass(1, c, "libapp.gui.widget")
	Args.isInteger(2, x)
	Args.isInteger(3, y)

	self.m_ChildPos[c] = { x = x, y = y }

	self:invalidate()
	self:invalidateLayout()
end

---@return integer x # X Position
---@return integer y # Y Position
function CanvasLayout:getChildPosition(c)
	Args.isClass(1, c, "libapp.gui.widget")

	local p = self.m_ChildPos[c]
	assert(p ~= nil, "Invalid Child")
	return p.x, p.y
end

---@protected
function CanvasLayout:onLayout()
	local tmp = self:activeChildren()
	local rBase = self:contentRect()
	for i = 1, #tmp do
		local c = tmp[i]
		local w, h = c:desiredSize()
		local x, y = self:getChildPosition(c)
		self:setChildRect(c, Rect.new(rBase.left + x, rBase.top + y, w, h))
	end
end

return CanvasLayout
