local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")
local TokenType = require("libpack.tokenizer.type")
local Syntax = require("libpack.parser.syntax")

-----------------------------------------------------------

---@class ValueConstExpr : ValueExpr
local Cls = Class.NewClass(Super, "value-const")

---@return ValueConstExpr
function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
end

---@param value Token
function Cls:setValue(value)
    assert(value ~= nil, "value must not be nil")
    self.m_Value = value
    return self
end

function Cls:token() return self.m_Value end

---@param token Token
function Cls.IsValidConstant(token)
    if token:isType(TokenType.String) then return true end
    if token:isType(TokenType.Number) then return true end
    if token:isType(TokenType.Keyword) then
        if token:value() == Syntax.Keywords.True then return true end
        if token:value() == Syntax.Keywords.False then return true end
        if token:value() == Syntax.Keywords.Nil then return true end
    end
    return false
end

function Cls:validate()
    Super.validate(self)
    if not Cls.IsValidConstant(self.m_Value) then
        error("invalid value token")
    end

    return self
end

return Cls
