local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class GotoStat : Stat
local Cls = Class.NewClass(Super, "GotoStat")

---@return GotoStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_Label = nil
    self.m_TargetScope = nil
end

---@param label Token
function Cls:setLabel(label)
    assert(label ~= nil, "label must not be nil")
    self.m_Label = label
    return self
end

function Cls:label() return self.m_Label end

function Cls:validate()
    local AST = require("libpack.ast")
    local Var = require("libpack.ast.expr.value.var")

    if not self.m_Label then error("missing label") end
    if not Var.IsValidIdentifier(self.m_Label) then error("invalid label") end

    return self
end

return Cls
