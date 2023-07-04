local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class IfStat : Stat
local Cls = Class.NewClass(Super, "IfStat")

---@return IfStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_IfScope = nil
    self.m_ElseIfScopes = nil
    self.m_ElseScope = nil
end

---@param scope CondScope
function Cls:setIfScope(scope)
    assert(scope ~= nil, "if scope must not be nil")
    self.m_IfScope = self:_setCheck(scope)
    return self
end

---@param scopes CondScope[]
function Cls:setElseIfScopes(scopes)
    assert(scopes ~= nil, "elseif scopes must not be nil")
    self.m_ElseIfScopes = self:_setCheckArr(scopes)
    return self
end

---@param scope Scope
function Cls:setElseScope(scope)
    assert(scope ~= nil, "else scope must not be nil")
    self.m_ElseScope = self:_setCheck(scope)
    return self
end

function Cls:hasElse() return self.m_ElseScope ~= nil end

function Cls:hasElseIf() return self.m_ElseIfScopes ~= nil end

function Cls:numElseIfCases() return self.m_ElseIfScopes and #self.m_ElseIfScopes or 0 end


function Cls:ifScope() return self.m_IfScope end
function Cls:elseIfScope(n) return self.m_ElseIfScopes[n] end
function Cls:elseIfScopes() return self.m_ElseIfScopes end
function Cls:elseScope() return self.m_ElseScope end

function Cls:ifCondition() return self.m_IfScope:condition() end
function Cls:elseIfCondition(n) return self.m_ElseIfScopes[n]:condition() end

function Cls:ifBody() return self.m_IfScope:statements() end
function Cls:elseIfBody(n) return self.m_ElseIfScopes[n]:statements() end
function Cls:elseBody() return self.m_ElseScope:statements() end

function Cls:validate()
    --Super.validate(self)

    local AST = require("libpack.ast")

    if not self.m_IfScope then error("missing if scope") end
    if not Class.IsInstance(self.m_IfScope, AST.CondScope) then error("invalid if scope") end
    self.m_IfScope:validate()

    if self.m_ElseScope then
        if not Class.IsInstance(self.m_ElseScope, AST.Scope, true) then error("invalid else scope") end
        self.m_ElseScope:validate()
    end

    if self.m_ElseIfScopes then
        for i, j in pairs(self.m_ElseIfScopes) do
            if not Class.IsInstance(j, AST.CondScope) then error("invalid elseif scope #" .. i) end
            j:validate()
        end
    end

    return self
end

return Cls
