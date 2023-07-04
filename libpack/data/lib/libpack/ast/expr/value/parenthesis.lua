local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")

-----------------------------------------------------------

---@class ValueParenthesis : ValueExpr
local Cls = Class.NewClass(Super, "value-par")


---@return ValueParenthesis
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
end

---@param expr ValueExpr
function Cls:setValue(expr)
    assert(expr ~= nil, "expr must not be nil")
    self.m_Expr = self:_setCheck(expr)
    return self
end

function Cls:value() return self.m_Expr end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not Class.IsInstance(self.m_Expr, AST.Expr) then error("invalid expr") end

    return self
end

return Cls
