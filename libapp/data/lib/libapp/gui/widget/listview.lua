local keyboard = require("keyboard")

local Class = require("libapp.class")
local Rect = require("libapp.struct.rect")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local DrawHelper = require("libapp.util.drawhelper")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget.selector")
---@class ListView : Selector
local ListView = Class.NewClass(Super, "ListView")

---@param w integer
---@param h integer
---@return ListView
function ListView.new(w, h)
	return Class.NewObj(ListView, w, h)
end

---@param w integer
---@param h integer
---@private
function ListView:init(w, h)
	Super.init(self, w, h)

	self.m_ScrollPos = 0

	self:setBorderStyle(Styles.Border.Round, Styles.Decorator.Single, false)
	self:setBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)

	self:setLabelColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	self:setLabel("")
	self:setLabelMode(Enums.LabelMode.Border)
	self:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Near, false)

	self:setScrollStyle(Styles.Track.Shade)
	self:setScrollColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	self:setItemColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	self:setSelectedItemColor(Enums.ColorKey.Foreground, Enums.ColorKey.AccentBackground)
end

---@param g Graphics
---@protected
function ListView:onDraw(g)
	Super.onDraw(self, g)

	local cRect = self:itemsRect()
	local cSize = self:itemCount()
	local vSize = cRect:height()

	if cSize > vSize then
		local sRect = self:scrollRect()
		local sSize = sRect:height()

		local thumbSize, _ = DrawHelper.calculateScrollParams(
			cSize,
			vSize,
			sSize
		)

		local overflow = cSize - vSize
		local fScroll = self:scrollPos() / overflow

		DrawHelper.trackbar(
			g, sRect, thumbSize,
			fScroll, Enums.Direction4.Down,
			self:scrollStyle(),
			self:getColors(self:scrollColor())
		)
	end

	g:pushClip(self:itemsRect())
	g:setColors(self:getColors(self:itemColor()))
	g:clear()
	local p = self:itemsRect():tl()
	local nItems = math.min(self:itemsRect():height(), self:itemCount())
	for i = 1, nItems do
		local idx = self:scrollPos() + i
		if idx == self:selectedIndex() then
			g:setColors(self:getColors(self:selectedItemColor()))
		else
			g:setColors(self:getColors(self:itemColor()))
		end
		g:setRows(p.y, 1, ' ')
		g:drawString(p, self:getDisplayText(idx))
		p.y = p.y + 1
	end
	g:popClip()
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
---@protected
function ListView:onClick(scr, p, btn, times, usr, overlay)
	local rItems = self:itemsRect()
	local rScroll = self:scrollRect()
	if rItems:contains(p) then
		local clickPos = math.floor(p.y) - rItems.top
		local topIdx = self.m_ScrollPos + 1
		local botIdx = math.min(self:itemCount(), topIdx + rItems:height())
		local newIdx = math.max(1, math.min(clickPos + topIdx, botIdx))
		if newIdx ~= self:selectedIndex() then
			self:setSelectedIndex(newIdx)
		end
	elseif rScroll:contains(p) then
		local dy = p.y - rScroll.top
		local clickPos = math.floor((dy * self:itemCount() / rScroll:height()) + 0.5)
		self:scrollIntoView(clickPos)
	end
	return true
end

---@param kbd string
---@param chr integer
---@param keycode integer
---@param usr string
---@return boolean
---@protected
function ListView:onKeyDown(kbd, chr, keycode, usr)
	if not self:focused() then return false end

	if keycode == keyboard.keys['end'] then
		self:setSelectedIndex(self:itemCount())
	elseif keycode == keyboard.keys.home then
		self:setSelectedIndex(0)
	elseif keycode == keyboard.keys.up then
		self:setSelectedIndex(self:selectedIndex() - 1)
	elseif keycode == keyboard.keys.down then
		self:setSelectedIndex(self:selectedIndex() + 1)
	elseif keycode == keyboard.keys.pageUp then
		self:setSelectedIndex(self:selectedIndex() - self:itemsRect():height())
	elseif keycode == keyboard.keys.pageDown then
		self:setSelectedIndex(self:selectedIndex() + self:itemsRect():height())
	end

	self:scrollIntoView(self:selectedIndex())
	self:invalidate()
	return true
end

---@param scr string # screen address
---@param p Point # screen coordinates
---@param delta integer # scroll delta
---@param usr string # user
---@protected
function ListView:onScroll(scr, p, delta, usr)
	if self:contentRect():contains(p) then
		local dir = delta > 0 and -1 or 1
		local step = 3
		local pos = self:scrollPos() + (dir * step)
		self:setScrollPos(math.floor(pos + 0.5))
		return true
	end
end

---@param scr string # screen Address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@return boolean # true to start drag
---@protected
function ListView:onBeginDrag(scr, p, btn, usr)
	self.m_DragIndex = self.m_ScrollPos
	if self:scrollRect():contains(p) then
		self.m_DragMode = 0
		return true
	elseif self:itemsRect():contains(p) then
		self.m_DragMode = 1
		return true
	end
	return false
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@protected
function ListView:onDrag(scr, p, delta, btn, usr)
	local dy
	if self.m_DragMode == 0 then
		local _, scrollStep = DrawHelper.calculateScrollParams(
			self:itemCount(),
			self:itemsRect():height(),
			self:scrollRect():height()
		)
		dy = delta.y * scrollStep
	elseif self.m_DragMode == 1 then
		dy = -delta.y
	end
	local pos = self.m_DragIndex + dy
	self:setScrollPos(math.floor(pos + 0.5))
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@protected
function ListView:onDrop(scr, p, btn, usr)
	self.m_DragIndex = nil
	self.m_DragMode = -1
	self:invalidate()
end

function ListView:invalidateRects()
	Super.invalidateRects(self)
	self.m_ItemsRect = nil
	self.m_ScrollRect = nil
end

---@private
---@return Rect
function ListView:itemsRect()
	if self.m_ItemsRect == nil then
		local cRect = self:contentRect()
		local hasScroll = self:itemCount() > cRect:height()
		if hasScroll then
			self.m_ItemsRect = cRect:inflated(0, 0, -1, 0)
		else
			self.m_ItemsRect = cRect
		end
	end
	return self.m_ItemsRect
end

---@private
---@return Rect
function ListView:scrollRect()
	if self.m_ScrollRect == nil then
		local iRect = self:itemsRect()
		local hasScroll = self:itemCount() > iRect:height()
		if hasScroll then
			self.m_ScrollRect = Rect.new(iRect.right, iRect.top, 1, iRect:height())
		else
			self.m_ScrollRect = Rect.new(iRect.right, iRect.top, 0, iRect:height())
		end
	end
	return self.m_ScrollRect
end

--- Sets the Scroll Top index
---@param index integer
function ListView:setScrollPos(index)
	Args.isInteger(1, index)

	local nVisible = self:itemsRect():height()
	local maxPos = math.max(0, self:itemCount() - nVisible)
	local newPos = math.min(math.max(0, index), maxPos)
	if newPos ~= self.m_ScrollPos then
		self.m_ScrollPos = newPos
		self:invalidate()
	end
end

---@return integer
function ListView:scrollPos()
	return self.m_ScrollPos
end

---@param index integer
function ListView:scrollIntoView(index)
	Args.isInteger(1, index)

	local vp = self:contentRect():height()
	local iMin = self:scrollPos() + 1
	local iMax = iMin + vp
	if index < iMin then
		self:setScrollPos(index - 1)
	elseif index > iMax then
		self:setScrollPos(index - vp)
	end
end

---@param style TrackStyle
function ListView:setScrollStyle(style)
	Args.isValue(1, style, Args.ValueType.Table)

	self.m_ScrollStyle = style
end

---@return TrackStyle
function ListView:scrollStyle()
	return self.m_ScrollStyle
end

---@param thumbFore Color
---@param thumbBack Color
---@param trackFore? Color # defaults to thumbFore
---@param trackBack? Color # defaults to thumbBack
function ListView:setScrollColor(thumbFore, thumbBack, trackFore, trackBack)
	Args.isAnyValue(1, thumbFore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, thumbBack, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(3, trackFore, true, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(4, trackBack, true, Args.ValueType.String, Args.ValueType.Number)

	self.m_ScrollThumbForeground = thumbFore
	self.m_ScrollThumbBackground = thumbBack
	self.m_ScrollTrackForeground = trackFore or thumbFore
	self.m_ScrollTrackBackground = trackBack or thumbBack
end

---@return Color thumbFore
---@return Color thumbBack
---@return Color trackFore
---@return Color trackBack
function ListView:scrollColor()
	return self.m_ScrollThumbForeground, self.m_ScrollThumbBackground, self.m_ScrollTrackForeground,
		self.m_ScrollTrackBackground
end

---@param fore Color
---@param back Color
function ListView:setItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_ItemForeground = fore
	self.m_ItemBackground = back
end

---@return Color
---@return Color
function ListView:itemColor()
	return self.m_ItemForeground, self.m_ItemBackground
end

---@param fore Color
---@param back Color
function ListView:setSelectedItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_SelectedItemForeground = fore
	self.m_SelectedItemBackground = back
end

---@return Color
---@return Color
function ListView:selectedItemColor()
	return self.m_SelectedItemForeground, self.m_SelectedItemBackground
end

return ListView
