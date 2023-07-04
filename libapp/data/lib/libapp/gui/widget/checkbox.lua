local Class = require("libapp.class")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget")
---@class CheckBox : Widget
local CheckBox = Class.NewClass(Super, "CheckBox")
CheckBox.__TimerDelay = 4 / 20

---@param w integer
---@param h integer
---@return CheckBox
function CheckBox.new(w, h) 
	return Class.NewObj(CheckBox, w, h) 
end

---@param w integer
---@param h integer
---@private
function CheckBox:init(w, h)
	Super.init(self, w, h)

	self:setBorderStyle(Styles.Border.None, Styles.Decorator.None)
	self:setBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	self:setLabelColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	self:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Near, false)
	self:setGroup(nil)
	self:setValue(false)

	self:setCheckStyle(Styles.CheckBox.Square, "On", "Off")
	self:setLabel("%s")
	self:setLabelMode(Enums.LabelMode.Content)
end

---@param g Graphics
function CheckBox:onDraw(g)
	Super.onDraw(self, g)

	local labelRect = self:contentRect()
	local gStyle, _, _ = self:toggleStyle()

	g:pushClip(labelRect)
	g:setColors(self:getColors(Enums.ColorKey.Foreground, Enums.ColorKey.Background))
	g:clear()

	local glyph = gStyle[self:value()]
	local gRect = g:drawString(labelRect:tl(), glyph, false, false)


	labelRect = labelRect:inflated(-gRect:width() - 1, 0, 0, 0)

	local lText = self:label()
	if lText ~= "" then
		local xAlign, yAlign, vertical = self:labelAlignment()

		g:drawLabel(labelRect, lText,
			xAlign, yAlign, vertical, 0,
			Styles.Border.None, Styles.Border.None
		)
	end
	g:popClip()
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
function CheckBox:onClick(scr, p, btn, times, usr, overlay)
	local cRect = self:contentRect()
	local lDist = p.x - cRect:x()
	if lDist < 1.5 then
		self:setValue(not self:value())
	elseif self.m_ClickCallback then
		self.m_ClickCallback(btn, times)
	end
end

---@return string
function CheckBox:label()
	local lab = Super.label(self)
	return string.format(lab, self.m_Value and self.m_ToggleOnStr or self.m_ToggleOffStr)
end

---@param callback? fun(a:any) # Fired after the value is changed, receives the current value
function CheckBox:setValueChangedCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_ValueChangedCallback = callback
end

---@param callback? fun(btn:integer,times:integer) # Called when the label part is clicked, receives the mouse button and number of times it was pressed
function CheckBox:setClickCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_ClickCallback = callback
end

---@param style ToggleStyle
---@param onText string
---@param offText string
function CheckBox:setCheckStyle(style, onText, offText)
	Args.isValue(1, style, Args.ValueType.Table)
	Args.isValue(2, onText, Args.ValueType.String)
	Args.isValue(3, offText, Args.ValueType.String)

	self.m_ToggleStyle = style
	self.m_ToggleOnStr = onText
	self.m_ToggleOffStr = offText
end

---@return ToggleStyle
---@return string
---@return string
function CheckBox:toggleStyle()
	return self.m_ToggleStyle, self.m_ToggleOnStr, self.m_ToggleOffStr
end

---@param group? CheckBox[]
function CheckBox:setGroup(group)
	Args.isValue(1, group, Args.ValueType.Table, true)

	self.m_ToggleGroup = group
end

---@return CheckBox[]? value
function CheckBox:group()
	return self.m_ToggleGroup
end

---@param value boolean
function CheckBox:setValue(value)
	Args.isValue(1, value, Args.ValueType.Boolean)

	if self.m_Value == value then
		return
	end

	if value then
		self.m_Value = true
		if self.m_ToggleGroup then
			for _, k in pairs(self.m_ToggleGroup) do
				if k ~= self then k:setValue(false) end
			end
		end
	else
		if self.m_ToggleGroup then
			local setCount = 0
			for _, k in pairs(self.m_ToggleGroup) do
				setCount = setCount + (k:value() and 1 or 0)
			end
			self.m_Value = setCount == 1
		else
			self.m_Value = false
		end
	end
	if self.m_ValueChangedCallback then
		self.m_ValueChangedCallback(self.m_Value)
	end
	self:invalidate()
end

---@return boolean value
function CheckBox:value()
	return self.m_Value
end

return CheckBox
