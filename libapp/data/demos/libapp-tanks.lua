local libApp = require("libapp")
local Class = require("libapp.class")

local GUI = libApp.GUI
local Styles = libApp.Styles
local Enums = libApp.Enums

libApp.enableTypeChecks(true)

local TankController = require("libapp.comp.tank_controller")
--

---@class TanksWindow : Window
local TanksWindow = Class.NewClass(GUI.Window, "Window")

function TanksWindow:init()
	GUI.Window.init(self)

	self.m_AllTanks = nil
	self.m_CurTanks = nil
end

---@return TankController[]
function TanksWindow:tanks()
	if self.m_AllTanks == nil then
		self.m_AllTanks = TankController.list()
	end
	return self.m_AllTanks
end

---@param app Application
---@param w integer
---@param h integer
function TanksWindow:inflate(app, w, h)
	local mainLyt = GUI.MainLayout.new(w, h)

	mainLyt:setLabel("Tanks")
	mainLyt:setBorderStyle(Styles.Border.Round, Styles.Decorator.Cap)
	mainLyt:setLabelAlignment(Enums.Alignment.Center, Enums.Alignment.Near, false)

	local grid = GUI.GridLayout.new(0,0)
	grid:setRows(1,-3)
	mainLyt:addChild(grid)

	local tankList = GUI.StackLayout.new(0, 0)
	tankList:setSizeMode(Enums.SizeMode.Automatic, Enums.SizeMode.Stretch)
	tankList:setDirection(Enums.Direction2.Vertical)
	grid:addChild(tankList, 0, 0)
	grid:setChildAlignment(tankList, Enums.Alignment.Near, Enums.Alignment.Near)

	do
		local bars = {}
		local tanks = self:tanks()
		for i = 1, #tanks do
			local pBar = GUI.ProgressBar.new(0, 4)
			pBar:setFillDirection(Enums.Direction4.Right)
			pBar:setBorderStyle(Styles.Border.Solid, Styles.Decorator.Solid)
			pBar:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Far, false)

			tankList:addChild(pBar)

			bars[i] = {
				bar = pBar,
				tank = tanks[i]
			}
		end
		self.m_CurTanks = bars
	end

	local toolbar = GUI.StackLayout.new(0,0)
	toolbar:setDirection(Enums.Direction2.Horizontal)
	toolbar:setSizeMode(Enums.SizeMode.Automatic, Enums.SizeMode.Automatic)
	grid:addChild(toolbar, 0, 1)
	grid:setChildAlignment(toolbar, Enums.Alignment.Far, Enums.Alignment.Center)

	local quit = GUI.Button.new(10,3)
	quit:setLabel("Quit")
	quit:setClickCallback(function() app:exit(0) end)
	toolbar:addChild(quit)

	return mainLyt
end

function TanksWindow:onClosed()
	self.m_AllTanks = nil
	self.m_CurTanks = nil
end

---@param elapsedTime number
function TanksWindow:onUpdate(elapsedTime)
	for _, v in pairs(self.m_CurTanks) do
		local bar = v.bar --[[@as ProgressBar]]
		local tc = v.tank --[[@as TankController]]

		local lvl = tc:level()
		local cap = tc:capacity()
		local nam = tc:fluidName()
		local lbl = string.format("%s %d%%", nam, math.floor(lvl * 100 / cap))

		bar:setRange(0, cap)
		bar:setValue(lvl)
		bar:setLabel(lbl)
	end
end

local app = GUI.Application.new()
local wnd = TanksWindow.new()
app:run(wnd)
