local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class ForStat : Stat
local Cls = Class.NewClass(Super, "ForStat")

---@param forIn boolean
---@return ForStat
function Cls.new(forIn)
    return Class.NewObj(Cls, forIn)
end

---@param forIn boolean
function Cls:init(forIn)
    Super.init(self)
    self.m_ForIn = forIn
    self.m_Scope = nil
end

---@param scope ForScope
function Cls:setInnerScope(scope)
    assert(scope ~= nil, "inner scope must not be nil")
    self.m_Scope = self:_setCheck(scope)
    return self
end

function Cls:isForIn() return self.m_ForIn end

function Cls:innerScope() return self.m_Scope end

function Cls:body() return self.m_Scope:statements() end

function Cls:stateVars() return self.m_Scope:stateVars() end

function Cls:initValues() return self.m_Scope:initValues() end

function Cls:validate()
    Super.validate(self)
    if not self.m_Scope then error("missing inner scope") end
    self.m_Scope:validate()
    local nIter = #self.m_Scope:stateVars()
    local nInit = #self.m_Scope:initValues()

    if nIter < 1 then error("missing iteration variables") end
    if nInit < 1 then error("missing init values") end

    if self.m_ForIn then
        -- TODO : Check how many
        --if nInit ~= 2 then error("for-in loop requires 2") end
    else
        if nIter ~= 1 then error("for loop only uses 1 iteration variable") end
        if not (nInit >= 2 and nInit <= 3) then error("for loop requires 2 or 3 init Values") end
    end

    return self
end

return Cls
