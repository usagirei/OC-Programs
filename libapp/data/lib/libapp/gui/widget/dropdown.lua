local keyboard = require("keyboard")

local Class = require("libapp.class")
local Rect = require("libapp.struct.rect")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local DrawHelper = require("libapp.util.drawhelper")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget.selector")
---@class Dropdown : Selector
local Dropdown = Class.NewClass(Super, "Dropdown")
Dropdown.__Arrow = { "▾", "▴" }

---@param w integer
---@param h integer
---@return Dropdown
function Dropdown.new(w, h)
	return Class.NewObj(Dropdown, w, h)
end

---@param w integer
---@param h integer
---@private
function Dropdown:init(w, h)
	Super.init(self, w, h)

	self.m_ScrollPos = 0
	self.m_PopupOpen = false

	self:setLabel("")
	self:setLabelMode(Enums.LabelMode.Border)
	self:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Near, false)

	self:setPopupBorderStyle(Styles.Border.Popup_Solid, 5)
	self:setPopupBorderColor(Enums.ColorKey.ControlBackground, Enums.ColorKey.Background)

	self:setPopupItemColor(Enums.ColorKey.ControlForeground, Enums.ColorKey.ControlBackground)
	self:setPopupSelectedItemColor(Enums.ColorKey.ControlForeground, Enums.ColorKey.AccentBackground)

	self:setPopupScrollStyle(Styles.Track.Shade)
	self:setPopupScrollColor(
		Enums.ColorKey.AccentForeground, Enums.ColorKey.ControlBackground,
		Enums.ColorKey.AccentBackground, Enums.ColorKey.ControlBackground
	)

	self:setBorderStyle(Styles.Border.None, Styles.Decorator.None)
	self:setBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
end

---@protected
function Dropdown:onFocusGot()
	self:showDropdown()
end

---@protected
function Dropdown:onFocusLost()
	self:hideDropdown()
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
---@protected
function Dropdown:onClick(scr, p, btn, times, usr, overlay)
	if overlay then
		local rItems = self:itemsRect()
		local rScroll = self:scrollRect()
		if rItems:contains(p) then
			local clickPos = math.floor(p.y) - rItems.top
			local topIdx = self.m_ScrollPos + 1
			local botIdx = math.min(self:itemCount(), topIdx + rItems:height())
			local newIdx = math.max(1, math.min(clickPos + topIdx, botIdx))
			if newIdx == self:selectedIndex() and times >= 2 then
				self:hideDropdown()
			else
				self:setSelectedIndex(newIdx)
			end
		elseif rScroll:contains(p) then
			local dy = p.y - rScroll.top
			local clickPos = math.floor((dy * self:itemCount() / rScroll:height()) + 0.5)
			self:scrollIntoView(clickPos + 1)
		end
	elseif not overlay and self.m_PopupOpen then
		self:hideDropdown()
	end
	return true
end

---@param scr string # screen address
---@param p Point # screen coordinates
---@param delta integer # scroll delta
---@param usr string # user
---@protected
function Dropdown:onScroll(scr, p, delta, usr)
	if self:overlayRect():contains(p) then
		local dir = delta > 0 and -1 or 1
		local step = 3
		local pos = self:scrollPos() + (dir * step)
		self:setScrollPos(math.floor(pos + 0.5))
		return true
	end
end

---@param kbd string
---@param chr integer
---@param keycode integer
---@param usr string
---@return boolean
---@protected
function Dropdown:onKeyDown(kbd, chr, keycode, usr)
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

---@param scr string # screen Address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@return boolean # true to start drag
---@protected
function Dropdown:onBeginDrag(scr, p, btn, usr)
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
function Dropdown:onDrag(scr, p, delta, btn, usr)
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
function Dropdown:onDrop(scr, p, btn, usr)
	self.m_DragIndex = nil
	self.m_DragMode = -1
	self:invalidate()
end

---@param g Graphics
---@protected
function Dropdown:onDraw(g)
	Super.onDraw(self, g)

	local textRect = self:contentRect()
	local lText = self:label()
	local lMode = self:labelMode()
	if lMode == Enums.LabelMode.Prefix then
		local lRect, _ = g:drawLabel(
			textRect, lText,
			Enums.Alignment.Near, Enums.Alignment.Near, false, 0,
			Styles.Border.None, Styles.Decorator.None
		)
		textRect = Rect.new(lRect.right + 1, textRect.top, textRect:width() - lRect:width() - 1, textRect:height())
	end

	g:setColors(self:getColors(Enums.ColorKey.ControlForeground, Enums.ColorKey.ControlBackground))
	g:pushClip(textRect)
	g:clear()
	textRect = textRect:inflated(0, 0, -1, 0)
	if self.m_PopupOpen then
		g:setChar(textRect:tr(), Dropdown.__Arrow[2])
	else
		g:setChar(textRect:tr(), Dropdown.__Arrow[1])
	end
	local text = self:selectedText()
	if text ~= "" then
		g:drawString(textRect:tl(), text, false)
	end
	g:popClip()
end

---@param g Graphics
---@protected
function Dropdown:onDrawOverlay(g)
	if not self:focused() or self:itemCount() == 0 then
		return
	end

	local cRect = self:itemsRect()
	local cSize = self:itemCount()
	local vSize = cRect:height()

	g:setColors(self:getColors(self:popupBorderColor()))
	g:drawBorder(self:overlayRect(), self.m_PopupStyle)

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
			g, self:scrollRect(), thumbSize,
			fScroll, Enums.Direction4.Down,
			self:popupScrollStyle(),
			self:getColors(self:popupScrollColor())
		)
	end

	g:pushClip(self:itemsRect())
	local p = self:itemsRect():tl()
	local nItems = self:itemsRect():height()
	for i = 1, nItems do
		local idx = self:scrollPos() + i
		if idx == self:selectedIndex() then
			g:setColors(self:getColors(self:popupSelectedItemColor()))
		else
			g:setColors(self:getColors(self:popupItemColor()))
		end
		g:setRows(p.y, 1, ' ')
		g:drawString(p, self:getDisplayText(idx))
		p.y = p.y + 1
	end
	g:popClip()
end

--- Shows the dropdown
function Dropdown:showDropdown()
	if self.m_PopupOpen == true then return end
	self.m_PopupOpen = true
	self:setFocus()
	self:invalidateRects()

	self:invalidate()
end

--- Hides the dropdown
function Dropdown:hideDropdown()
	if self.m_PopupOpen == false then return end
	self:invalidate()

	self.m_PopupOpen = false
	self:releaseFocus()
	self:invalidateRects()
end

--- Sets the Scroll Top index
---@param index integer
function Dropdown:setScrollPos(index)
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
function Dropdown:scrollPos()
	return self.m_ScrollPos
end

---@param index integer
function Dropdown:scrollIntoView(index)
	Args.isInteger(1, index)

	local vp = self:itemsRect():height()
	local iMin = self:scrollPos() + 1
	local iMax = iMin + vp
	if index < iMin then
		self:setScrollPos(index - 1)
	elseif index > iMax then
		self:setScrollPos(index - vp)
	end
end

---@return Rect
function Dropdown:overlayRect()
	if self.m_PopupRect == nil then
		local contentRect = self:contentRect()
		local nItems = self:itemCount()
		if nItems ~= 0 and self.m_PopupOpen then
			local x0 = contentRect.left
			local y0 = contentRect.top

			local nVisible = math.min(self.m_PopupSize, nItems + 1)
			self.m_PopupRect = Rect.new(x0, y0 + 1, contentRect:width(), nVisible)
		else
			self.m_PopupRect = Rect.new(contentRect.left, contentRect.top, 0, 0)
			self.m_ItemsRect = self.m_PopupRect
			self.m_ScrollRect = self.m_PopupRect
		end
	end
	return self.m_PopupRect
end

function Dropdown:itemsRect()
	if self.m_ItemsRect == nil then
		local cRect = DrawHelper.getContentRectForBorder(self:overlayRect(), self.m_PopupStyle)
		local hasScroll = self:itemCount() > cRect:height()
		if hasScroll then
			self.m_ItemsRect = cRect:inflated(0, 0, -1, 0)
		else
			self.m_ItemsRect = cRect
		end
	end
	return self.m_ItemsRect
end

function Dropdown:scrollRect()
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

---@protected
function Dropdown:invalidateRects()
	Super.invalidateRects(self)
	self.m_PopupRect = nil
	self.m_ItemsRect = nil
	self.m_ScrollRect = nil
end

---@param style BorderStyle
---@param popupSize integer
function Dropdown:setPopupBorderStyle(style, popupSize)
	Args.isValue(1, style, Args.ValueType.Table)
	Args.isInteger(2, popupSize)

	self.m_PopupStyle = style
	self.m_PopupSize = popupSize
end

---@return BorderStyle
---@return integer
function Dropdown:popupBorderStyle()
	return self.m_PopupStyle, self.m_PopupSize
end

---@param fore Color
---@param back Color
function Dropdown:setPopupBorderColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupBorderForeground = fore
	self.m_PopupBorderBackground = back
end

---@return Color
---@return Color
function Dropdown:popupBorderColor()
	return self.m_PopupBorderForeground, self.m_PopupBorderBackground
end

---@param style TrackStyle
function Dropdown:setPopupScrollStyle(style)
	Args.isValue(1, style, Args.ValueType.Table)

	self.m_PopupScrollStyle = style
end

---@return TrackStyle
function Dropdown:popupScrollStyle()
	return self.m_PopupScrollStyle
end

---@param thumbFore Color
---@param thumbBack Color
---@param trackFore? Color # defaults to thumbFore
---@param trackBack? Color # defaults to thumbBack
function Dropdown:setPopupScrollColor(thumbFore, thumbBack, trackFore, trackBack)
	Args.isAnyValue(1, thumbFore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, thumbBack, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(3, trackFore, true, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(4, trackBack, true, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupScrollThumbForeground = thumbFore
	self.m_PopupScrollThumbBackground = thumbBack
	self.m_PopupScrollTrackForeground = trackFore or thumbFore
	self.m_PopupScrollTrackBackground = trackBack or thumbBack
end

---@return Color thumbFore
---@return Color thumbBack
---@return Color trackFore
---@return Color trackBack
function Dropdown:popupScrollColor()
	return self.m_PopupScrollThumbForeground, self.m_PopupScrollThumbBackground, self.m_PopupScrollTrackForeground,
		self.m_PopupScrollTrackBackground
end

---@param fore Color
---@param back Color
function Dropdown:setPopupItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupItemForeground = fore
	self.m_PopupItemBackground = back
end

---@return Color
---@return Color
function Dropdown:popupItemColor()
	return self.m_PopupItemForeground, self.m_PopupItemBackground
end

---@param fore Color
---@param back Color
function Dropdown:setPopupSelectedItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupSelectedItemForeground = fore
	self.m_PopupSelectedItemBackground = back
end

---@return Color
---@return Color
function Dropdown:popupSelectedItemColor()
	return self.m_PopupSelectedItemForeground, self.m_PopupSelectedItemBackground
end

return Dropdown
