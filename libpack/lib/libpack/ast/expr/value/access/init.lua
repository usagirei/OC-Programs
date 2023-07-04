local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")

-----------------------------------------------------------

---@class AccessExpr : ValueExpr
local Cls = Class.NewClass(Super, "AccessExpr")

---@param isLValue boolean
function Cls:init(isLValue)
    Super.init(self, isLValue)
end

---@param indexee ValueExpr
function Cls:setIndexee(indexee)
    assert(indexee ~= nil, "indexee must not be nil")
    self.m_Indexee = self:_setCheck(indexee)
    return self
end

function Cls:indexee() return self.m_Indexee end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_Indexee then error("missing indexee") end
    if not Class.IsInstance(self.m_Indexee, AST.ValueExpr) then error("invalid indexee") end

    return self
end

return Cls
