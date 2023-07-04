local Class = require("libpack.class")
local Super = require("libpack.ast.stat")

-----------------------------------------------------------

---@class ReturnStat : Stat
local Cls = Class.NewClass(Super, "ReturnStat")

---@return ReturnStat
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self)
    self.m_RetVals = nil
end

---@param values ValueExpr[]
function Cls:setReturnValues(values)
    assert(values ~= nil, "return values must not be nil")
    self.m_RetVals = self:_setCheckArr(values)
    return self
end

function Cls:returnValues() return self.m_RetVals end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_RetVals then error("missing scope") end
    for i, j in pairs(self.m_RetVals) do
        if not Class.IsInstance(j, AST.ValueExpr) then error("invalid return value #" .. i) end
        j:validate()
    end

    return self
end

return Cls
