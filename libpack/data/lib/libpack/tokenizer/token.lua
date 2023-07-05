local Class = require("libpack.class")
local Super = require("libpack.stringview")
local TokenType = require("libpack.tokenizer.type")

---@class Token : StringView
local Cls = Class.NewClass(Super)
Cls.prototype.__tostring = Cls.value
Cls.prototype.__len = Cls.len

Cls.Type = TokenType

---@param t TokenType
---@param str string
---@param i? integer
---@param j? integer
---@return Token
function Cls.new(t, str, i, j)
    return Class.NewObj(Cls, t, str, i, j)
end

---@param token? Token
---@param type TokenType|integer
function Cls.withType(token, type)
    if not token then return nil end
    token:setType(type)
    return token
end

---@param t TokenType
---@param str string
---@param i? integer
---@param j? integer
function Cls:init(t, str, i, j)
    Super.init(self, str, i, j)
    self.m_Typ = t
    self.m_Val = nil
end

---@return TokenType|string
---@param friendly? boolean # true to return friendly name instead of numeric value
---@param typeOnly? boolean # true to exclude flags from the returned type
function Cls:type(friendly, typeOnly)
    local v = self.m_Typ
    if typeOnly then v = v & TokenType.TypeMask end
    if friendly then
        return TokenType.name(v)
    else
        return v
    end
end

---@param t TokenType
function Cls:isType(t)
    return (self.m_Typ & t) == t
end

---@param type TokenType
function Cls:setType(type)
    self.m_Typ = type
end

---@param a Token
---@param b Token
function Cls.prototype.__eq(a, b)
    local ok = true
    if getmetatable(b) == Cls.prototype then
        ok = a:type() == b:type()
    end
    return ok and Super.prototype.__eq(a, b)
end

---@param str string
function Cls.IsValidIdentifier(str)
    return str:find("^[%a_][%w_]*$") ~= nil
end

---@param str string
function Cls.IsValidNumber(str)
    local Syntax = require("libpack.parser.syntax")
    
    for pat, type in ipairs(Syntax.Numbers) do
        if string.find(str, pat) ~= nil then
            return true
        end
    end
    return false
end

---@param num string|number
function Cls.CreateNumber(num)
    local Syntax = require("libpack.parser.syntax")
    
    if type(num) == "number" then
        num = string.format("%f", num):gsub("%.?0+$", "")
    end
    for pat, type in ipairs(Syntax.Numbers) do
        if string.find(num, pat) ~= nil then
            return Cls.new(type, num)
        end
    end
    error("invalid number string")
end

---@param name string
function Cls.CreateIdentifier(name)
    assert(Cls.IsValidIdentifier(name), "invalid identifier")
    return Cls.new(TokenType.Identifier, name)
end

---@param value string
---@param raw? boolean
function Cls.CreateString(value, raw)
    local isMl = value:find("[^\\]\n", 1, true)
    if raw then
        if not isMl then
            local sq = value:sub(1, 1)
            local eq = value:sub(-1, -1)
            assert((sq == eq) and (sq == '"' or sq == "'"), "invalid string")
        else
            local open = value:match("^[(=*)[")
            local close = value:match("]" .. open .. "]$")
            assert(open and close, "invalid string")
        end
        return Cls.new(TokenType.String, value)
    end

    local hasSq = value:find("'", 1, true)
    local hasDq = value:find('"', 1, true)
    if isMl or (hasSq and hasDq) then
        local test = value:match("[(=*)[")
        if not test then
            return Cls.new(TokenType.String, "[[" .. value .. "]]")
        else
            -- TODO
            error()
        end
    elseif not hasSq and hasDq then
        return Cls.new(TokenType.String, "'" .. value .. "'")
    else
        return Cls.new(TokenType.String, "\"" .. value .. "\"")
    end
end

return Cls
