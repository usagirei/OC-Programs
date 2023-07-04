local Class = require("libapp.class")

local Super = require("libapp.gui.widget.container")
---@class Layout : Container
local Layout = Class.NewClass(Super, "Layout")

---@param w integer
---@param h integer
function Layout:init(w, h)
	self.m_IsLayouting = true
	Super.init(self, w, h)
	self.m_IsLayouting = false
end

function Layout:onLayout()
	error("not implemented")
end

function Layout:setLayoutDirty()
	Super:setLayoutDirty()
	self.m_LayoutDirty = true
end

function Layout:invalidateRects()
	Super.invalidateRects(self)

	if self.m_LayoutDirty then
		self.m_LayoutDirty = false
		self.m_IsLayouting = true
		self:onLayout()
		self.m_IsLayouting = false
	end
end

return Layout
