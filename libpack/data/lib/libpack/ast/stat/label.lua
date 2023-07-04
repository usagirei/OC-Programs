local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class LabelStat : Stat
local Cls = Class.NewClass(Super, "LabelStat")

---@return LabelStat
function Cls.new()
    return Class.NewObj(Cls)
end

---@param label Token
function Cls:init(label)
    Super.init(self)
    self.m_Label = label
end

---@param label Token
function Cls:setLabel(label)
    assert(label ~= nil, "label must not be nil")
    self.m_Label = label
    return self
end

function Cls:label() return self.m_Label end

function Cls:validate()
    local Var = require("libpack.ast.expr.value.var")
    --Super:validat()

    if not self.m_Label then error("missing label") end
    if not Var.IsValidIdentifier(self.m_Label) then error("invalid label") end

    return self
end

return Cls
