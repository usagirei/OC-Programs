local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")
local Syntax = require("libpack.parser.syntax")

-----------------------------------------------------------

---@class UnaryExpr : ValueExpr
local Cls = Class.NewClass(Super, "unaryop")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Op = nil
    self.m_Val = nil
end

---@param op Token
function Cls:setOperator(op)
    assert(op ~= nil, "operator must not be nil")
    self.m_Op = op
    return self
end

---@param val ValueExpr
function Cls:setOperand(val)
    assert(val ~= nil, "operand must not be nil")
    self.m_Val = self:_setCheck(val)
    return self
end

function Cls:operator() return self.m_Op end

function Cls:operand() return self.m_Val end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not Class.IsInstance(self.m_Val, AST.ValueExpr) then error("invalid operand") end
    self.m_Val:validate()

    local flag = false
    for i, j in pairs(Syntax.Operators) do
        local ub, _, v, _, _ = table.unpack(j)
        if ub == "u" and v == self.m_Op:value() then
            flag = true
            break
        end
    end
    if not flag then error("invalid operator") end

    return self
end

return Cls
