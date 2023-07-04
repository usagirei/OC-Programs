local Class = require("libpack.class")
local Super = require("libpack.ast.node")

-----------------------------------------------------------

---@class Scope : Node
local Cls = Class.NewClass(Super, "scope")

---@param isClosure boolean
---@return Scope
function Cls.new(isClosure)
    return Class.NewObj(Cls, isClosure)
end

---@param isClosure boolean
function Cls:init(isClosure)
    Super.init(self)
    self.m_IsClosure = isClosure
    self.m_Statements = nil
    self.m_Parent = nil
    ---@type Scope[]
    self.m_Children = {}

end

---@param stats Stat[]
function Cls:setStatements(stats)
    assert(stats ~= nil, "statements must not be nil")
    self.m_Statements = self:_setCheckArr(stats)
    return self
end

function Cls:isClosure() return self.m_IsClosure end

function Cls:statements() return self.m_Statements end

function Cls:validate()
    local AST = require("libpack.ast")
    Super.validate(self)

    --Super.validate(self)
    if not self.m_Statements then return end
    for i, j in pairs(self.m_Statements) do
        if not Class.IsInstance(j, AST.Stat) then error("invalid statement #" .. i) end
        j:validate()
    end
    for i, j in pairs(self.m_Children) do
        j:validate()
    end

    return self
end

return Cls
