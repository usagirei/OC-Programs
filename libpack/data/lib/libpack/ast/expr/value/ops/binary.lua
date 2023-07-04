local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")
local Syntax = require("libpack.parser.syntax")

-----------------------------------------------------------

---@class BinaryExpr : ValueExpr
local Cls = Class.NewClass(Super, "binaryop")


function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Op = nil
    self.m_Lhs = nil
    self.m_Rhs = nil
end

---@param op Token
function Cls:setOperator(op)
    assert(op ~= nil, "operator must not be nil")
    self.m_Op = op
    return self
end

---@param lhs ValueExpr
function Cls:setLeftOperand(lhs)
    assert(lhs ~= nil, "left operand must not be nil")
    self.m_Lhs = self:_setCheck(lhs)
    return self
end

---@param rhs ValueExpr
function Cls:setRightOperand(rhs)
    assert(rhs ~= nil, "right operand must not be nil")
    self.m_Rhs = self:_setCheck(rhs)
    return self
end

function Cls:operator() return self.m_Op end

function Cls:leftOperand() return self.m_Lhs end

function Cls:rightOperand() return self.m_Rhs end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not Class.IsInstance(self.m_Lhs, AST.ValueExpr) then error("invalid left operand") end
    self.m_Lhs:validate()
    
    if not Class.IsInstance(self.m_Rhs, AST.ValueExpr) then error("invalid right operand") end
    self.m_Rhs:validate()

    local flag = false
    for i, j in pairs(Syntax.Operators) do
        local ub, _, v, _, _ = table.unpack(j)
        if ub == "b" and v == self.m_Op:value() then
            flag = true
            break
        end
    end
    if not flag then error("invalid operator") end

    return self
end

return Cls
