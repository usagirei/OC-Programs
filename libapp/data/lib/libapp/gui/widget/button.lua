local Class = require("libapp.class")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget")
---@class Button : Widget
local Button = Class.NewClass(Super, "Button")
Button.__TimerDelay = 4 / 20

---@param w integer
---@param h integer
---@return Button
function Button.new(w, h) 
	return Class.NewObj(Button, w, h) 
end

---@param w integer
---@param h integer
---@private
function Button:init(w, h)
	Super.init(self, w, h)
	self.m_ClickTimerId = nil

	self:setBorderStyle(Styles.Border.SolidShadow, Styles.Decorator.None, true)
	self:setBorderColor(Enums.ColorKey.ControlBackground, Enums.ColorKey.Background)
	self:setBorderColorClick(Enums.ColorKey.AccentBackground, Enums.ColorKey.Background)

	self:setLabelColor(Enums.ColorKey.ControlForeground, Enums.ColorKey.ControlBackground)
	self:setLabelColorClick(Enums.ColorKey.AccentForeground, Enums.ColorKey.AccentBackground)
end

---@param g Graphics
function Button:onDraw(g)
	local cFg, cBg = self:getColors(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	g:setColors(cFg, cBg)
	g:clear()

	local lFgKey, lBgKey, bFgKey, bBgKey
	if self:focused() then
		lFgKey, lBgKey = self:labelColorClick()
		bFgKey, bBgKey = self:borderColorClick()
	else
		lFgKey, lBgKey = self:labelColor()
		bFgKey, bBgKey = self:borderColor()
	end
	local lFg, lBg, bFg, bBg = self:getColors(lFgKey, lBgKey, bFgKey, bBgKey)

	local bStyle, _ = self:borderStyle()
	local mRect = self:mainRect()
	g:setColors(bFg, bBg)
	g:drawBorder(mRect, bStyle)

	local label = self:label()
	if label ~= "" then
		local cRect = self:contentRect()
		local xAlign, yAlign, vertical = self:labelAlignment()
		g:pushClip(cRect)
		g:setColors(lFg, lBg)
		g:clear()
		g:drawLabel(cRect, label,
			xAlign, yAlign, vertical, 0,
			Styles.Border.None, Styles.Border.None
		)
		g:popClip()
	end
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
---@protected
function Button:onClick(scr, p, btn, times, usr, overlay)
	local function timerCallback()
		self:releaseFocus()
		self:invalidate()
		self.m_ClickTimerId = nil
		return false
	end

	if self.m_ClickCallback then
		self.m_ClickCallback(btn, times)
	end
	self:invalidate()

	if self.m_ClickTimerId ~= nil then
		self:application():cancelTimer(self.m_ClickTimerId)
	end
	self.m_ClickTimerId = self:application():createTimer(Button.__TimerDelay, false, timerCallback)
	return true
end

---@param callback? fun(btn:integer,times:integer) # Called on click, receives the mouse button and number of times it was pressed
function Button:setClickCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_ClickCallback = callback
end

---@param fore Color
---@param back Color
function Button:setBorderColorClick(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_BorderForegroundClick = fore
	self.m_BorderBackgroundClick = back
end

---@return Color
---@return Color
function Button:borderColorClick()
	return self.m_BorderForegroundClick, self.m_BorderBackgroundClick
end

---@param fore Color
---@param back Color
function Button:setLabelColorClick(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_LabelForegroundClick = fore
	self.m_LabelBackgroundClick = back
end

---@return Color
---@return Color
function Button:labelColorClick()
	return self.m_LabelForegroundClick, self.m_LabelBackgroundClick
end

return Button
