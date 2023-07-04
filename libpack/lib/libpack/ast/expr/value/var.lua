local Class = require("libpack.class")
local Super = require("libpack.ast.expr.value")
local TOK = require("libpack.tokenizer.type")
local Token = require("libpack.tokenizer.token")

-----------------------------------------------------------

---@class ValueVarExpr : ValueExpr
local Cls = Class.NewClass(Super, "value-var")


function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, true)
    self.m_Value = nil
    self.m_IsDecl = nil
end

---@param isDecl boolean
function Cls:setDecl(isDecl)
    assert(isDecl ~= nil, "decl must not be nil")
    self.m_IsDecl = isDecl
    return self
end

---@param name Token
function Cls:setName(name)
    assert(name ~= nil, "name must not be nil")
    self.m_Value = name
    return self
end

function Cls:isDecl() return self.m_IsDecl end

function Cls:name() return self.m_Value end

function Cls:validate()
    Super.validate(self)
    if self.m_IsDecl == nil then error("missing isDecl flag") end
    if not Cls.IsValidIdentifier(self.m_Value) then error("invalid identifier name") end

    return self
end

---@param token Token
function Cls.IsValidIdentifier(token)
    if not token then return false end
    if not token:isType(TOK.Identifier) then return false end
    return Token.IsValidIdentifier(token:value())
end

return Cls
