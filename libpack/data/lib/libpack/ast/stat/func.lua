local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class FuncStat : Stat
local Cls = Class.NewClass(Super, "FuncStat")

---@return FuncStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_Name = nil
    self.m_InnerScope = nil
end

---@param scope FuncScope
function Cls:setInnerScope(scope)
    assert(scope ~= nil, "scope must not be nil")
    self.m_InnerScope = self:_setCheck(scope)
    return self
end

---@param name ValueVarExpr|AccessExpr
function Cls:setName(name)
    assert(name ~= nil, "name must not be nil")
    self.m_Name = self:_setCheck(name)
    return self
end

function Cls:name() return self.m_Name end

function Cls:innerScope() return self.m_InnerScope end

function Cls:isVarArg() return self.m_InnerScope:isVarArg() end
function Cls:varArg() return self.m_InnerScope:varArg() end

function Cls:args() return self.m_InnerScope:args() end

function Cls:body() return self.m_InnerScope:statements() end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_InnerScope then error("missing inner scope") end
    if not self.m_Name then error("missing name") end

    if Class.IsInstance(self.m_Name, AST.AccessExpr) then
        self.m_Name:validate()
    elseif Class.IsInstance(self.m_Name, AST.ValueVarExpr) then
        self.m_Name:validate()
    else
        error("invalid name")
    end

    self.m_InnerScope:validate()

    return self
end

return Cls
