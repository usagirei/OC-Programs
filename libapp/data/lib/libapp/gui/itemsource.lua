local Class = require("libapp.class")
local Sort = require("libapp.util.sort")
local Args = require("libapp.util.args")

---@class ItemsSource : Object
local ItemsSource = Class.NewClass(nil, "ItemSource")

---@return ItemsSource
---@param values? any[]
function ItemsSource.new(values) 
	return Class.NewObj(ItemsSource, values) 
end

---@param values? any[]
---@private
function ItemsSource:init(values)
	Args.isArray(1, values, true)

	self.m_ViewData = nil
	self.m_PredFunc = nil
	self.m_LessFunc = nil
	self.m_DataChangedCallbacks = {}
	if values then
		self:setData(values)
	end
end

---@param values any[]
function ItemsSource:setData(values)
	Args.isArray(1, values)

	self.m_Items = {}
	for i=1,#values do
		self.m_Items[#self.m_Items + 1] = values[i]
	end
	self:notifyDatasetChanged()
end

---@return any[]
function ItemsSource:data()
	if self.m_ViewData == nil then
		local data = {}
		for i = 1, #self.m_Items do
			local item = self.m_Items[i]
			if not self.m_PredFunc or self.m_PredFunc(item) then
				data[#data + 1] = item
			end
		end
		if self.m_LessFunc then
			data = Sort.stable_sort(data, self.m_LessFunc)
		end
		self.m_ViewData = data
	end
	return self.m_ViewData
end

---@return integer
function ItemsSource:count()
	return #self:data()
end

function ItemsSource:clear()
	self.m_Items = {}
	self:notifyDatasetChanged()
end

---@param predFn fun(a : any):boolean
function ItemsSource:setFilterFunc(predFn)
	Args.isValue(1, predFn, Args.ValueType.Function)

	self.m_PredFunc = predFn
	self:notifyDatasetChanged()
end

---@param lessFn fun(a : any, b: any):boolean
function ItemsSource:setSortFunc(lessFn)
	Args.isValue(1, lessFn, Args.ValueType.Function)

	self.m_LessFunc = lessFn
	self:notifyDatasetChanged()
end

---@param callback fun()
function ItemsSource:addItemsSourceChangedCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function)

	self.m_DataChangedCallbacks[callback] = true
end

---@param callback fun()
function ItemsSource:removeItemsSourceChangedCallback(callback)
	Args.isValue(1, callback, Args.ValueType.Function)

	self.m_DataChangedCallbacks[callback] = true
end

---@param self ItemsSource
function ItemsSource.prototype.__len(self)
	return self:count()
end

---@private
function ItemsSource:notifyDatasetChanged()
	self.m_ViewData = nil
	for k, v in pairs(self.m_DataChangedCallbacks) do
		k()
	end
end

return ItemsSource
