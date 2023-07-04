local Class = require("libpack.class")
local Super = require("libpack.ast.scope")

-----------------------------------------------------------

---@class FuncScope : Scope
local Cls = Class.NewClass(Super, "scope-func")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, true)
    self.m_Args = nil
    self.m_VarArg = nil
end

---@param args ValueVarExpr[]
function Cls:setArgs(args)
    assert(args ~= nil, "args must not be nil")
    self.m_Args = self:_setCheckArr(args)
    return self
end

---@param varArgs ValueVarArgsExpr
function Cls:setVarArg(varArgs)
    assert(varArgs ~= nil, "varargs must not be nil")
    self.m_VarArg = self:_setCheck(varArgs)
    return self
end

function Cls:isVarArg() return self.m_VarArg ~= nil end

function Cls:args() return self.m_Args end

function Cls:varArg() return self.m_VarArg end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_Args then error("missing args") end
    for i, j in pairs(self.m_Args) do
        if not Class.IsInstance(j, AST.ValueVarExpr) then error("invalid arg #" .. i) end
        j:validate()
    end
    if self.m_VarArg then
        self.m_VarArg:validate()
    end

    return self
end

return Cls
