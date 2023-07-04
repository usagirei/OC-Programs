local Class = require("libpack.class")
local StringView = require("libpack.stringview")

---@class TokenWriter
local Cls = Class.NewClass()

---@param indent? string
---@param pretty? boolean
---@return TokenWriter
function Cls.new(indent, pretty)
    return Class.NewObj(Cls, indent, pretty)
end

---@param indent? string
---@param pretty? boolean
function Cls:init(indent, pretty)
    self.m_Buffer = {}
    self.m_Depth = 0
    self.m_LineLen = 0
    self.m_IsNewLine = true
    self.m_LeadPad = false
    self.m_Pad = "n"
    self:setIndent(indent)
    self:setPretty(pretty)
end

---@param pretty? boolean
function Cls:setPretty(pretty) self.m_Pretty = pretty or false end

function Cls:pretty() return self.m_Pretty end

---@param indent? string
function Cls:setIndent(indent) self.m_Indent = indent or "\t" end

function Cls:indent() return self.m_Indent end

---@param token StringView|string
---@param trailPad "y"|"n"|"p"|"q"
---@param ignoreLead "y"|"n"|"p"|"q"
function Cls:token(token, trailPad, ignoreLead)
    local valueStr
    if type(token) == "string" then
        valueStr = token
    elseif Class.IsInstance(token, StringView) then
        valueStr = token:value()
    else
        error("expected a String or StringView")
    end

    if ignoreLead == "p" then
        if self.m_Pretty then self.m_Pad = false end
    elseif ignoreLead == "q" then
        if not self.m_Pretty then self.m_Pad = false end
    elseif ignoreLead == "y" then
        self.m_Pad = false
    else
        -- Ignore
    end

    if trailPad == "p" then
        trailPad = self.m_Pretty and "y" or "n"
    elseif trailPad == "q" then
        trailPad = self.m_Pretty and "n" or "y"
    end
    self:write(valueStr)
    self.m_Pad = (trailPad == "y")
    return self
end

function Cls:tailWs()
    local cur = self:current()
    local tailWs = cur:match("%s$")
    return tailWs ~= nil
end

---@private
---@return string
function Cls:current()
    return self.m_Buffer[#self.m_Buffer] or ''
end

---@param force? boolean
---@param noiIndent? boolean
function Cls:softLF(force, noiIndent)
    if self.m_IsNewLine and not force then return self end
    if self.m_Pretty or force then
        self.m_LeadPad = false
        self.m_Pad = false
        self:write('\n')
        self.m_NoIndent = noiIndent or false
    else
        --self.m_LeadPad = true
    end
    return self
end

---@param force? boolean
---@param noiIndent? boolean
function Cls:hardLF(force, noiIndent)
    if self.m_IsNewLine and not force then return self end
    if self.m_Pretty or force then
        self.m_LeadPad = false
        self.m_Pad = false
        self:write('\n')
        self.m_NoIndent = noiIndent or false
    else
        self.m_LeadPad = false
        self.m_Pad = false
        self:write(';')
    end
    return self
end

function Cls:_write(v, ...)
    if not v then return end
    if self.m_Pretty and self.m_LineLen > 120 and not self.m_IsNewLine then
        if self.m_Pretty then
            self.m_LineLen = 0
            self.m_IsNewLine = true
            self.m_Buffer[#self.m_Buffer + 1] = string.rep(self.m_Indent + 1, self.m_Depth)
        else
            self.m_LineLen = 0
            self.m_IsNewLine = true
            self.m_Buffer[#self.m_Buffer + 1] = '\n'
        end
    end
    if self.m_IsNewLine then
        if self.m_Pretty and not self.m_NoIndent and self.m_Depth > 0 then
            self.m_Buffer[#self.m_Buffer + 1] = string.rep(self.m_Indent, self.m_Depth)
            self.m_LineLen = self.m_Depth
        end
        self.m_NoIndent = false
        self.m_IsNewLine = false
    end
    if self.m_Pad and #self.m_Buffer > 0 and self.m_Buffer[#self.m_Buffer]:match("[%s;]$") == nil then
        self.m_Pad = false
        self:_write(' ')
    end
    self.m_Pad = false
    self.m_LineLen = self.m_LineLen + utf8.len(v)
    self.m_Buffer[#self.m_Buffer + 1] = v
    if self.m_Buffer[#self.m_Buffer]:match("\n$") then self.m_LineLen = 0 end
    if self.m_Pretty then
        if self.m_Buffer[#self.m_Buffer]:match("\n$") then
            self.m_IsNewLine = true
        end
    else
        if self.m_Buffer[#self.m_Buffer]:match(";$") then
            self.m_IsNewLine = true
        end
    end
    self._write(...)
end

---@param ... string
function Cls:write(...)
    self:_write(...)
    return self
end

function Cls:clear()
    self.m_Buffer = {}
    self.m_IsNewLine = true
    self.m_LineLen = 0
end

function Cls:pushIndent()
    self.m_Depth = self.m_Depth + 1
    return self
end

function Cls:popIndent()
    self.m_Depth = self.m_Depth - 1
    assert(self.m_Depth >= 0)
    return self
end

function Cls:tostring()
    return table.concat(self.m_Buffer)
end

return Cls
