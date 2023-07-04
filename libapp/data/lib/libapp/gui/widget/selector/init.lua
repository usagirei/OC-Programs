local Class = require("libapp.class")
local Args = require("libapp.util.args")
local ItemsSource = require("libapp.gui.itemsource")

local Super = require("libapp.gui.widget")
---@class Selector : Widget
local Selector = Class.NewClass(Super, "Selector")

---@param w integer
---@param h integer
function Selector:init(w, h)
	Super.init(self, w, h)

	self.m_SelectedIndex = 1
	self.m_DisplayPath = nil
	self.m_ValuePath = nil
	self.m_Items = {}

	self.m_SelectedItemChangingCallback = nil
	self.m_SelectedItemChangedCallback = nil

	self.m_SourceChangedCallback = function()
		self:setSelectedIndex(self:selectedIndex())

		if self.m_SelectedItemChangedCallback then
			local index = self:selectedIndex()
			local value = self:selectedValue()
			self.m_SelectedItemChangedCallback(index, value)
		end

		self:invalidate()
	end
end

---@param itemSource ItemsSource # items source
---@param displayPath? string # name of the key in the item table to use as display test, nil for the item itself
---@param valuePath? string # name of the key in the item table to use as callback value, nil for the item itself
---@see ItemsSource
function Selector:setItemsSource(itemSource, displayPath, valuePath)
	Args.isClass(1, itemSource, ItemsSource, true)
	Args.isValue(2, displayPath, Args.ValueType.String, true)
	Args.isValue(3, valuePath, Args.ValueType.String, true)

	self.m_DisplayPath = displayPath
	self.m_ValuePath = valuePath

	if self.m_ItemsSource ~= nil then
		self.m_ItemsSource:removeItemsSourceChangedCallback(self.m_SourceChangedCallback)
	end
	itemSource:addItemsSourceChangedCallback(self.m_SourceChangedCallback)
	self.m_ItemsSource = itemSource
end

---@return integer
function Selector:itemCount()
	if not self.m_ItemsSource then return 0 end
	return self.m_ItemsSource:count()
end

---@param index integer
---@return any item # item at index
function Selector:getItem(index)
	Args.isInteger(1, index)

	if not self.m_ItemsSource then return nil end
	local data = self.m_ItemsSource:data()
	return data[index]
end

--- Gets the display text of the item at index
---@param index integer
---@return string # display text of item at index
function Selector:getDisplayText(index)
	Args.isInteger(1, index)

	local item = self:getItem(index)
	if item == nil then return "" end

	if self.m_DisplayPath == nil or self.m_DisplayPath == "" then return tostring(item) end
	return tostring(item[self.m_DisplayPath])
end

--- Gets the value of the item at index
---@param index integer
---@return any item # value of item at index
function Selector:getValue(index)
	Args.isInteger(1, index)

	local item = self:getItem(index)
	if item == nil then return nil end

	if self.m_ValuePath == nil or self.m_ValuePath == "" then return item end
	return item[self.m_ValuePath]
end

--- Sets the current selected index
---@param index integer
function Selector:setSelectedIndex(index)
	Args.isInteger(1, index)

	index = math.min(math.max(1, index), self:itemCount())
	if index == self.m_SelectedIndex then return end

	local value = self:getValue(index)
	if not self.m_SelectedItemChangingCallback or self.m_SelectedItemChangingCallback(index, value) ~= false then
		self.m_SelectedIndex = index
		local _ = self.m_SelectedItemChangedCallback and self.m_SelectedItemChangedCallback(index, value)
		self:invalidate()
	end
end

--- Gets the index of the currently selected item
function Selector:selectedIndex()
	return self.m_SelectedIndex
end

--- Gets the value of the currently selected item
--- @return any
function Selector:selectedValue()
	return self:getValue(self.m_SelectedIndex)
end

--- Gets the display text of the currently selected item
function Selector:selectedText()
	return self:getDisplayText(self.m_SelectedIndex)
end

---@param callback? fun(index: integer, value: any) # Fired before the selected item is changed, receives the current index and value, return `false` to prevent changing
function Selector:setSelectedItemChangingCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_SelectedItemChangingCallback = callback
end

---@param callback? fun(index: integer, value: any) # Fired after the selected item is changed, receives the current index and value
function Selector:setSelectedItemChangedCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function, true)

	self.m_SelectedItemChangedCallback = callback
end

return Selector
