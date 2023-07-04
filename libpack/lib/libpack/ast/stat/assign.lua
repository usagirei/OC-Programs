local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class AssignStat : Stat
local Cls = Class.NewClass(Super, "AssignStat")

---@return AssignStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)

    self.m_LValues = nil
    self.m_RValues = nil
end

---@param lvalues ValueExpr[]
function Cls:setLValues(lvalues)
    assert(lvalues ~= nil, "lvalues must not be nil")
    self.m_LValues = self:_setCheckArr(lvalues)
    return self
end

---@param rvalues ValueExpr[]
function Cls:setRValues(rvalues)
    assert(rvalues ~= nil, "rvalues must not be nil")
    self.m_RValues = self:_setCheckArr(rvalues)
    return self
end

function Cls:lvalues() return self.m_LValues end

function Cls:rvalues() return self.m_RValues end

function Cls:validate()
    local AST = require("libpack.ast")
    
    if not self.m_LValues or #self.m_LValues == 0 then error("missing l-values") end
    if not self.m_RValues then error("missing r-values") end

    for i, j in pairs(self.m_LValues) do
        if not Class.IsInstance(j, AST.ValueExpr) and j:isLValue() then error("invalid l-value #" .. i) end
        j:validate()
    end

    for i, j in pairs(self.m_RValues) do
        if not Class.IsInstance(j, AST.ValueExpr) then error("invalid r-value #" .. i) end
        j:validate()
    end

    return self
end

return Cls
