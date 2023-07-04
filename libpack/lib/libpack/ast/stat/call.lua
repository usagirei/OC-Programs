local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class CallStat : Stat
local Cls = Class.NewClass(Super, "CallStat")

---@return CallStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_Expr = nil
end

---@param expr CallExpr
function Cls:setCallExpr(expr)
    assert(expr ~= nil, "expr must not be nil")
    self.m_Expr = self:_setCheck(expr)
    return self
end

function Cls:callExpr() return self.m_Expr end

function Cls:validate()
    local AST = require("libpack.ast")

    if not self.m_Expr then error("call expr missing") end
    if not Class.IsInstance(self.m_Expr, AST.CallExpr) then error("invalid call expr") end

    self.m_Expr:validate()

    return self
end

return Cls
