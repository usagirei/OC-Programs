local libApp = require("libapp")
local Class = require("libapp.class")

local GUI = libApp.GUI
local Styles = libApp.Styles
local Enums = libApp.Enums

libApp.enableTypeChecks(true)
--

local Super = GUI.Window

---@class MainWindow : Window
local MainWindow = Class.NewClass(Super, "MainWindow")

function MainWindow:init()
	Super.init(self)

	self.text = ""
end

---@param app Application
---@param w integer
---@param h integer
---@return Widget
function MainWindow:inflate(app, w, h)
	local mainLyt = GUI.MainLayout.new(w, h)

	local mainGrid = GUI.GridLayout.new(0, 0)
	local togStack = GUI.StackLayout.new(0, 0)
	local topStack = GUI.StackLayout.new(0, 0)
	local progStack = GUI.StackLayout.new(0, 0)

	local lstView = GUI.ListView.new(0, 0)
	local textView = GUI.TextView.new(0, 0)
	local progGreen = GUI.ProgressBar.new(4, 0)
	local progRed = GUI.ProgressBar.new(4, 0)
	local dropdown = GUI.Dropdown.new(25, 3)
	local inputBox = GUI.InputBox.new(25, 3)
	local addButton = GUI.Button.new(10, 0)
	local removeButton = GUI.Button.new(10, 0)

	local items = GUI.ItemsSource.new()
	---@type string[]
	local q = {}

	progGreen:setBorderStyle(Styles.Border.SolidShadow, Styles.Decorator.SolidShadow)
	progGreen:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Far, true)
	progGreen:setFillDirection(Enums.Direction4.Down)
	progGreen:setLabel("Progresseee")

	progRed:setBorderStyle(Styles.Border.Solid, Styles.Decorator.Solid)
	progRed:setFillDirection(Enums.Direction4.Up)
	progRed:setLabelAlignment(Enums.Alignment.Far, Enums.Alignment.Far, true)
	progRed:setLabel("Heat")
	progRed:setTheme({
		accentForeground = 0xff0000,
		accentBackground = 0x7f0000
	})

	lstView:setLabel("ListBox")
	lstView:setItemsSource(items)

	progStack:setDirection(Enums.Direction2.Horizontal)
	progStack:setSizeMode(Enums.SizeMode.Automatic, Enums.SizeMode.Automatic)
	progStack:addChild(progGreen)
	progStack:addChild(progRed)

	textView:setWordWrap(true)
	textView:setBorderStyle(Styles.Border.Thin_DoubleTop, Styles.Decorator.Double)

	dropdown:setBorderStyle(Styles.Border.Round, Styles.Decorator.Cap)
	dropdown:setLabel("Dropdown")
	dropdown:setItemsSource(items)
	dropdown:setSelectedItemChangedCallback(
		function(i, v)
			mainLyt:setLabel(v)
		end
	)

	inputBox:setLabel("Input")
	inputBox:setValue(self.text)
	inputBox:setBorderStyle(Styles.Border.Thin, Styles.Decorator.Cap)
	inputBox:setPopupBorderStyle(Styles.Border.Popup_Round, 5)
	inputBox:setPopupBorderColor(Enums.ColorKey.Foreground, Enums.ColorKey.Background)
	inputBox:setAutoCompleteCallback({ "abcdef", "123456789", "abc123456", "abc12345", "abc1234" })
	inputBox:setValueChangedCallback(
		function(t)
			self.text = t
			mainLyt:setLabel(t)
		end
	)

	local n = 11
	addButton:setLabel("Add")
	addButton:setClickCallback(
		function(btn, times)
			local v = progGreen:value()
			progGreen:setValue(v + 1)
			progRed:setValue(v + 1)
			table.insert(q, lstView:selectedIndex() + 1, string.format("§%x⮊_§rItem %d§%x⮈§r", n % 16, n,
				15 - n % 16))
			items:setData(q)
			lstView:setSelectedIndex(lstView:selectedIndex() + 1)
			n = n + 1
		end
	)

	removeButton:setLabel("Remove")
	removeButton:setClickCallback(
		function(btn, times)
			local v = progGreen:value()
			progGreen:setValue(v - 1)
			progRed:setValue(v - 1)
			table.remove(q, lstView:selectedIndex())
			lstView:setSelectedIndex(lstView:selectedIndex() - 1)
			items:setData(q)
		end
	)

	topStack:setDirection(Enums.Direction2.Horizontal)
	topStack:setSizeMode(Enums.SizeMode.Automatic, Enums.SizeMode.Fixed)
	topStack:setSpacing(1)
	topStack:addChild(dropdown)
	topStack:addChild(inputBox)
	topStack:addChild(addButton)
	topStack:addChild(removeButton)

	togStack:setDirection(Enums.Direction2.Vertical)
	togStack:setBorderStyle(Styles.Border.Round, Styles.Decorator.Single)
	togStack:setLabelMode(Enums.LabelMode.Border)
	togStack:setLabelAlignment(Enums.Alignment.Center, Enums.Alignment.Near, false, 0)
	togStack:setLabel("Toggles")

	mainGrid:setRows(-3, 1, 1)
	mainGrid:setColumns(-20, 1)
	mainGrid:addChild(topStack, 0, 0, 2, 1)
	mainGrid:addChild(togStack, 0, 1)
	mainGrid:addChild(lstView, 0, 2)
	mainGrid:addChild(textView, 1, 1)
	mainGrid:addChild(progStack, 1, 2)
	mainGrid:setChildAlignment(progStack, Enums.Alignment.Center, Enums.Alignment.Center)

	mainLyt:setLabel("Window")
	mainLyt:setBorderStyle(Styles.Border.Round, Styles.Decorator.Cap)
	mainLyt:setLabelAlignment(Enums.Alignment.Center, Enums.Alignment.Near, false)
	mainLyt:addChild(mainGrid)
	mainLyt:setChildAlignment(mainGrid, Enums.Alignment.Center, Enums.Alignment.Center)

	local f = io.open("/usr/misc/greetings.txt", "r")
	if f then
		local qq = f:read("a")
		f:close()
		textView:setValue(qq)
	end

	for i = 1, 5 do
		local tog = GUI.CheckBox.new(13, 1)
		tog:setLabel("Toggle: %s")
		togStack:addChild(tog)
	end

	---@type string[]
	for i = 1, 10 do
		q[#q + 1] = string.format("§%x⮊_§rItem %d§%x⮈§r", i % 16, i, 15 - i % 16)
	end
	items:setData(q)

	return mainLyt
end

local app = GUI.Application.new(1, 0)
local mainWnd = MainWindow.new()
app:run(mainWnd)
