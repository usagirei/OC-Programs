local Class = require("libapp.class")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")
local DrawHelper = require("libapp.util.drawhelper")

local Super = require("libapp.gui.widget.container.layout")
---@class MainLayout : Layout
local MainLayout = Class.NewClass(Super, "MainLayout")

---@param w integer
---@param h integer
---@return MainLayout
function MainLayout.new(w, h)
	return Class.NewObj(MainLayout, w, h)
end

---@param w integer
---@param h integer
---@private
function MainLayout:init(w, h)
	Super.init(self, w, h)
	self.m_ChildrenAlign = setmetatable({}, { __mode = "k" })
end

---@param c Widget
---@param xAlign Alignment # Alignment, or nil for stretch
---@param yAlign Alignment # Alignment, or nil for stretch
function MainLayout:setChildAlignment(c, xAlign, yAlign)
	Args.isClass(1, c, "libapp.gui.widget")
	Args.isEnum(2, xAlign, Enums.Alignment)
	Args.isEnum(3, yAlign, Enums.Alignment)

	self.m_ChildrenAlign[c] = {
		horizontal = xAlign,
		vertical = yAlign
	}
	self:invalidateLayout()
end

---@return Alignment xAlign
---@return Alignment yAlign
function MainLayout:getChildAlignment(c)
	Args.isClass(1, c, "libapp.gui.widget")

	local a = self.m_ChildrenAlign[c]
	local xAlign, yAlign
	if a ~= nil then
		xAlign, yAlign = a.horizontal, a.vertical
	else
		xAlign, yAlign = Enums.Alignment.Near, Enums.Alignment.Near
	end
	return xAlign, yAlign
end

---@protected
function MainLayout:onLayout()
	local tmp = self:activeChildren()
	local gRect = self:contentRect()
	for i = 1, #tmp do
		local c = tmp[i]
		local cW, cH = c:desiredSize()
		local xA, yA = self:getChildAlignment(c)

		local cRect = DrawHelper.alignRect(gRect, cW, cH, xA, yA)

		self:setChildRect(c, cRect)
	end
end

return MainLayout
