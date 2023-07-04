local event = require("event")
local computer = require("computer")

local Class = require("libapp.class")
local PointF = require("libapp.struct.pointf")
local Rect = require("libapp.struct.rect")
local Styles = require("libapp.styles")
local Enums = require("libapp.enums")
local DrawHelper = require("libapp.util.drawhelper")
local Args = require("libapp.util.args")

---@class Widget : Object
local Widget = Class.NewClass(nil, "Widget")

Widget.Theme = {
	foreground = 0xffffff,
	background = 0x000000,

	controlForeground = 0xffffff,
	controlBackground = 0x333333,

	accentForeground = 0x00FF00,
	accentBackground = 0x007f00,

	errorForeground = 0xff0000,
	errorBackground = 0x7f0000,
}

---

Widget.__doubleClickThreshold = 5 / 20
local function getFallbackTheme(_, key) return Widget.Theme[key] or 0xFF00FF end
Widget.m_Theme = setmetatable({}, { __index = getFallbackTheme })


---@param w integer
---@param h integer
function Widget:init(w, h)
	Args.isInteger(1, w)
	Args.isInteger(2, h)

	self.m_Focused = false
	self.m_DragPoint = nil
	self.m_NumClicks = 0
	self.m_LastButton = -1
	self.m_LastClick = computer.uptime()

	self:setZIndex(0)
	self:setParent(nil)
	self:setPreferedSize(w, h)
	self:setSizeMode(Enums.SizeMode.Fixed, Enums.SizeMode.Fixed)
	self:setZIndex(0)
	self:setVisible(true)
	self:setInteractive(true)
	self:invalidateRects()

	self:setBorderStyle(Styles.Border.None, Styles.Decorator.None, false)
	self:setBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)

	self:setLabel(Class.TypeName(self))
	self:setLabelMode(Enums.LabelMode.Default)
	self:setLabelAlignment(Enums.Alignment.Center, Enums.Alignment.Center, false)
	self:setLabelColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
end

function Widget:dispose()
	self:setParent(nil)
	self:setApplication(nil)
end

---@protected
function Widget:onFocusLost() end

---@protected
function Widget:onFocusGot() end

---@param scr string # screen Address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@return boolean # true to start drag
---@protected
function Widget:onBeginDrag(scr, p, btn, usr) return false end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@protected
function Widget:onDrag(scr, p, delta, btn, usr) end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param usr string # user
---@protected
function Widget:onDrop(scr, p, btn, usr) end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # mouse button
---@param times integer # number of clicks
---@param usr string # user
---@param overlay boolean # is overlay
---@protected
function Widget:onClick(scr, p, btn, times, usr, overlay) return true end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param delta integer # scroll delta
---@param usr string # user
---@protected
function Widget:onScroll(scr, p, delta, usr) return false end

---@param kbd string # keyboard address
---@param chr integer # character codepoint
---@param code integer # keycode
---@param usr string # user
---@protected
function Widget:onKeyDown(kbd, chr, code, usr) return false end

---@param kbd string # keyboard address
---@param chr integer # character codepoint
---@param code integer # keycode
---@param usr string # user
---@protected
function Widget:onKeyUp(kbd, chr, code, usr) return false end

---@param kbd string # keyboard address
---@param str string # pasted string
---@param usr string # user
---@protected
function Widget:onClipboard(kbd, str, usr) end

---@param g Graphics
---@protected
function Widget:onBeginDraw(g) end

---@param g Graphics
---@protected
function Widget:onDraw(g)
	g:setColors(self:getColors(Enums.ColorKey.Foreground, Enums.ColorKey.Background))
	g:clear()

	local bStyle, bDecor = self:borderStyle()
	local bRect = self:mainRect()
	g:setColors(self:getColors(self:borderColor()))
	g:drawBorder(bRect, bStyle)

	local lText = self:label()
	local lMode = self:labelMode()
	if lText ~= "" then
		local xAlign, yAlign, vertical, padding = self:labelAlignment()
		g:setColors(self:getColors(self:labelColor()))
		if lMode == Enums.LabelMode.Default then
			g:drawLabel(bRect, lText, xAlign, yAlign, vertical, padding, bStyle, bDecor)
		elseif lMode == Enums.LabelMode.Border and DrawHelper.isLabelInsideBorder(bStyle, xAlign, yAlign, vertical) then
			g:drawLabel(bRect, lText, xAlign, yAlign, vertical, padding, bStyle, bDecor)
		elseif lMode == Enums.LabelMode.Content then
			local cRect = self:contentRect()
			g:drawLabel(cRect, lText, xAlign, yAlign, vertical, padding, Styles.Border.None, Styles.Decorator.None)
		end
	end
end

---@param g Graphics
---@protected
function Widget:onDrawOverlay(g)

end

---@param g Graphics
---@protected
function Widget:onEndDraw(g)

end

---@param p PointF
---@param overlay boolean
function Widget:hitTest(p, overlay)
	if overlay then
		local rOver = self:overlayRect()
		return rOver and rOver:contains(p)
	else
		local rMain = self.m_BorderIsHit and self:mainRect() or self:contentRect()
		return rMain and rMain:contains(p)
	end
end

--- recalculates screen rect
---@protected
function Widget:invalidateRects()
	self.m_MainRect = nil
	self.m_ContentRect = nil
end

function Widget:setLayoutDirty()

end

---@return Rect # base screen rect
function Widget:mainRect()
	if self.m_MainRect == nil then
		if self:parent() then
			self.m_MainRect = self:parent():getChildRect(self)
		else
			local w, h = self:desiredSize()
			self.m_MainRect = Rect.new(0, 0, w, h)
		end
	end

	return self.m_MainRect
end

---@return Rect # main rect minus border, if present
function Widget:contentRect()
	if self.m_ContentRect == nil then
		local mainRect = self:mainRect()
		self.m_ContentRect = DrawHelper.getContentRectForBorder(mainRect, self:borderStyle())
	end

	return self.m_ContentRect
end

---@return Rect? # overlay screen rect
function Widget:overlayRect()
	return nil
end

---@return Rect # combined base and overlay screen rects
function Widget:screenRect()
	local rMain = self:mainRect()
	local rOver = self:overlayRect()
	if rOver ~= nil then
		return rMain + rOver
	else
		return rMain
	end
end

---@param g Graphics
function Widget:beginDraw(g)
	self:onBeginDraw(g)
end

---@param g Graphics
function Widget:draw(g)
	self:invalidateRects()

	local mRect = self:mainRect()
	g:pushClip(mRect)
	self:onDraw(g)
	g:popClip()
end

---@param g Graphics
function Widget:endDraw(g)
	self:onDrawOverlay(g)
	self:onEndDraw(g)
end

function Widget:invalidate()
	if self:application() then
		local before = self:screenRect()
		self:invalidateRects()
		local after = self:screenRect()
		self:application():invalidateScreen(before + after)
	end
end

function Widget:invalidateLayout()
	if self:application() then
		self:application():invalidateLayout()
	end
end

---@param colorTable table
function Widget:setTheme(colorTable)
	Args.isValue(1, colorTable, Args.ValueType.Table, true)

	if colorTable == nil then
		self.m_Theme = nil
	else
		self.m_Theme = setmetatable(colorTable, { __index = getFallbackTheme })
	end

	self:invalidate()
end

---@param ... Color # color keys
---@return integer ... # color values
function Widget:getColors(...)
	local args = table.pack(...)
	if args.n == 1 then
		return self.m_Theme[args[1]]
	else
		local cols = {}
		for i = 1, args.n do
			local arg = args[i]
			if type(arg) == Args.ValueType.String then
				cols[#cols + 1] = self.m_Theme[arg]
			elseif type(arg) == Args.ValueType.Number then
				cols[#cols + 1] = arg
			else
				error('invalid color', 3)
			end
		end
		return table.unpack(cols)
	end
end

---@return Application app
function Widget:application()
	return self.m_Application
end

---@param app? Application
function Widget:setApplication(app)
	Args.isClass(1, app, "libapp.gui.application", true)

	if self.m_Application then
		self.m_Application:unregisterWidget(self)
	end

	self.m_Application = app

	if app then
		app:registerWidget(self)
	end

	self:invalidateLayout()
end

---@param horizontal SizeMode
---@param vertical SizeMode
function Widget:setSizeMode(horizontal, vertical)
	Args.isEnum(1, horizontal, Enums.SizeMode)
	Args.isEnum(2, vertical, Enums.SizeMode)

	self.m_SizeMode = {
		x = horizontal,
		y = vertical
	}
	self:invalidateLayout()
end

---@return SizeMode x
---@return SizeMode y
function Widget:sizeMode()
	return self.m_SizeMode.x, self.m_SizeMode.y
end

---@return integer w
---@return integer h
function Widget:minimumSize()
	return self:preferedSize()
end

---@param prefW integer # Prefered Width
---@param prefH integer # Prefered Height
function Widget:setPreferedSize(prefW, prefH)
	Args.isInteger(1, prefW)
	Args.isInteger(2, prefH)

	self.m_Size = {
		width = prefW,
		height = prefH
	}

	if self:parent() then
		self:parent():invalidate()
	end
	self:invalidate()
	self:invalidateLayout()
end

---@return integer w
---@return integer h
function Widget:preferedSize()
	return self.m_Size.width, self.m_Size.height
end

---@return integer width
---@return integer height
function Widget:desiredSize()
	local sx, sy = self:sizeMode()
	local pW, pH = self:preferedSize()
	local mW, mH = self:minimumSize()

	local xx, yy
	if sx == Enums.SizeMode.Automatic then
		xx = mW
	elseif sx == Enums.SizeMode.Stretch then
		xx = 0
	else
		xx = pW
	end

	if sy == Enums.SizeMode.Automatic then
		yy = mH
	elseif sy == Enums.SizeMode.Stretch then
		yy = 0
	else
		yy = pH
	end

	return xx, yy
end

---@param z integer # Z Index
function Widget:setZIndex(z)
	Args.isInteger(1, z)

	if self.m_Z == z then return end

	self.m_Z = z
	if self:parent() then
		self:parent():invalidate()
	end
	self:invalidate()
	self:invalidateLayout()
end

function Widget:zIndex()
	return self.m_Z
end

---@param visible boolean
function Widget:setVisible(visible)
	Args.isValue(1, visible, Args.ValueType.Boolean)

	if not visible then
		self.m_LastTouchPoint = nil
	end

	self.m_Visible = visible
	if self:parent() then
		self:parent():invalidate()
		self:parent():invalidateLayout()
	end
	self:invalidate()
	self:invalidateLayout()
end

---@return boolean visible
function Widget:visible()
	return self.m_Visible
end

---@param interactive boolean
function Widget:setInteractive(interactive)
	Args.isValue(1, interactive, Args.ValueType.Boolean)

	self.m_Interactive = interactive
end

---@return boolean visible
function Widget:interactive()
	return self.m_Interactive
end

---@return string
function Widget:label()
	return self.m_LabelText
end

---@param label string
function Widget:setLabel(label)
	Args.isValue(1, label, Args.ValueType.String)

	if self.m_LabelText == label then
		return
	end
	self.m_LabelText = label
	self:invalidate()
	--self:invalidateLayout()
end

---@return LabelMode
function Widget:labelMode()
	return self.m_LabelMode
end

---@param mode LabelMode
---@see LabelMode
function Widget:setLabelMode(mode)
	Args.isEnum(1, mode, Enums.LabelMode)

	mode = mode or Enums.LabelMode.Default
	if mode == self.m_LabelMode then
		return
	end
	self.m_LabelMode = mode
	self:invalidate()
	--self:invalidateLayout()
end

---@param border BorderStyle
---@param decorator DecoratorStyle
---@param isHit? boolean # true if border is considered a hit test area for click detection, defaults to false
---@see BorderStyle
---@see LabelStyle
function Widget:setBorderStyle(border, decorator, isHit)
	Args.isValue(1, border, Args.ValueType.Table)
	Args.isValue(2, decorator, Args.ValueType.Table)
	Args.isValue(3, isHit, Args.ValueType.Boolean, true)

	isHit = isHit or false
	self.m_BorderStyle = border
	self.m_BorderDecor = decorator
	self.m_BorderIsHit = isHit

	self:invalidate()
	self:invalidateLayout()
end

---@return BorderStyle border
---@return DecoratorStyle decorator
function Widget:borderStyle()
	return self.m_BorderStyle, self.m_BorderDecor
end

---@param fore Color
---@param back Color
function Widget:setBorderColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_BorderForeground = fore
	self.m_BorderBackground = back

	self:invalidate()
end

---@return Color
---@return Color
function Widget:borderColor()
	return self.m_BorderForeground, self.m_BorderBackground
end

---@param fore Color
---@param back Color
function Widget:setLabelColor(fore, back)
	Args.isAnyValue(1, fore, false, Args.ValueType.String, Args.ValueType.Number)
	Args.isAnyValue(2, back, false, Args.ValueType.String, Args.ValueType.Number)

	self.m_LabelForeground = fore
	self.m_LabelBackground = back

	self:invalidate()
end

---@return Color
---@return Color
function Widget:labelColor()
	return self.m_LabelForeground, self.m_LabelBackground
end

---@param xAlign Alignment # Horizontal Alignment
---@param yAlign Alignment # Vertical Alignment
---@param vertical? boolean # Vertical Text, defaults to false
---@param padding? integer # Padding, defaults to 0
function Widget:setLabelAlignment(xAlign, yAlign, vertical, padding)
	Args.isEnum(1, xAlign, Enums.Alignment)
	Args.isEnum(2, yAlign, Enums.Alignment)
	Args.isValue(3, vertical, Args.ValueType.Boolean, true)
	Args.isInteger(4, padding, true)

	vertical = vertical or false
	padding = padding or 0
	self.m_LabelStyle = { xAlign, yAlign, vertical, padding }

	self:invalidate()
end

---@return Alignment xAlign # Horizontal Alignment
---@return Alignment yAlign # Vertical Alignment
---@return boolean vertical # Vertical Text
---@return integer padding # Padding
function Widget:labelAlignment()
	local x, y, v, p = table.unpack(self.m_LabelStyle)
	return x, y, v, p
end

---@param other Widget
---@protected
function Widget:occludes(other)
	if (self.m_Z <= other.m_Z) then return false end

	local oMain = other:mainRect()
	local rOver = self:overlayRect()
	local rMain = self:mainRect()

	return rMain:contains(oMain) or (rOver and rOver:contains(oMain))
end

---@param container? Container
function Widget:setParent(container)
	Args.isClass(1, container, "libapp.gui.widget.container", true)

	self.m_Parent = container

	self:invalidate()
	self:invalidateLayout()
end

---@return Container? parent
function Widget:parent()
	return self.m_Parent
end

---@return boolean
function Widget:focused()
	return self.m_Focused
end

---@return boolean
function Widget:isDragging()
	return self.m_DragPoint ~= nil
end

---@protected
---@return PointF?
function Widget:dragPoint()
	return self.m_DragPoint
end

function Widget:setFocus()
	if self.m_Focused then
		return
	end

	local function release_focus(msg, scr, x, y, btn, usr)
		local p = self:application():transformTouchPoint(x, y)
		local hit = self:hitTest(p, false) or self:hitTest(p, true)
		if not hit then
			self:releaseFocus()
			return false
		end
	end
	event.listen('touch', release_focus)

	for w in self:application():widgets() do
		if w ~= self and w.m_Focused then
			w.m_Focused = false
			w:onFocusLost()
			w:invalidate()
		end
	end
	self.m_Focused = true
	self:onFocusGot()
	self:invalidate()
end

function Widget:releaseFocus()
	if not self.m_Focused then
		return
	end

	self.m_Focused = false
	self:onFocusLost()
	self:invalidate()

	if self.m_DragPoint then
		self:onDrop("", PointF.new(-1, -1), 0, "")
		self.m_DragPoint = nil
	end
end

---@param kbd string # keyboard address
---@param string string # pasted string
---@param usr string # user
function Widget:event_clipboard(kbd, string, usr)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	return self:onClipboard(kbd, string, usr)
end

---@param down boolean # true if key is down
---@param kbd string # keyboard address
---@param chr integer # Character codepoint
---@param code integer # Keycode
---@param usr string # user
function Widget:event_key(down, kbd, chr, code, usr)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	local consumed
	if down then
		consumed = self:onKeyDown(kbd, chr, code, usr)
	else
		consumed = self:onKeyUp(kbd, chr, code, usr)
	end

	return consumed
end

---@param down boolean # true if is drag (button down), false if is drop (button up)
---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Widget:event_dragdrop(down, scr, p, btn, player)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	if not self:focused() then
		return false
	end

	if down then -- drag
		if not self.m_DragPoint then
			local start = self:onBeginDrag(scr, p, btn, player)
			if start then
				self.m_DragPoint = self.m_LastTouchPoint

				self:onDrag(scr, p, p - self.m_DragPoint, btn, player)
				return true
			end
		else
			self:onDrag(scr, p, p - self.m_DragPoint, btn, player)
			return true
		end
	else -- drop
		if self.m_DragPoint then
			self:onDrop(scr, p, btn, player)
			self.m_DragPoint = nil
			return true
		end
	end

	return false
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Widget:event_touch_overlay(scr, p, btn, player)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	self.m_LastTouchPoint = p

	local isHit = self:hitTest(p, true)
	if not isHit then
		return false
	end

	local curTime = computer.uptime()
	local deltaT = curTime - self.m_LastClick
	if deltaT < Widget.__doubleClickThreshold and self.m_LastButton == btn then
		self.m_NumClicks = self.m_NumClicks + 1
	else
		self.m_NumClicks = 1
		self.m_LastButton = btn
	end
	self.m_LastClick = curTime

	local wasFocused = self:focused()
	local consumed = self:onClick(scr, p, btn, self.m_NumClicks, player, true)
	if consumed == nil then
		return false
	elseif consumed == true then
		if not wasFocused then
			self:setFocus()
		end
		return true
	else
		return true
	end
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Widget:event_touch(scr, p, btn, player)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	self.m_LastTouchPoint = p

	local isHit = self:hitTest(p, false)
	if not isHit then return false end

	local curTime = computer.uptime()
	local deltaT = curTime - self.m_LastClick
	if deltaT < Widget.__doubleClickThreshold and self.m_LastButton == btn then
		self.m_NumClicks = self.m_NumClicks + 1
	else
		self.m_NumClicks = 1
		self.m_LastButton = btn
	end
	self.m_LastClick = curTime

	local wasFocused = self:focused()
	local consumed = self:onClick(scr, p, btn, self.m_NumClicks, player, false)
	if consumed and not wasFocused then
		self:setFocus()
	end

	return consumed
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param delta integer # scroll delta
---@param player string # user
function Widget:event_scroll(scr, p, delta, player)
	if not self:visible() then return false end
	if not self:interactive() then return false end

	return self:onScroll(scr, p, delta, player)
end

return Widget
