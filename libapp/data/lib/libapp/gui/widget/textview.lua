local keyboard = require("keyboard")

local Class = require("libapp.class")
local Graphics = require("libapp.gfx.graphics")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")
local Rect = require("libapp.struct.rect")
local Point = require("libapp.struct.point")
local DrawHelper = require("libapp.util.drawhelper")

local Super = require("libapp.gui.widget")
---@class TextView : Widget
local TextView = Class.NewClass(Super, "TextView")

---@param w integer
---@param h integer
---@return TextView
function TextView.new(w, h)
	return Class.NewObj(TextView, w, h)
end

---@param w integer
---@param h integer
---@private
function TextView:init(w, h)
	Super.init(self, w, h)
	self:setValue("")
	self:setWordWrap(false)
	self:setScrollStyle(Styles.Track.Shade)
	self:setScrollPos(Point.new(0, 0))

	self:setScrollStyle(Styles.Track.Shade)
	self:setScrollColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
end

---@param g Graphics
---@protected
function TextView:onDraw(g)
	Super.onDraw(self, g)

	local cRect = self:contentRect()
	local tRect = self:textRect()
	local vRect = self:viewRect()

	local hasHScroll = tRect:width() > cRect:width()
	local hasVScroll = tRect:height() > cRect:height()

	Graphics.debugPrint(tRect:width(), cRect:width())

	if hasHScroll then
		local sRect = self:scrollRectH()
		local sSize = sRect:width()
		local cSize = tRect:width()
		local vSize = self:viewRect():width()

		local thumbSize, _ = DrawHelper.calculateScrollParams(
			cSize,
			vSize,
			sSize
		)

		local overflow = cSize - vSize
		local fScroll = self.m_ScrollPos.x / overflow

		DrawHelper.trackbar(
			g, sRect, thumbSize,
			fScroll, Enums.Direction4.Right,
			self:scrollStyle(),
			self:getColors(self:scrollColor())
		)
	end

	if hasVScroll then
		local sRect = self:scrollRectV()
		local sSize = sRect:height()
		local cSize = tRect:height()
		local vSize = self:viewRect():height()

		local thumbSize, _ = DrawHelper.calculateScrollParams(
			cSize,
			vSize,
			sSize
		)

		local overflow = cSize - vSize
		local fScroll = self.m_ScrollPos.y / overflow

		DrawHelper.trackbar(
			g, sRect, thumbSize,
			fScroll, Enums.Direction4.Down,
			self:scrollStyle(),
			self:getColors(self:scrollColor())
		)
	end

	g:pushClip(self:viewRect())

	g:setColors(self:getColors(Enums.ColorKey.Foreground, Enums.ColorKey.Background))
	g:clear()
	local text = self:value()
	if text ~= "" then
		local prep = self:preparedText()
		local offsetViewRect = vRect:offset(-self:scrollPos())
		g:drawPreparedText(prep, offsetViewRect, -1, -1, false)
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
function TextView:onClick(scr, p, btn, times, usr, overlay)
	local rScrollH = self:scrollRectH()
	local rScrollV = self:scrollRectV()
	if rScrollH:contains(p) then
		local dx = p.x - rScrollH.left
		local sx = self:textRect():width()
		local overflow = sx - self:viewRect():width()
		local nx = math.floor((dx * overflow / rScrollH:width()) + 0.5)
		local oy = self:scrollPos().y
		self:setScrollPos(Point.new(nx, oy))
	elseif rScrollV:contains(p) then
		local dy = p.y - rScrollV.top
		local sy = self:textRect():height()
		local overflow = sy - self:viewRect():height()
		local ox = self:scrollPos().x
		local ny = math.floor((dy * overflow / rScrollV:height()) + 0.5)
		self:setScrollPos(Point.new(ox, ny))
	end
	return true
end

---@param scr string # screen address
---@param p Point # screen coordinates
---@param delta integer # scroll delta
---@param usr string # user
---@protected
function TextView:onScroll(scr, p, delta, usr)
	if self:mainRect():contains(p) then
		local dir = delta > 0 and -1 or 1
		local step = 3
		local oPos = self:scrollPos()
		local dPos
		if keyboard.isControlDown() then
			dPos = Point.new(math.floor(oPos.x + dir * step), oPos.y)
		else
			dPos = Point.new(oPos.x, math.floor(oPos.y + dir * step))
		end
		self:setScrollPos(dPos)
		return true
	end
end

---@param scr string # screen Address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@return boolean # true to start drag
---@protected
function TextView:onBeginDrag(scr, p, btn, usr)
	self.m_DragStart = self:scrollPos()
	if self:scrollRectV():contains(p) then
		self.m_DragMode = 0
		return true
	elseif self:scrollRectH():contains(p) then
		self.m_DragMode = 1
		return true
	elseif self:viewRect():contains(p) then
		self.m_DragMode = 2
		return true
	end
	return false
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@protected
function TextView:onDrag(scr, p, delta, btn, usr)
	if self.m_DragMode == 0 then
		local _, scrollStep = DrawHelper.calculateScrollParams(
			self:textRect():height(), self:viewRect():height(), self:scrollRectV():height()
		)
		local dy = delta.y * scrollStep
		local pos = self.m_DragStart.y + dy
		local ox = self:scrollPos().x
		local ny = math.floor(pos + 0.5)
		self:setScrollPos(Point.new(ox, ny))
	elseif self.m_DragMode == 1 then
		local _, scrollStep = DrawHelper.calculateScrollParams(
			self:textRect():width(), self:viewRect():width(), self:scrollRectH():width()
		)
		local dx = delta.x * scrollStep
		local pos = self.m_DragStart.x + dx
		local nx = math.floor(pos + 0.5)
		local oy = self:scrollPos().y
		self:setScrollPos(Point.new(nx, oy))
	elseif self.m_DragMode == 2 then
		local dx = -delta.x
		local dy = -delta.y

		local posX = self.m_DragStart.x + dx
		local posY = self.m_DragStart.y + dy
		local nx = math.floor(posX + 0.5)
		local ny = math.floor(posY + 0.5)
		self:setScrollPos(Point.new(nx, ny))
	end
end

function TextView:invalidateRects()
	Super.invalidateRects(self)
	self.m_ViewRect = nil
	self.m_ScrollRectH = nil
	self.m_ScrollRectV = nil
end

function TextView:setLayoutDirty()
	Super:setLayoutDirty()
	self.m_PreparedText = nil
end

---@private
function TextView:preparedText()
	if self.m_PreparedText == nil then
		if self:wordWrap() then
			local cRect = self:contentRect()
			self.m_PreparedText = Graphics:prepareText(self:value(), cRect:width() - 1)
		else
			self.m_PreparedText = Graphics:prepareText(self:value(), nil)
		end
	end
	return self.m_PreparedText
end

function TextView:textRect()
	return self:preparedText().textRect
end

--- Sets the Scroll Top index
---@param pos Point
function TextView:setScrollPos(pos)
	Args.isClass(1, pos, Point)

	local tRect = self:textRect()
	local vRect = self:viewRect()

	local oX = math.max(0, tRect:width() - vRect:width())
	local oY = math.max(0, tRect:height() - vRect:height())
	local nX = math.min(math.max(0, pos.x), oX)
	local nY = math.min(math.max(0, pos.y), oY)
	local newPos = Point.new(nX, nY)

	if newPos ~= self.m_ScrollPos then
		self.m_ScrollPos = newPos
		self:invalidate()
	end
end

function TextView:scrollIntoView(index)
	Args.isInteger(1, index)

	local vp = self:contentRect():height()
	local x = self:scrollPos().x
	local yMin = self:scrollPos().y + 1
	local yMax = yMin + vp
	if index < yMin then
		self:setScrollPos(Point.new(x, index))
	elseif index > yMax then
		self:setScrollPos(Point.new(x, index - vp))
	end
end

function TextView:scrollToBottom(index)
	Args.isInteger(1, index)

	local x = self:scrollPos().x
	self:setScrollPos(Point.new(x, self:textRect():height()))
end

---@return Point
function TextView:scrollPos()
	return self.m_ScrollPos
end

---@private
---@return Rect
function TextView:viewRect()
	if self.m_ViewRect == nil then
		local cRect = self:contentRect()
		local tRect = self:textRect()
		local hasHScroll = tRect:width() > cRect:width()
		local hasVScroll = tRect:height() > cRect:height()
		if hasVScroll and hasHScroll then
			self.m_ViewRect = cRect:inflated(0, 0, -1, -1)
		elseif hasHScroll then
			self.m_ViewRect = cRect:inflated(0, 0, 0, -1)
		elseif hasVScroll then
			self.m_ViewRect = cRect:inflated(0, 0, -1, 0)
		else
			self.m_ViewRect = cRect
		end
	end
	return self.m_ViewRect
end

---@private
---@return Rect
function TextView:scrollRectV()
	if self.m_ScrollRectV == nil then
		local cRect = self:contentRect()
		local tRect = self:textRect()
		local vRect = self:viewRect()
		local hasScroll = tRect:height() > cRect:height()
		self.m_ScrollRectV = Rect.new(vRect.right, vRect.top, hasScroll and 1 or 0, vRect:height())
	end
	return self.m_ScrollRectV
end

---@private
---@return Rect
function TextView:scrollRectH()
	if self.m_ScrollRectH == nil then
		local cRect = self:contentRect()
		local tRect = self:textRect()
		local vRect = self:viewRect()
		local hasScroll = tRect:width() > cRect:width()
		self.m_ScrollRectH = Rect.new(vRect.left, vRect.bottom, vRect:width(), hasScroll and 1 or 0)
	end
	return self.m_ScrollRectH
end

---@param thumbFore Color
---@param thumbBack Color
---@param trackFore? Color # defaults to thumbFore
---@param trackBack? Color # defaults to thumbBack
function TextView:setScrollColor(thumbFore, thumbBack, trackFore, trackBack)
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
function TextView:scrollColor()
	return self.m_ScrollThumbForeground, self.m_ScrollThumbBackground, self.m_ScrollTrackForeground,
		self.m_ScrollTrackBackground
end

---@param style TrackStyle
function TextView:setScrollStyle(style)
	Args.isValue(1, style, Args.ValueType.Table)

	self.m_ScrollStyle = style
end

---@return TrackStyle
function TextView:scrollStyle()
	return self.m_ScrollStyle
end

---@param enable boolean
function TextView:setWordWrap(enable)
	Args.isValue(1, enable, Args.ValueType.Boolean)

	if self.m_WordWrap == enable then
		return
	end

	self.m_WordWrap = enable
	self:invalidate()
end

---@return boolean
function TextView:wordWrap()
	return self.m_WordWrap
end

---@param text string|string[]
function TextView:setValue(text)
	Args.isValue(1, text, Args.ValueType.String)

	text = text or ""
	if type(text) == "string" then
		if self.m_Value == text then
			return
		end
	end

	self.m_Value = text
	self.m_PreparedText = nil
	Super.invalidate(self)
	self:invalidateLayout()
end

---@return string|string[]
function TextView:value()
	return self.m_Value
end

return TextView
