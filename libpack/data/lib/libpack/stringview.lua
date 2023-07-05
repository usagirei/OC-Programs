local class = require("libpack.class")

---@class StringView : Object
local StringView = class.NewClass()

---@param str? string
---@param i? integer
---@param j? integer
---@return StringView
function StringView.new(str, i, j)
    return class.NewObj(StringView, str, i ,j)
end

---@param str? string
---@param i? integer
---@param j? integer
function StringView:init(str, i, j)
    assert(str)
    i = i or 1
    j = j or #str
    if i < 0 then i = #str + i + 1 end
    if j < 0 then j = #str + i + 1 end
    assert(i & 0xFFFFFFFF == i)
    assert(j & 0xFFFFFFFF == j)
    self.m_Str = str
    self.m_Range = i | (j << 32)
end

---@return integer
function StringView:head()
    return (self.m_Range & 0xFFFFFFFF)
end

---@return integer
function StringView:tail()
    return (self.m_Range >> 32) & 0xFFFFFFFF
end

---@return string
function StringView:value()
    return self.m_Str:sub(self:head(), self:tail())
end

---@return integer
function StringView:len()
    return self:tail() - self:head() + 1
end

---@return string
function StringView:data()
    return self.m_Str
end

---@param i? integer
---@param j? integer
---@return ... integer
function StringView:byte(i, j)
    i, j = self:indexRelativeAbsolute(i, j)
    return self:data():byte(i, j)
end

---@param i? integer
---@param j? integer
function StringView:sub(i, j)
    i = i or 1
    j = j or #self

    i, j = self:indexRelativeAbsolute(i, j)
    if not i then return '' end

    return StringView.new(self.m_Str, i, j)
end

--- Index Relative to Absolute
function StringView:indexRelativeAbsolute(i, j)
    i = i or 1
    j = j or #self
    i = i - 1 + self:head()
    j = j - 1 + self:head()
    if i > self:tail() or i > j then return nil end
    if j < self:head() or j < i then return nil end
    i = math.min(math.max(self:head(), i), self:tail())
    j = math.min(math.max(self:head(), j), self:tail())
    return i, j
end

--- Index Absolute to Relative
function StringView:indexAbsoluteRelative(i, j)
    i = i or self:head()
    j = j or self:tail()
    i = i - self:head() + 1
    j = j - self:head() + 1
    if i > #self or i > j then return nil end
    if j < 1 or j < i then return nil end
    i = math.min(math.max(1, i), #self)
    j = math.min(math.max(1, j), #self)
    return i, j
end

StringView.Empty = StringView.new("", 1, 0)
StringView.prototype.__tostring = StringView.value
StringView.prototype.__len = StringView.len

---@param a StringView
---@param b StringView
StringView.prototype.__eq = function(a, b)
    if a:len() ~= b:len() then return false end
    for i = 1, #a do
        local iA = a:byte(i)
        local iB = b:byte(i)
        if iA ~= iB then return false end
    end
    return true
end

return StringView