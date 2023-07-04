local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")
local SYM = require("libpack.parser.syntax").Symbols

-----------------------------------------------------------

---@class ValueVarArgsExpr : ValueExpr
local Cls = Class.NewClass(Super, "value-varargs")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Token = nil
end

---@param token Token
function Cls:setToken(token)
    assert(token ~= nil, "token must not be nil")
    self.m_Token = token
    return self
end

function Cls:token() return self.m_Token end

function Cls:validate()
    Super.validate(self)
    if self.m_Token:value() ~= SYM.VarArg then error("invalid varargs token") end

    return self
end

return Cls
