local Class = require("libpack.class")
local Super = require("libpack.ast.scope")

-----------------------------------------------------------

---@class ForScope : Scope
local Cls = Class.NewClass(Super, "scope-for")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, true)
    self.m_IterVars = nil
    self.m_InitValues = nil
end

---@param exprs ValueExpr[]
function Cls:setInitExprs(exprs)
    assert(exprs ~= nil, "init expr must not be nil")
    self.m_InitValues = self:_setCheckArr(exprs)
    return self
end

---@param vars ValueVarExpr[]
function Cls:setStateVars(vars)
    assert(vars ~= nil, "init expr must not be nil")
    self.m_IterVars = self:_setCheckArr(vars)
    return self
end

function Cls:stateVars() return self.m_IterVars end

function Cls:initValues() return self.m_InitValues end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_IterVars then error("missing iter vars") end
    if not self.m_InitValues then error("missing init values") end

    for i, j in pairs(self.m_IterVars) do
        if not Class.IsInstance(j, AST.ValueVarExpr) then error("invalid iter var #" .. i) end
        j:validate()
    end
    for i, j in pairs(self.m_InitValues) do
        if not Class.IsInstance(j, AST.ValueExpr) then error("invalid init expr #" .. i) end
        j:validate()
    end

    return self
end

return Cls
