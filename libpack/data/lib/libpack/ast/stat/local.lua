local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class LocalStat : Stat
local Cls = Class.NewClass(Super, "LocalStat")

---@return LocalStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)

    self.m_Value = nil
end

---@param value AssignStat|FuncStat
function Cls:setStat(value)
    assert(value ~= nil, "value must not be nil")
    self.m_Value = self:_setCheck(value)
    return self
end

function Cls:stat() return self.m_Value end

function Cls:validate()
    local AST = require("libpack.ast")
    Super.validate(self)
    if not self.m_Value then error("missing value") end
    if Class.IsInstance(self.m_Value, AST.FuncStat) then
        local fn = self.m_Value --[[@as FuncStat]]
        if not Class.IsInstance(fn:name(), AST.ValueVarExpr) then
            error("invalid func name")
        end
    elseif Class.IsInstance(self.m_Value, AST.AssignStat) then
        -- OK
    else
        error("invalid value")
    end
    self.m_Value:validate()
    return self
end

return Cls
