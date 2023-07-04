local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")

-----------------------------------------------------------

---@class CallExpr : ValueExpr
local Cls = Class.NewClass(Super, "call")


function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Callee = nil
    self.m_Args = nil
end

---@param callee ValueExpr
function Cls:setCallee(callee)
    assert(callee ~= nil, "callee must not be nil")
    self.m_Callee = self:_setCheck(callee)
    return self
end

---@param args ValueExpr[]
function Cls:setArgs(args)
    assert(args ~= nil, "args must not be nil")
    self.m_Args = self:_setCheckArr(args)
    return self
end

function Cls:callee() return self.m_Callee end

function Cls:args() return self.m_Args end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not Class.IsInstance(self.m_Callee, AST.ValueExpr) then error("invalid callee operand") end
    self.m_Callee:validate()

    if not self.m_Args then error("missing args") end
    for i, arg in pairs(self.m_Args) do
        if not Class.IsInstance(arg, AST.ValueExpr) then error("invalid arg #" .. i) end
        arg:validate()
    end

    return self
end

return Cls
