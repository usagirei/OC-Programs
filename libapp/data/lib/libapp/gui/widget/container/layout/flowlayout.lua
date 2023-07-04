local Class = require("libapp.class")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")
local Rect = require("libapp.struct.rect")

local Super = require("libapp.gui.widget.container.layout")
---@class FlowLayout : Layout
local FlowLayout = Class.NewClass(Super, "FlowLayout")

---@param w integer
---@param h integer
---@return FlowLayout
function FlowLayout.new(w, h)
	return Class.NewObj(FlowLayout, w, h)
end

---@param w integer
---@param h integer
---@private
function FlowLayout:init(w, h)
	Super.init(self, w, h)

	self:setSpacing(0, 0)
	self:setDirection(Enums.Direction2.Horizontal)
end

---@protected
function FlowLayout:onLayout()
	if self.m_Direction == Enums.Direction2.Horizontal then
		self:_hlayout()
	else
		self:_vlayout()
	end
end

---@private
function FlowLayout:_vlayout()
	local cRect = self:contentRect()

	local xBase = cRect.left
	local yBase = cRect.top
	local colWidth = 0

	local xPos = xBase
	local yPos = yBase

	local tmp = self:children()
	local yMax = cRect.bottom
	for i = 1, #tmp do
		local c = tmp[i]
		local childWidth, childHeight = c:desiredSize()

		local yNext = yPos + childHeight
		if yNext > yMax then
			xBase = xBase + colWidth + self.m_X_Spacing
			xPos = xBase
			yPos = yBase

			yNext = yPos + childHeight
			colWidth = 0
		end

		self:setChildRect(c, Rect.new(xPos, yPos, childWidth, childHeight))
		yPos = yNext + self.m_Y_Spacing
		colWidth = math.max(colWidth, childWidth)
	end
end

---@private
function FlowLayout:_hlayout()
	local cRect = self:contentRect()

	local xBase = cRect.left
	local yBase = cRect.top
	local rowHeight = 0

	local xPos = xBase
	local yPos = yBase

	local tmp = self:children()
	local xMax = cRect.right
	for i = 1, #tmp do
		local c = tmp[i]
		local childWidth, childHeight = c:desiredSize()

		local xNext = xPos + childWidth
		if xNext > xMax then
			yBase = yBase + rowHeight + self.m_Y_Spacing
			xPos = xBase
			yPos = yBase

			xNext = xPos + childWidth
			rowHeight = 0
		end

		self:setChildRect(c, Rect.new(xPos, yPos, childWidth, childHeight))
		xPos = xNext + self.m_X_Spacing
		rowHeight = math.max(rowHeight, childHeight)
	end
end

---@param xSpacing integer
---@param ySpacing integer
function FlowLayout:setSpacing(xSpacing, ySpacing)
	Args.isInteger(1, xSpacing)
	Args.isInteger(2, ySpacing)

	self.m_X_Spacing = xSpacing
	self.m_Y_Spacing = ySpacing

	self:invalidate()
	self:invalidateLayout()
end

---@return integer xSpacing
---@return integer ySpacing
function FlowLayout:spacing()
	return self.m_X_Spacing, self.m_Y_Spacing
end

---@param dir Direction2
function FlowLayout:setDirection(dir)
	Args.isEnum(1, dir, Enums.Direction2)

	self.m_Direction = dir

	self:invalidate()
	self:invalidateLayout()
end

---@return Direction2
function FlowLayout:direction()
	return self.m_Direction
end

return FlowLayout
