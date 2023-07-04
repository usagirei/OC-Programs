local Class = require("libapp.class")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")
local Rect = require("libapp.struct.rect")
local DrawHelper = require("libapp.util.drawhelper")

local Super = require("libapp.gui.widget.container.layout")
---@class GridLayout : Layout
local GridLayout = Class.NewClass(Super, "GridLayout")

local function packSum(pack, iStart, iEnd, size)
	local abs = pack.abs
	local rel = pack.rel
	local rem = size - abs
	local sum = 0
	for i = math.max(0, iStart), math.min(pack.n - 1, iEnd) do
		---@type number
		local cc = pack[i + 1]
		if cc > 0 then
			sum = sum + (rem * cc / rel)
		elseif cc < 0 then
			sum = sum - cc
		end
	end
	return sum
end

---@param w integer
---@param h integer
---@return GridLayout
function GridLayout.new(w, h) 
	return Class.NewObj(GridLayout, w, h) 
end

---@param w integer
---@param h integer
---@private
function GridLayout:init(w, h)
	Super.init(self, w, h)

	self.m_ChildrenPos = setmetatable({}, { __mode = "k" })
	self.m_ChildrenAlign = setmetatable({}, { __mode = "k" })
	self:setColumns(1)
	self:setRows(1)
end

---@param ... number
function GridLayout:setColumns(...)
	local pack = table.pack(...)
	local abs = 0
	local rel = 0
	for i = 1, #pack do
		local n = pack[i]
		if n > 0 then
			rel = rel + n
		elseif n < 0 then
			abs = abs - n
		end
	end
	pack.abs = abs
	pack.rel = rel
	self.m_Cols = pack

	self:invalidate()
	self:invalidateLayout()
end

---@param ... number
function GridLayout:setRows(...)
	local pack = table.pack(...)
	local abs = 0
	local rel = 0
	for i = 1, #pack do
		local n = pack[i]
		if n > 0 then
			rel = rel + n
		elseif n < 0 then
			abs = abs - n
		end
	end
	pack.abs = abs
	pack.rel = rel
	self.m_Rows = pack

	self:invalidate()
	self:invalidateLayout()
end

---@param c Widget
---@param xCol integer # Column
---@param yRow integer # Row
---@param xColSpan? integer # Column Span
---@param yRowSpan? integer # Row Span
function GridLayout:addChild(c, xCol, yRow, xColSpan, yRowSpan)
	Args.isInteger(2, xCol)
	Args.isInteger(3, yRow)
	Args.isInteger(4, xColSpan, true)
	Args.isInteger(5, yRowSpan, true)

	self:setChildPosition(c, xCol or 0, yRow or 0, xColSpan or 1, yRowSpan or 1)
	self:setChildAlignment(c, Enums.Alignment.Center, Enums.Alignment.Center)
	Super.addChild(self, c)
end

---@param c Widget
---@param xCol integer # Column (X Axis)
---@param yRow integer # Row (Y Axis)
---@param xColSpan? integer # Column Span
---@param yRowSpan? integer # Row Span
function GridLayout:setChildPosition(c, xCol, yRow, xColSpan, yRowSpan)
	Args.isClass(1, c, "libapp.gui.widget")
	Args.isInteger(2, xCol)
	Args.isInteger(3, yRow)
	Args.isInteger(4, xColSpan, true)
	Args.isInteger(5, yRowSpan, true)

	self.m_ChildrenPos[c] = {
		col = xCol,
		row = yRow,
		colSpan = xColSpan or 1,
		rowSpan = yRowSpan or 1,
	}
	self:invalidateLayout()
end

---@param c Widget
function GridLayout:getChildPosition(c)
	Args.isClass(1, c, "libapp.gui.widget")

	local p = self.m_ChildrenPos[c]
	assert(p ~= nil, "Invalid Child")
	return p.col, p.row, p.colSpan, p.rowSpan
end

---@param c Widget
---@param xAlign Alignment # Alignment, or nil for stretch
---@param yAlign Alignment # Alignment, or nil for stretch
function GridLayout:setChildAlignment(c, xAlign, yAlign)
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
function GridLayout:getChildAlignment(c)
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

---@param row integer
---@param col integer
---@param rowSpan integer
---@param colSpan integer
---@private
function GridLayout:calculateGridRect(row, col, rowSpan, colSpan)
	local cRect = self:contentRect()

	local x = packSum(self.m_Cols, 0, col - 1, cRect:width())
	local y = packSum(self.m_Rows, 0, row - 1, cRect:height())
	local w = packSum(self.m_Cols, col, col + colSpan - 1, cRect:width())
	local h = packSum(self.m_Rows, row, row + rowSpan - 1, cRect:height())

	x = math.floor(x + 0.5)
	y = math.floor(y + 0.5)
	w = math.floor(w + 0.5)
	h = math.floor(h + 0.5)

	return Rect.new(cRect.left + x, cRect.top + y, w, h)
end

---@protected
function GridLayout:onLayout()
	local tmp = self:activeChildren()
	for i = 1, #tmp do
		local c = tmp[i]

		local col, row, nCol, nRow = self:getChildPosition(c)
		local xAlign, yAlign = self:getChildAlignment(c)

		local gRect = self:calculateGridRect(row, col, nRow, nCol)
		local cW, cH = c:desiredSize()
		local cRect = DrawHelper.alignRect(gRect, cW, cH, xAlign, yAlign)

		self:setChildRect(c, cRect)
	end
end

return GridLayout
