local keyboard = require("keyboard")
local event = require("event")
local unicode = require("unicode")

local Class = require("libapp.class")
local Point = require("libapp.struct.point")
local Rect = require("libapp.struct.rect")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local DrawHelper = require("libapp.util.drawhelper")
local Args = require("libapp.util.args")

local Super = require("libapp.gui.widget")
---@class InputBox : Widget
local InputBox = Class.NewClass(Super, "InputBox")
InputBox.__TimerDelay = 0.5
InputBox.__StarCharacter = '●'

---@param w integer
---@param h integer
---@return InputBox
function InputBox.new(w, h)
	return Class.NewObj(InputBox, w, h)
end

---@param w integer
---@param h integer
---@private
function InputBox:init(w, h)
	Super.init(self, w, h)

	self.m_Buffer = {}
	self.m_SelStart = 0
	self.m_PassChar = InputBox.__StarCharacter
	self.m_PassMode = false

	self.m_AutoCompleteTable = {}
	self.m_AutoCompleteTimerId = nil
	self.m_AutoCompleteIndex = 1

	self:setAutoCompleteCallback(nil)
	self:setValueValidationCallback(nil)
	self:setValueChangedCallback(nil)

	self:setValue("")
	self:setLabel("")
	self:setLabelMode(Enums.LabelMode.Ghost)
	self:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Near, false)

	self:setPopupBorderStyle(Styles.Border.Popup_Solid, 5)
	self:setPopupBorderColor(Enums.ColorKey.ControlBackground, Enums.ColorKey.Background)
	self:setPopupItemColor(Enums.ColorKey.AccentBackground, Enums.ColorKey.ControlBackground)
	self:setPopupSelectedItemColor(Enums.ColorKey.ControlForeground, Enums.ColorKey.AccentBackground)

	self:setBorderStyle(Styles.Border.None, Styles.Decorator.None)
	self:setBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
end

--- Sets InputBox to Password-Mode (Hides characters)
---@param enable boolean
---@param starCharacter? string # Character to use as mask
function InputBox:setPasswordMode(enable, starCharacter)
	Args.isValue(1, enable, Args.ValueType.Boolean)
	Args.isValue(2, starCharacter, Args.ValueType.String, true)

	self.m_PassMode = enable
	self.m_PassChar = starCharacter or InputBox.__StarCharacter
end

---@param callback? fun(val:string):boolean|string # Fired before the text is changed, receives the current text, return `false` or a `string` with a validation message to prevent changing
function InputBox:setValueValidationCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_ValidateValueCallback = callback
end

---@param callback? fun(val:string) # Fired after the text is changed, receives the current text
function InputBox:setValueChangedCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_ValueChangedCallback = callback
end

---@param style BorderStyle
---@param popupSize integer
function InputBox:setPopupBorderStyle(style, popupSize)
	Args.isValue(1, style, Args.ValueType.Table)
	Args.isInteger(2, popupSize)

	self.m_PopupStyle = style
	self.m_PopupSize = popupSize
end

---@return BorderStyle
---@return integer
function InputBox:popupStyle()
	return self.m_PopupStyle, self.m_PopupSize
end

---@param fore Color
---@param back Color
function InputBox:setPopupBorderColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupBorderForeground = fore
	self.m_PopupBorderBackground = back
end

---@return Color
---@return Color
function InputBox:popupBorderColor()
	return self.m_PopupBorderForeground, self.m_PopupBorderBackground
end

---@param fore Color
---@param back Color
function InputBox:setPopupItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupItemForeground = fore
	self.m_PopupItemBackground = back
end

---@return Color
---@return Color
function InputBox:popupItemColor()
	return self.m_PopupItemForeground, self.m_PopupItemBackground
end

---@param fore Color
---@param back Color
function InputBox:setPopupSelectedItemColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_PopupSelectedItemForeground = fore
	self.m_PopupSelectedItemBackground = back
end

---@return Color
---@return Color
function InputBox:popupSelectedItemColor()
	return self.m_PopupSelectedItemForeground, self.m_PopupSelectedItemBackground
end

---@private
function InputBox:validateText(text)
	if self.m_PassMode then return true end

	local test = self.m_ValidateValueCallback and self.m_ValidateValueCallback(text)
	if test == false or type(test) == "string" then
		self.m_Error = type(test) == "string" and test or "Invalid input"
		return false
	else
		self.m_Error = nil
		return true
	end
end

---@param text string
function InputBox:setValue(text)
	Args.isAnyValue(1, text, false, Args.ValueType.String)

	if self.m_Value == text then
		return
	end

	if self:validateText(text) then
		self.m_Value = text
		if self:focused() then
			self:setBuffer(text)
		end
		local _ = self.m_ValueChangedCallback and self.m_ValueChangedCallback(text)
		self:invalidate()
	end
end

---@return string
function InputBox:value()
	return self.m_Value
end

---@private
function InputBox:setBuffer(text, moveCursor)
	text = text or ""
	local textLen = unicode.len(text)
	self.m_Buffer = {}
	for i = 1, textLen do
		self.m_Buffer[#self.m_Buffer + 1] = unicode.sub(text, i, i)
	end
	if moveCursor then
		self.m_SelStart = #self.m_Buffer
	else
		self.m_SelStart = math.min(#self.m_Buffer, self.m_SelStart)
	end
end

---@param list string[]
function InputBox.FilterList(list, text, max)
	local lText = string.lower(text)

	local filtered = {}
	for i = 1, #list do
		local ent = list[i]
		local lEnt = string.lower(list[i])
		local ok = lEnt ~= lText and string.find(lEnt, lText, 1) == 1
		if ok then
			local tLen = unicode.len(lText)
			local eLen = unicode.len(lEnt)
			local cEnt = unicode.sub(ent, tLen + 1, eLen)
			filtered[#filtered + 1] = cEnt
		end
		if #filtered == max then
			break
		end
	end

	return filtered
end

---@param callback? (fun(val:string, num:integer):table)|table # autocomplete items callback, table with values, or nil to disable
--- if `itemSource` is a function, it will be called with the current display text and how many entries it should return, and it should return a table with the autocomplete predictions
function InputBox:setAutoCompleteCallback(callback)
	Args.isAnyValue(1, callback, true, Args.ValueType.Function, Args.ValueType.Table)

	if type(callback) == "nil" then
		self.m_AutoCompleteCallback = nil
	elseif type(callback) == "function" then
		self.m_AutoCompleteCallback = callback
	elseif type(callback) == "table" then
		self.m_AutoCompleteCallback = function(text, count)
			return InputBox.FilterList(callback, text, count)
		end
	end
end

---@return Rect
function InputBox:overlayRect()
	if self.m_PopupRect == nil then
		local cRect = self:contentRect()

		local lMode = self:labelMode()
		if lMode == Enums.LabelMode.Prefix then
			local bs = self:borderStyle()
			local lt = self:label()
			local lRect, _ = DrawHelper.calculateLabelRect(cRect, bs, unicode.len(lt), -1, -1, false, 0)
			cRect = Rect.new(lRect.right + 1, cRect.top, cRect:width() - lRect:width() - 1, cRect:height())
		end

		local nPreds = #self.m_AutoCompleteTable
		if nPreds <= 1 then
			self.m_PopupRect = Rect.new(cRect.left, cRect.top, 0, 0)
		else
			local maxW = 0
			for i = 1, nPreds do
				maxW = math.max(maxW, unicode.len(self.m_AutoCompleteTable[i]))
			end

			local x0 = cRect.left + #self.m_Buffer
			local y0 = cRect.top

			self.m_PopupRect = Rect.new(x0, y0 + 1, maxW, nPreds)
			self.m_PopupRect = DrawHelper.getBorderRectForContent(self.m_PopupRect, self.m_PopupStyle)
		end
	end

	return self.m_PopupRect
end

---@private
function InputBox:acceptAutoComplete()
	if #self.m_AutoCompleteTable ~= 0 then
		local pred = self.m_AutoCompleteTable[self.m_AutoCompleteIndex]
		local pLen = unicode.len(pred)
		for i = 1, pLen do
			table.insert(self.m_Buffer, unicode.sub(pred, i, i))
		end
		self.m_SelStart = #self.m_Buffer
		self:setValue(table.concat(self.m_Buffer))
	end
	self:showAutocomplete(true)
	self:invalidate()
end

---@param cancelTimer boolean
---@private
function InputBox:clearAutocomplete(cancelTimer)
	if cancelTimer and self.m_AutoCompleteTimerId ~= nil then
		event.cancel(self.m_AutoCompleteTimerId)
		self.m_AutoCompleteTimerId = nil
	end
	if self.m_PopupRect and self.m_PopupRect:height() ~= 0 then
		self:invalidate()
		self:invalidateRects()
	end
	if #self.m_AutoCompleteTable ~= 0 then
		self.m_AutoCompleteTable = {}
	end
end

---@param immediate boolean # shows the dropdown instantly
---@private
function InputBox:showAutocomplete(immediate)
	self:clearAutocomplete(true)
	if self.m_PassMode then return end
	if not self.m_AutoCompleteCallback then return end

	local text = table.concat(self.m_Buffer)
	local function timerCallback()
		local _, u, _, d = DrawHelper.getBorderSizes(self.m_PopupStyle)
		local maxH = self.m_PopupSize - u - d

		local rv = self.m_AutoCompleteCallback(text, maxH) or {}
		if #rv > maxH then
			local clip = math.min(#rv, maxH)
			rv = { table.unpack(rv, 1, clip) }
		end
		self.m_AutoCompleteTable = rv
		self.m_AutoCompleteIndex = 1
		self:invalidateRects()
		self:invalidate()

		self.m_AutoCompleteTimerId = nil
		return false
	end

	if immediate == true then
		timerCallback()
	else
		self.m_AutoCompleteTimerId = event.timer(self.__TimerDelay, timerCallback)
	end
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
---@protected
function InputBox:onClick(scr, p, btn, times, usr, overlay)
	if btn == 1 then
		self:setBuffer("")
		self:setValue("")
		self:validateText("")
		self:clearAutocomplete(true)
		self:invalidate()
	end
	if self:focused() then
		if overlay then
			local rOver = self:overlayRect()
			local newIdx = math.floor(math.min(#self.m_AutoCompleteTable, math.max(0, p.y - rOver.top) + 1))
			if newIdx == self.m_AutoCompleteIndex and times >= 2 then
				self:acceptAutoComplete()
			elseif self.m_AutoCompleteIndex ~= newIdx then
				self.m_AutoCompleteIndex = newIdx
				self:invalidate()
			end
		else
			local rContent = self:contentRect()
			local newPos = math.floor(math.min(#self.m_Buffer, math.max(0, p.x - rContent.left)))
			if newPos == self.m_SelStart and times >= 2 then
				self:acceptAutoComplete()
			else
				self.m_SelStart = newPos
				self:invalidate()
			end
		end
	end
	return true
end

---@param g Graphics
---@protected
function InputBox:onBeginDraw(g)

end

---@param g Graphics
---@protected
function InputBox:onDraw(g)
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

	if self.m_Error ~= nil then
		g:setColors(self:getColors(Enums.ColorKey.ErrorForeground, Enums.ColorKey.ErrorBackground))
	else
		g:setColors(self:getColors(Enums.ColorKey.ControlForeground, Enums.ColorKey.ControlBackground))
	end

	g:pushClip(textRect)
	g:clear()
	local pCur = Point.new(textRect.left, textRect.top)
	if self:focused() then
		local pred = nil
		if #self.m_AutoCompleteTable ~= 0 then
			pred = self.m_AutoCompleteTable[self.m_AutoCompleteIndex]
		end
		for i = 1, #self.m_Buffer do
			local chr = self.m_PassMode and self.m_PassChar or self.m_Buffer[i]
			g:setChar(pCur, chr)
			pCur.x = pCur.x + 1
		end
		if pred ~= nil then
			pCur.x = pCur.x
			g:setColors(self:getColors(Enums.ColorKey.AccentForeground))
			g:drawString(pCur, pred, false, true)
		end
		local pSel = Point.new(textRect.left + self.m_SelStart, textRect.top)
		local cch, cbg, cfg = g:getChar(pSel)
		if cch ~= nil then
			g:setColors(cfg, cbg)
			g:setChar(pSel, cch)
		end
	else
		local text = self:value()
		if text ~= "" then
			if self.m_PassMode then
				for i = 1, unicode.len(text) do
					g:setChar(pCur, self.m_PassChar)
					pCur.x = pCur.x + 1
				end
			else
				g:drawString(pCur, text, false, true)
			end
		elseif lMode == Enums.LabelMode.Ghost then
			g:setColors(self:getColors(Enums.ColorKey.AccentForeground))
			g:drawString(pCur, lText, false)
		end
	end

	g:popClip()
end

---@param g Graphics
---@protected
function InputBox:onDrawOverlay(g)
	if not self:focused() or #self.m_AutoCompleteTable <= 1 then
		return
	end

	g:setColors(self:getColors(self:popupBorderColor()))
	g:drawBorder(self:overlayRect(), self.m_PopupStyle)
	local listRect = DrawHelper.getContentRectForBorder(self:overlayRect(), self.m_PopupStyle)

	g:pushClip(listRect)
	local p = Point.new(listRect.left, listRect.top)
	for i = 1, #self.m_AutoCompleteTable do
		if i == self.m_AutoCompleteIndex then
			g:setColors(self:getColors(self:popupSelectedItemColor()))
		else
			g:setColors(self:getColors(self:popupItemColor()))
		end
		g:setRows(math.floor(p.y + 0.5), 1, " ")
		g:drawString(p, self.m_AutoCompleteTable[i])
		p.y = p.y + 1
	end
	g:popClip()
end

---@protected
function InputBox:invalidateRects()
	Super.invalidateRects(self)
	self.m_PopupRect = nil
end

---@protected
function InputBox:onFocusGot()
	local text = self:value()
	self.m_Error = nil
	self:setBuffer(text, true)
	if text == nil or text == "" then
		self.m_SelStart = 0
	end
	self:showAutocomplete(true)
end

---@protected
function InputBox:onFocusLost()
	local txt = table.concat(self.m_Buffer)
	self:setValue(txt)
	self.m_Error = nil
	self.m_Buffer = {}
	self:clearAutocomplete(true)
end

---@param kbd string
---@param chr integer
---@param keycode integer
---@param user string
---@return boolean
---@protected
function InputBox:onKeyDown(kbd, chr, keycode, user)
	if not self:focused() then return false end

	local flag = false
	if keycode == keyboard.keys.back then
		table.remove(self.m_Buffer, self.m_SelStart)
		self.m_SelStart = self.m_SelStart - 1
		flag = true
	elseif keycode == keyboard.keys.delete then
		if (self.m_SelStart) < #self.m_Buffer then
			table.remove(self.m_Buffer, self.m_SelStart + 1)
			flag = true
		end
	elseif keycode == keyboard.keys['end'] then
		self.m_SelStart = #self.m_Buffer
	elseif keycode == keyboard.keys.home then
		self.m_SelStart = 0
	elseif keycode == keyboard.keys.left then
		self.m_SelStart = self.m_SelStart - 1
	elseif keycode == keyboard.keys.right then
		self.m_SelStart = self.m_SelStart + 1
	elseif keycode == keyboard.keys.enter then
		self:releaseFocus()
	elseif keycode == keyboard.keys.numpadenter then
		self:releaseFocus()
	elseif keycode == keyboard.keys.up then
		self.m_AutoCompleteIndex = self.m_AutoCompleteIndex - 1
	elseif keycode == keyboard.keys.down then
		self.m_AutoCompleteIndex = self.m_AutoCompleteIndex + 1
	elseif keycode == keyboard.keys.tab then
		self:acceptAutoComplete()
	elseif not keyboard.isControl(chr) then
		table.insert(self.m_Buffer, self.m_SelStart + 1, unicode.char(chr))
		self.m_SelStart = self.m_SelStart + 1
		flag = true
	end
	self.m_SelStart = math.min(#self.m_Buffer, math.max(0, self.m_SelStart))
	self.m_AutoCompleteIndex = math.min(#self.m_AutoCompleteTable, math.max(1, self.m_AutoCompleteIndex))
	if flag then
		local valid = self:validateText(table.concat(self.m_Buffer))
		if valid then
			self:showAutocomplete(false)
		else
			self:clearAutocomplete(true)
		end
	end

	self:invalidate()
	return true
end

return InputBox
