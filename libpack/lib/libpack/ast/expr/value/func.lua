local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")

-----------------------------------------------------------

---@class ValueFunc : ValueExpr
local Cls = Class.NewClass(Super, "ValueFunc")


---@return ValueFunc
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_InnerScope = nil
end

---@param scope FuncScope
function Cls:setInnerScope(scope)
    assert(scope ~= nil, "inner scope must not be nil")
    self.m_InnerScope = self:_setCheck(scope)
    return self
end

function Cls:innerScope() return self.m_InnerScope end

function Cls:isVarArg() return self.m_InnerScope:isVarArg() end

function Cls:varArg() return self.m_InnerScope:varArg() end

function Cls:args() return self.m_InnerScope:args() end

function Cls:body() return self.m_InnerScope:statements() end

function Cls:validate()
    Super.validate(self)
    if not self.m_InnerScope then error("missing inner scope") end
    self.m_InnerScope:validate()

    return self
end

return Cls
