local Class = require("libapp.class")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")
local Rect = require("libapp.struct.rect")
local DrawHelper = require("libapp.util.drawhelper")

local Super = require("libapp.gui.widget.container.layout")
---@class StackLayout : Layout
local StackLayout = Class.NewClass(Super, "StackLayout")

---@param w integer
---@param h integer
---@return StackLayout
function StackLayout.new(w, h)
	return Class.NewObj(StackLayout, w, h)
end

---@param w integer
---@param h integer
---@private
function StackLayout:init(w, h)
	Super.init(self, w, h)

	self.m_ChildrenAlign = setmetatable({}, { __mode = "k" })
	self.m_OptimalSize = nil
	self:setSpacing(0)
	self:setDirection(Enums.Direction2.Horizontal)
	self:setSizeMode(Enums.SizeMode.Fixed, Enums.SizeMode.Fixed)
end

function StackLayout:invalidateRects()
	Super.invalidateRects(self)
	self.m_OptimalSize = nil
end

---@protected
function StackLayout:onLayout()
	if self:direction() == Enums.Direction2.Horizontal then
		self:_hlayout()
	else
		self:_vlayout()
	end
end

---@private
function StackLayout:_vlayout()
	local mRect = self:contentRect()

	local pos = mRect.top
	local tmp = self:activeChildren()
	for i = 1, #tmp do
		local c = tmp[i]
		local cW, cH = c:desiredSize()
		local xA, yA = self:getChildAlignment(c)

		local next = pos + cH

		local gRect = Rect.new(mRect:x(), pos, mRect:width(), cH)
		local cRect = DrawHelper.alignRect(gRect, cW, cH, xA, yA)

		self:setChildRect(c, cRect)
		pos = next + self.m_Spacing
	end
end

---@private
function StackLayout:_hlayout()
	local mRect = self:contentRect()

	local pos = mRect.left
	local tmp = self:activeChildren()
	for i = 1, #tmp do
		local c = tmp[i]
		local cW, cH = c:desiredSize()
		local xA, yA = self:getChildAlignment(c)

		local next = pos + cW

		local gRect = Rect.new(pos, mRect:y(), cW, mRect:height())
		local cRect = DrawHelper.alignRect(gRect, cW, cH, xA, yA)

		self:setChildRect(c, cRect)
		pos = next + self.m_Spacing
	end
end

---@return integer # Width
---@return integer # Height
function StackLayout:minimumSize()
	if self.m_OptimalSize == nil then
		local tmp = self:activeChildren()
		local brd, _ = self:borderStyle()
		local l, u, r, d = DrawHelper.getBorderSizes(brd)
		local sx, sy = 0, 0
		local cx, cy = 0, 0

		if self.m_Direction == Enums.Direction2.Horizontal then
			for i = 1, #tmp do
				local cW, cH = tmp[i]:desiredSize()
				sx = sx + cW + self.m_Spacing
				cx = cx + cW
				sy = math.max(sy, cH)
				cy = sy
			end
			sx = math.max(0, sx - self.m_Spacing)
		else
			for i = 1, #tmp do
				local cW, cH = tmp[i]:desiredSize()
				sy = sy + cH + self.m_Spacing
				cy = cy + cH
				sx = math.max(sx, cW)
				cx = sx
			end
			sy = math.max(0, sy - self.m_Spacing)
		end
		sx = sx + l + r
		sy = sy + u + d
		self.m_OptimalSize = { x = sx, y = sy, cx = cx, cy = cy }
	end
	return self.m_OptimalSize.x, self.m_OptimalSize.y
end

---@param c Widget
---@param xAlign Alignment # Alignment, or nil for stretch
---@param yAlign Alignment # Alignment, or nil for stretch
function StackLayout:setChildAlignment(c, xAlign, yAlign)
	Args.isClass(1, c, "libapp.gui.widget")
	Args.isEnum(2, xAlign, Enums.Alignment)
	Args.isEnum(3, yAlign, Enums.Alignment)

	self.m_ChildrenAlign[c] = {
		horizontal = xAlign,
		vertical = yAlign
	}
	self:invalidate()
	self:invalidateLayout()
end

---@return Alignment xAlign
---@return Alignment yAlign
function StackLayout:getChildAlignment(c)
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

---@param spacing integer
function StackLayout:setSpacing(spacing)
	Args.isInteger(1, spacing)

	self.m_Spacing = spacing
	self:invalidate()
	self:invalidateLayout()
end

---@return integer spacing
function StackLayout:spacing()
	return self.m_Spacing
end

---@param dir Direction2
function StackLayout:setDirection(dir)
	Args.isEnum(1, dir, Enums.Direction2)

	self.m_Direction = dir
end

---@return Direction2
function StackLayout:direction()
	return self.m_Direction
end

return StackLayout
