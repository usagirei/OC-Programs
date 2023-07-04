local Class = require("libpack.class")
local Super = require("libpack.ast.expr")

-----------------------------------------------------------

---@class ValueExpr : Expr
local Cls = Class.NewClass(Super, "value")


---@param isLvalue boolean
function Cls:init(isLvalue)
    Super.init(self)
    self.m_IsLValue = isLvalue
end

function Cls:isLValue() return self.m_IsLValue end

function Cls:validate()
    Super.validate(self)
    if self.m_IsLValue == nil then error("invalid isLValue value") end

    return self
end

return Cls
