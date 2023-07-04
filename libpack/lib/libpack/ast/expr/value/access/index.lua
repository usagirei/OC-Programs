local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value.access")

-----------------------------------------------------------

---@class IndexAccessExpr : AccessExpr
local Cls = Class.NewClass(Super, "access-index")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, true)
    self.m_Indexee = nil
    self.m_Index = nil
end

---@param index ValueExpr
function Cls:setIndex(index)
    assert(index ~= nil, "index must not be nil")
    self.m_Index = self:_setCheck(index)
    return self
end

function Cls:index() return self.m_Index end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_Index then error("missing index") end
    if not Class.IsInstance(self.m_Index, AST.Expr) then error("invalid index") end

    return self
end

return Cls
