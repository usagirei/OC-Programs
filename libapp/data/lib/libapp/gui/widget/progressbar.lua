local unicode = require('unicode')

local Class = require("libapp.class")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local Text = require("libapp.util.text")
local DrawHelper = require("libapp.util.drawhelper")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget")
---@class ProgressBar : Widget
local ProgressBar = Class.NewClass(Super, "ProgressBar")
ProgressBar.m_Value = 0
ProgressBar.m_MinValue = 0
ProgressBar.m_MaxValue = 100

---@param w integer
---@param h integer
---@return ProgressBar
function ProgressBar.new(w, h) 
    return Class.NewObj(ProgressBar, w, h)
 end

---@param w integer
---@param h integer
---@private
function ProgressBar:init(w, h)
    Super.init(self, w, h)
    self:setValue(0)
    self:setRange(0, 100)
    self:setLabel("")
    self:setLabelMode(Enums.LabelMode.Default)
    self:setBorderStyle(Styles.Border.None, Styles.Decorator.None)
    self:setLabelAlignment(Enums.Alignment.Center, Enums.Alignment.Center, false)

    self:setFillDirection(Enums.Direction4.Right)
    self:setFillStyle(Styles.Progress.Solid)
    self:setProgressColor(Enums.ColorKey.AccentForeground, Enums.ColorKey.AccentBackground)
end

---@param value number # value
function ProgressBar:setValue(value)
    Args.isValue(1, value, Args.ValueType.Number)

    self.m_Value = math.min(math.max(self.m_MinValue, value), self.m_MaxValue)
    self:invalidate()
end

---@return number value
function ProgressBar:value()
    return self.m_Value
end

---@param min number # nil to keep current
---@param max number # nil to keep current
function ProgressBar:setRange(min, max)
    Args.isValue(1, min, Args.ValueType.Number)
    Args.isValue(2, max, Args.ValueType.Number)

    self.m_MinValue = min
    self.m_MaxValue = max
    self.m_Value = math.min(math.max(self.m_MinValue, self.m_Value), self.m_MaxValue)
    self:invalidate()
end

---@return number min
---@return number max
function ProgressBar:range()
    return self.m_MinValue, self.m_MaxValue
end

---@param g Graphics
---@protected
function ProgressBar:onDraw(g)
    Super.onDraw(self, g)

    local pFg, pBg = self:getColors(self:progressColor())
    local pStyle = self:fillStyle()
    local pFill = self:fillDirection()
    local fVal = (self.m_Value - self.m_MinValue) / (self.m_MaxValue - self.m_MinValue)
    local barArea = self:contentRect()
    local fillRect, _, _ = DrawHelper.progressbar(
        g, barArea, fVal,
        pFill, pStyle,
        pFg, pBg
    )


    local lblText = self:label()
    if lblText == "" then return end

    local lMode = self:labelMode()
    local bStyle, _ = self:borderStyle()
    local xAlign, yAlign, vertical = self:labelAlignment()

    if lMode == Enums.LabelMode.None then
        return
    elseif lMode == Enums.LabelMode.Default then
        local inFrame = DrawHelper.isLabelInsideBorder(bStyle, xAlign, yAlign, vertical)
        if not inFrame then
            g:pushClip(barArea)
            local l = unicode.len(lblText)
            local labelRect = DrawHelper.calculateLabelRect(barArea, nil, l, xAlign, yAlign, vertical, 0)
            local p = labelRect:tl()

            local cFg = self:getColors(Enums.ColorKey.ControlForeground)

            local txtArr = Text.toArray(lblText)
            for i = 1, #txtArr do
                if fillRect:contains(p) then
                    g:setColors(cFg, pFg)
                else
                    g:setColors(cFg, pBg)
                end
                g:setChar(p, txtArr[i])

                if vertical then
                    p.y = p.y + 1
                else
                    p.x = p.x + 1
                end
            end
            g:popClip()
        end
    end
end

---@param direction Direction4 # fill direction
function ProgressBar:setFillDirection(direction)
    Args.isEnum(1, direction, Enums.Direction4)

    self.m_FillDirection = direction
    self:invalidate()
end

---@return Direction4 style
function ProgressBar:fillDirection()
    return self.m_FillDirection
end

---@param style ProgressBarStyle # a string with 3+ characters, the first being padding, the last being fill, and the inbetweens used as an indicator of fractional progress
---@see ProgressBarStyle
function ProgressBar:setFillStyle(style)
    Args.isValue(1, style, Args.ValueType.Table)

    self.m_FillStyle = style
    self:invalidate()
end

---@return ProgressBarStyle style
function ProgressBar:fillStyle()
    return self.m_FillStyle
end

---@param fore Color
---@param back Color
function ProgressBar:setProgressColor(fore, back)
    Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
    Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

    self.m_ProgressForeground = fore
    self.m_ProgressBackground = back
end

---@return Color
---@return Color
function ProgressBar:progressColor()
    return self.m_ProgressForeground, self.m_ProgressBackground
end

return ProgressBar
