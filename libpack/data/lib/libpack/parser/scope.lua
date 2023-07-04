local Class = require("libpack.class")

-----------------------------------------------------------

---@class ScopeData
local ScopeData = Class.NewClass(nil,"ScopeData")

---@param id string
---@param closure boolean
---@param canBreak boolean
---@param start Token
function ScopeData.new(id, closure, canBreak, start)
    return Class.NewObj(ScopeData, id, closure, canBreak, start)
end

---@param id string
---@param closure boolean
---@param canBreak boolean
---@param start Token
function ScopeData:init(id, closure, canBreak, start)
    self.m_Id = id
    self.m_Closure = closure
    self.m_Start = start
    self.m_CanBreak = canBreak
end

function ScopeData:id() return self.m_Id end

function ScopeData:canBreak() return self.m_CanBreak end

function ScopeData:isClosure() return self.m_Closure end

function ScopeData:start() return self.m_Start end

return ScopeData