local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class BreakStat : Stat
local Cls = Class.NewClass(Super, "BreakStat")

---@return BreakStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_TargetScope = nil
end

function Cls:validate()
    -- TODO:

    return self
end

return Cls
