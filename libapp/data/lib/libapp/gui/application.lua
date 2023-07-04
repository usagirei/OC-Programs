local computer = require("computer")
local event = require("event")
local term = require("term")
local os = require("os")

local Class = require("libapp.class")

local Enums = require("libapp.enums")
local Graphics = require("libapp.gfx.graphics")
local Rect = require("libapp.struct.rect")
local Point = require("libapp.struct.point")
local PointF = require("libapp.struct.pointf")
local Styles = require("libapp.styles")
local EventHandler = require("libapp.util.eventhandler")
local Args = require("libapp.util.args")
local Window = require("libapp.gui.window")

local isArray = require("libapp.util.isarray")

---@alias CreateWindowDelegate fun(app:Application, root:Widget, ...):(fun():boolean)

---@class WindowData
---@field onCreate CreateWindowDelegate

---@class Application : Object
local Application = Class.NewClass(nil, "Application")

---@param ups? integer # Window Updates per Second
---@param fps? integer # Force refresh display per second
---@return Application
function Application.new(ups, fps)
	return Class.NewObj(Application, ups, fps)
end

---@param fps? integer
---@private
function Application:init(ups, fps)
	Args.isInteger(1, ups, true)
	Args.isInteger(2, fps, true)

	fps = fps or 1
	ups = ups or 1

	self.m_UpdateRate = ups
	self.m_RefreshRate = fps
	self.m_Timers = {}
	self.m_NextTimerId = 1

	self.m_Threads = {}

	self.m_CurrentWindow = nil
	---@type Window[]
	self.m_Windows = {}

	self.m_Running = false
	self.m_ExitCode = 0
	self.m_PreciseScreen = false
	---@type Widget[]
	self.m_Widgets = setmetatable({}, { __mode = 'v' })
end

---@param w Widget
---@return boolean
function Application:registerWidget(w)
	Args.isClass(1, w, "libapp.gui.widget")

	for i = 1, #self.m_Widgets do
		if self.m_Widgets[i] == w then
			return false
		end
	end
	local id = #self.m_Widgets + 1
	self.m_Widgets[id] = w
	return true
end

---@param w Widget
---@return boolean
function Application:unregisterWidget(w)
	Args.isClass(1, w, "libapp.gui.widget")

	for i = 1, #self.m_Widgets do
		if self.m_Widgets[i] == w then
			table.remove(self.m_Widgets, i)
			return true
		end
	end
	return false
end

function Application:invalidateLayout()
	self.m_LayoutDirty = true
end

function Application:layout()
	if self.m_LayoutDirty then
		self.m_LayoutDirty = false

		for i = 1, #self.m_Widgets do
			local w = self.m_Widgets[i]
			w:setLayoutDirty()
		end
	end
end

---@return fun(integer):Widget
function Application:widgets()
	local i = #self.m_Widgets
	local function iter()
		i = i - 1
		return self.m_Widgets[i]
	end
	return iter
end

---@param x number
---@param y number
---@return PointF
function Application:transformTouchPoint(x, y)
	Args.isValue(1, x, Args.ValueType.Number, false)
	Args.isValue(2, y, Args.ValueType.Number, false)

	if self.m_PreciseScreen then
		return PointF.new(x, y)
	else
		return PointF.new(x - 1, y - 1)
	end
end

---@param rect Rect
function Application:invalidateScreen(rect)
	Args.isClass(0, rect, Rect)

	self.m_Graphics:setDirtyRect(rect)
end

---@private
function Application:createEventHandler()
	local handler = EventHandler.new()

	function handler.interrupted()
		self:exit(-1)
		return true
	end

	---@param kbd string
	---@param chr integer
	---@param code integer
	---@param usr string
	function handler.key_down(kbd, chr, code, usr)
		self.m_RootWidget:event_key(true, kbd, chr, code, usr)
		return true
	end

	---@param kbd string
	---@param chr integer
	---@param code integer
	---@param usr string
	function handler.key_up(kbd, chr, code, usr)
		self.m_RootWidget:event_key(false, kbd, chr, code, usr)
		return true
	end

	---@param kbd string
	---@param str string
	---@param usr string
	function handler.clipboard(kbd, str, usr)
		self.m_RootWidget:event_clipboard(kbd, str, usr)
		return true
	end

	---@param scr string
	---@param x integer
	---@param y integer
	---@param btn integer
	---@param player string
	function handler.touch(scr, x, y, btn, player)
		local p = self:transformTouchPoint(x, y)
		local _ = self.m_RootWidget:event_touch_overlay(scr, p, btn, player) or
			self.m_RootWidget:event_touch(scr, p, btn, player)
		return true
	end

	---@param scr string
	---@param x integer
	---@param y integer
	---@param delta integer
	---@param player string
	function handler.scroll(scr, x, y, delta, player)
		local p = self:transformTouchPoint(x, y)
		self.m_RootWidget:event_scroll(scr, p, delta, player)
		return true
	end

	---@param scr string
	---@param x integer
	---@param y integer
	---@param btn integer
	---@param player string
	function handler.drag(scr, x, y, btn, player)
		local p = self:transformTouchPoint(x, y)
		self.m_RootWidget:event_dragdrop(true, scr, p, btn, player)
		return true
	end

	---@param scr string
	---@param x integer
	---@param y integer
	---@param btn integer
	---@param player string
	function handler.drop(scr, x, y, btn, player)
		local p = self:transformTouchPoint(x, y)
		self.m_RootWidget:event_dragdrop(false, scr, p, btn, player)
		return true
	end

	return handler

	---@private
end

---@private
---@param g Graphics
function Application.DrawErrorScreen(g, err, trace)
	g:setColors(0xffffff, 0x0000ff)
	g:resetClip()
	g:clear()

	local outer = g:area()
	local inner = outer:inflated(-1)

	g:drawBorder(outer, Styles.Border.Thin_DoubleTop)
	g:drawLabel(
		outer,
		"Application Error",
		Enums.Alignment.Center,
		Enums.Alignment.Near,
		false,
		1,
		Styles.Border.Thin_DoubleTop,
		Styles.Decorator.Double
	)

	local prep

	prep = g:prepareText(err, inner:width())
	g:drawPreparedText(prep, inner, Enums.Alignment.Near, Enums.Alignment.Near, false)
	inner.top = inner.top + #prep.lines

	g:drawSeparator(Point.new(outer.left, inner.top), outer:width(), Enums.Direction2.Horizontal,
		Styles.Separator.Single_Tee)
	inner.top = inner.top + 1

	prep = g:prepareText(trace, inner:width())
	g:drawPreparedText(prep, inner, Enums.Alignment.Near, Enums.Alignment.Near, false)
	inner.top = inner.top + #prep.lines

	g:setDirtyRect(nil)
	g:flush(true)
end

---@param wnd Window
---@private
function Application:_open(wnd)
	if self.m_CurrentWindow then
		self.m_CurrentWindow:onClosed()
		self.m_RootWidget:dispose()

		self.m_CurrentWindow = nil
		self.m_RootWidget = nil
	end

	if wnd then
		local root = wnd:inflate(self, self.m_Graphics:width(), self.m_Graphics:height())

		self.m_CurrentWindow = wnd
		self.m_RootWidget = root

		root:setApplication(self)
		wnd:onLoaded()
		self:invalidateLayout()
	end
end

---@param wnd Window
function Application:open(wnd)
	Args.isClass(1, wnd, Window, false)

	if self.m_CurrentWindow ~= nil and self.m_CurrentWindow:onClosing() == false then
		return false
	end

	self:createTimer(0, false, Application._open, self, wnd)
	return true
end

---@param id integer
function Application:cancelTimer(id)
	if self.m_Timers[id] == nil then return end
	self.m_Timers[id] = nil
end

---@param delay number # Initial Delay
---@param repeating boolean # Repeating
---@param fn function # Function
---@param ... any # Function Arguments
function Application:createTimer(delay, repeating, fn, ...)
	Args.isValue(1, fn, Args.ValueType.Function)

	local id = self.m_NextTimerId
	self.m_NextTimerId = self.m_NextTimerId + 1
	self.m_Timers[id] = {
		time = computer.uptime(),
		interval = delay,
		repeating = repeating,
		func = fn,
		args = table.pack(...)
	}
	return id
end

---@generic TResult
---@param fun fun():TResult
---@param onFinish? fun(result:TResult)
---@param onError? fun(err:string)
function Application:startCoroutine(fun, onFinish, onError)
	local thread = coroutine.create(fun)
	self.m_Threads[#self.m_Threads + 1] = {
		thread = thread,
		onFinish = onFinish,
		onError = onError,
		time = computer.uptime(),
	}
end

---@private
function Application:dispatchThreads()
	for i = #self.m_Threads, 1, -1 do
		local co = self.m_Threads[i]
		if co.time <= computer.uptime() then
			local ok, res = coroutine.resume(co.thread)
			local stat = coroutine.status(co.thread)
			if stat == "dead" then
				if ok then
					local _ = co.onFinish and co.onFinish(res)
				else
					local _ = co.onError and co.onError(res)
				end
				table.remove(self.m_Threads, i)
			elseif stat == "suspended" then
				if type(res) == "number" then
					co.time = computer.uptime() + res				
				end
			end
		end
	end
end

---@private
function Application:dispatchTimers()
	local now = computer.uptime()

	local delete = {}
	local didDelete = false
	for i, v in pairs(self.m_Timers) do
		local delta = now - v.time
		if delta >= v.interval then
			local rv = v.func(table.unpack(v.args))
			if not v.repeating or rv == false then
				delete[i] = true
				didDelete = true
			else
				v.time = now
			end
		end
	end

	if not didDelete then return end

	for i, t in pairs(delete) do
		if t then
			self.m_Timers[i] = nil
		end
	end
	if isArray(self.m_Timers) then
		self.m_NextTimerId = #self.m_Timers + 1
	end
end

---@param exitCode integer
function Application:exit(exitCode)
	Args.isInteger(1, exitCode, false)

	if self.m_CurrentWindow ~= nil and self.m_CurrentWindow:onClosing() == false then
		return
	end

	self.m_Running = false
	self.m_ExitCode = exitCode
end

---@param wnd Window
---@param ... any
function Application:run(wnd, ...)
	Args.isClass(1, wnd, Window, false)

	do
		local gfx = Graphics.new()
		local scr = gfx:screen()
		scr.setPrecise(true)

		self.m_Graphics = gfx
		self.m_Running = true
		self.m_PreciseScreen = scr.isPrecise()
	end

	local function runner()
		self:dispatchTimers()

		local lastDraw = 0
		local lastUpdate = 0
		local g = self.m_Graphics
		local refreshTime = (self.m_RefreshRate == 0) and math.huge or 1.0 / self.m_RefreshRate
		local updateTime = (self.m_UpdateRate == 0) and math.huge or 1.0 / self.m_UpdateRate
		local pumpTime = 1 / 20

		g:setColors(0xffffff, 0x000000)
		g:clear()

		local handler = self:createEventHandler()
		while self.m_Running do
			handler:pumpMessages(pumpTime)

			self:dispatchTimers()
			self:dispatchThreads()

			local root = self.m_RootWidget
			local curWnd = self.m_CurrentWindow
			local now = computer.uptime()

			if curWnd and root then
				local updateDelta = now - lastUpdate
				local doUpdate = updateDelta >= updateTime
				if doUpdate then
					curWnd:onUpdate(updateDelta)
					lastUpdate = now
				end

				local drawDelta = now - lastDraw
				local doRefresh = drawDelta >= refreshTime
				local dirtyRect = g:dirtyRect()
				if dirtyRect ~= nil or doRefresh then
					self:layout()
					root:beginDraw(g)
					root:draw(g)
					root:endDraw(g)

					g:flush(doRefresh)
					lastDraw = now
				end
			end
		end
	end

	local function onError(msg)
		self:exit(-1)
		return { msg, debug.traceback() }
	end

	self:open(wnd)
	local ok, err = xpcall(runner, onError)

	if not ok then
		local msg, trace = table.unpack(err --[[@as table]])
		self.DrawErrorScreen(self.m_Graphics, msg, trace)

		--computer.beep("-..")
		os.sleep(0.1)
		event.pull('key')
	end

	self.m_Graphics:setColors(0xffffff, 0x000000)
	self.m_Graphics:gpu().setActiveBuffer(0)

	if self.m_RootWidget then
		self.m_RootWidget:dispose()
	end
	self.m_Graphics:dispose()

	self.m_RootWidget = nil
	self.m_Graphics = nil
	self.m_Running = false

	term.clear()

	return self.m_ExitCode
end

return Application
