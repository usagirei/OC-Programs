local Class = require("libpack.class")

---@class Switch : Object
local Cls = Class.NewClass(nil, "Switch")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    ---@type {class:Object,func:function}[]
    self.m_Cases = {}
    self.m_Else = nil
end

---@generic T : Object
---@param cls T
---@param func fun(obj:T, ...):any
function Cls:Case(cls, func)
    for i, j in pairs(self.m_Cases) do
        if Class.IsInstance(self[i], cls) then
            error("case already matched by case #" .. i)
        end
    end
    self.m_Cases[#self.m_Cases + 1] = { class = cls, func = func }
    return self
end

---@generic U
---@param func fun(obj:any, ...):any
function Cls:Else(func)
    self.m_Else = func
    return self
end

---@param o any
---@param ... any
---@return any
function Cls:Match(o, ...)
    if o then
        for i, j in ipairs(self.m_Cases) do
            if Class.IsInstance(o, j.class) then
                return j.func(o, ...)
            end
        end
    end
    if self.m_Else then
        return self.m_Else(o, ...)
    end
end

return Cls
