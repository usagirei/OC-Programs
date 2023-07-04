local Class = require("libpack.class")
local Super = require("libpack.ast.scope")

-----------------------------------------------------------

---@class CondScope : Scope
local Cls = Class.NewClass(Super, "CondScope")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, true)
    self.m_Condition = nil
end

---@param cond ValueExpr
function Cls:setCondition(cond) 
    assert(cond ~= nil, "condition must not be nil")
    self.m_Condition = self:_setCheck(cond)
    return self
end

function Cls:condition() return self.m_Condition end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not Class.IsInstance(self.m_Condition, AST.ValueExpr) then error("invalid condition") end
    self.m_Condition:validate()

    return self
end

return Cls