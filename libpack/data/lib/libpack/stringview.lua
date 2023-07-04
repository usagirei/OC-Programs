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
    self:setData(str or "", i, j)
end

function StringView:freeze()
    if self.m_Frz then return end
    self.m_Val = self:value()
    self.m_Frz = true
    self:value()
    return self
end

function StringView:frozen()
    return self.m_Frz
end

---@return integer
function StringView:head()
    return self.m_Beg
end

---@return integer
function StringView:tail()
    return self.m_End
end

---@return string
function StringView:value()
    if self.m_Frz then
        return self.m_Val
    else
        return self.m_Str:sub(self.m_Beg, self.m_End)
    end
end

---@return integer
function StringView:len()
    return self.m_Len
end

---@param str string
---@param i? integer
---@param j? integer
function StringView:setData(str, i, j)
    assert(not self:frozen(), "stringview is frozen")

    i = i or 1
    j = j or #str
    if i < 0 then i = #str + i + 1 end
    if j < 0 then j = #str + i + 1 end
    self.m_Str = str
    self.m_Beg = i
    self.m_End = j
    self.m_Len = j - i + 1
    return self
end

---@return string
function StringView:data()
    return self.m_Str
end

---@param i? integer
---@param j? integer
---@return ... integer
function StringView:byte(i, j)
    i, j = self:ira(i, j)
    return self:data():byte(i, j)
end

---@param i? integer
---@param j? integer
function StringView:sub(i, j)
    i = i or 1
    j = j or #self

    i, j = self:ira(i, j)
    if not i then return '' end

    return StringView.new(self.m_Str, i, j)
end

--- Index Relative to Absolute
---@protected
function StringView:ira(i, j)
    i = i or 1
    j = j or #self
    i = i - 1 + self.m_Beg
    j = j - 1 + self.m_Beg
    if i > self.m_End or i > j then return nil end
    if j < self.m_Beg or j < i then return nil end
    i = math.min(math.max(self.m_Beg, i), self.m_End)
    j = math.min(math.max(self.m_Beg, j), self.m_End)
    return i, j
end

--- Index Absolute to Relative
---@protected
function StringView:iar(i, j)
    i = i or self.m_Beg
    j = j or self.m_End
    i = i - self.m_Beg + 1
    j = j - self.m_Beg + 1
    if i > #self or i > j then return nil end
    if j < 1 or j < i then return nil end
    i = math.min(math.max(1, i), #self)
    j = math.min(math.max(1, j), #self)
    return i, j
end

StringView.Empty = StringView.new("", 1, 0):freeze()
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