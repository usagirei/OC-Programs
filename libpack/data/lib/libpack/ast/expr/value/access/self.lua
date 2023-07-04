local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value.access")
local TokenType = require("libpack.tokenizer.type")

-----------------------------------------------------------

---@class SelfAccessExpr : AccessExpr
local Cls = Class.NewClass(Super, "SelfAccessExpr")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Indexee = nil
    self.m_Index = nil
end

---@param index Token
function Cls:setIndex(index)
    assert(index ~= nil, "index must not be nil")
    self.m_Index = index
    return self
end

function Cls:index() return self.m_Index end

function Cls:validate()
    Super.validate(self)
    if not self.m_Index then error("missing index") end
    if not self.m_Index:isType(TokenType.Identifier) then error("invalid index") end
    
    return self
end

return Cls
