local Class = require("libpack.class")
local Tokenizer = require("libpack.tokenizer.reader")
local Solver = require("libpack.solver")
local ScopeData = require("libpack.parser.scope")
local Syntax = require("libpack.parser.syntax")
local Util = require("libpack.parser.util")
local Token = require("libpack.tokenizer.token")

local AST = require("libpack.ast")
local TOK = require("libpack.tokenizer.type")
local COM = Syntax.CommentRange
local STR = Syntax.StringRange
local SYM = Syntax.Symbols
local KWD = Syntax.Keywords
local OPS = Syntax.Operators

-----------------------------------------------------------

local random = math.random
local function uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-----------------------------------------------------------

---@class LuaParser : Object
local Cls = Class.NewClass()

---@return LuaParser
function Cls.new()
    return Class.NewObj(Cls)
end

---@protected
function Cls:init()
    local t = Tokenizer.new()
        :withString(table.unpack(STR))
        :withComments(table.unpack(COM))
        :withKeywords(KWD)
        :withSymbols(SYM)

    self.m_Tokenizer = t
    self.m_LastMatch = nil
    ---@type string[]
    self.m_ScopesStack = {}
    ---@type {[string]:ScopeData}
    self.m_ScopeData = {}
    ---@type Token[]
    self.m_Trivia = {}

    ---@param bin boolean
    ---@param op Token
    ---@param v1 ValueExpr
    ---@param v2 ValueExpr
    local function combine(bin, op, v1, v2)
        local rv
        if bin then
            assert(v1)
            assert(v2)
            rv = AST.BinaryExpr.new():setOperator(op):setLeftOperand(v1):setRightOperand(v2)
        else
            assert(v1)
            assert(not v2)
            rv = AST.UnaryExpr.new():setOperator(op):setOperand(v1)
        end
        self:setSourceInfo(rv, op)
        return rv
    end
    self.m_Solver = Solver.new(combine)
    for i, dat in pairs(OPS) do
        local bu, sk, op, pr, ra = table.unpack(dat)
        self.m_Solver:setOperator(bu == "b", op, pr, ra)
    end
end

function Cls:reader()
    return self.m_Tokenizer
end

---@param path string
---@return Chunk
function Cls:parseFile(path)
    local f = io.open(path)
    assert(f, "error loading file: " .. path)
    local chunkData = f:read("a")
    f:close()

    return self:parseChunk(chunkData)
end

---@param chunk string
function Cls:parseChunk(chunk)
    assert(not self.m_Busy, "parser already working on a chunk/file")
    self.m_Busy = true
    self:reader():setData(chunk)
    self.m_LastMatch = nil
    self.m_Tokenizer:next()
    local rv = Util.chunk(self)
    self.m_Busy = false
    return rv:validate()
end

-----------------------------------------------------------

---@private
---@return ScopeData
function Cls:scopeCreate(isClosure, canBreak, start)
    local id
    repeat id = uuid() until not self.m_ScopeData[id]
    local s = ScopeData.new(id, isClosure, canBreak, start)
    self.m_ScopeData[id] = s
    return s
end

---@param idOrLevel integer|string|nil
---@return ScopeData?
function Cls:scopeGet(idOrLevel)
    if type(idOrLevel) == "string" then
        return self.m_ScopeData[idOrLevel]
    elseif type(idOrLevel) == "nil" then
        return self.m_ScopeData[self.m_ScopesStack[#self.m_ScopesStack]]
    else
        local offset = (idOrLevel or 1) - 1
        local index = #self.m_ScopesStack - offset
        if index < 1 or index > #self.m_ScopesStack then return nil end
        local scopeId = self.m_ScopesStack[index]
        return self.m_ScopeData[scopeId]
    end
end

function Cls:scopeDepth() return #self.m_ScopesStack end

---@param isClosure boolean
---@param canBreak boolean
---@return string
function Cls:scopeBegin(isClosure, canBreak)
    local startToken = self:lastMatch() or self.m_Tokenizer:token()
    local newScope = self:scopeCreate(isClosure, canBreak, startToken)
    self.m_ScopesStack[#self.m_ScopesStack + 1] = newScope:id()
    return newScope:id()
end

---@param id string
---@param statements Stat[]
---@param scopeBuilder? fun(id:string, stats:Stat[], data:ScopeData, ...):Scope
function Cls:scopeEnd(id, statements, scopeBuilder, ...)
    local sId = self.m_ScopesStack[#self.m_ScopesStack]
    assert(id == sId, "end block id mismatch")
    self.m_ScopesStack[#self.m_ScopesStack] = nil

    local sData = self:scopeGet(id)
    assert(sData, "invalid scope")

    local sBlk
    if scopeBuilder then
        sBlk = scopeBuilder(id, statements, sData, ...)
        assert(Class.IsInstance(sBlk, AST.Scope))
    else
        sBlk = AST.Scope.new(sData:isClosure()):setStatements(statements)
    end
    self.m_ScopeData[id] = nil
    self:setSourceInfo(sBlk, sData:start())

    return sBlk
end

-----------------------------------------------------------

---@private
---@param match fun(token:Token):boolean
---@return boolean isMatch
---@return Token? token
function Cls:readToken(match)
    local tk = self.m_Tokenizer:token()
    if not tk then return false, nil end

    local tkType = tk:type(false, true)
    local isCom = (tkType & TOK.Comment == TOK.Comment)
    local isWs = (tkType & TOK.Whitespace == TOK.Whitespace)
    if isCom then
        self.m_Trivia[#self.m_Trivia + 1] = tk
        self.m_Tokenizer:next()
        return self:readToken(match)
    elseif isWs then
        self.m_Tokenizer:next()
        return self:readToken(match)
    else
        local isMatch = match(tk)
        if isMatch then
            self.m_Tokenizer:next()
        end
        return isMatch, tk
    end
end

---@private
---@param tValue? string
---@param tType TokenType
---@param optional? boolean
---@return boolean ok
---@return Token? token
function Cls:match(tValue, tType, optional)
    local pred = function(t)
        local valid = true
        if tType then valid = valid and (t:type() & tType == tType) end
        if tValue then valid = valid and (t:value() == tValue) end
        return valid
    end
    local ok, rv = self:readToken(pred)
    if not ok and not optional then
        local exType = TOK.name(tType)
        local exVal = tValue or ""
        local rvType = rv and rv:type(true, true) or "nil"
        local rvVal = rv and rv:value() or "nil"
        error(string.format("Expected [%s]'%s' - got [%s]'%s'", exType, exVal, rvType, rvVal))
    end
    if rv then
        self.m_LastMatch = rv
    end
    return ok, rv
end

-----------------------------------------------------------

---@return Token
function Cls:lastMatch()
    return self.m_LastMatch
end

---@param symb string
---@param optional? boolean
function Cls:symbol(symb, optional)
    local ok, rv = self:match(symb, TOK.Symbol, optional)
    if ok then return rv end
end

---@param kwd string
---@param optional? boolean
function Cls:keyword(kwd, optional)
    local ok, rv = self:match(kwd, TOK.Keyword, optional)
    if ok then return rv end
end

---@param optional? boolean
function Cls:number(optional)
    local ok, rv = self:match(nil, TOK.Number, optional)
    if ok then return rv end
end

---@param optional? boolean
function Cls:string(optional)
    local ok, rv = self:match(nil, TOK.String, optional)
    if ok then return rv end
end

---@param name? string
---@param optional? boolean
function Cls:identifier(name, optional)
    local ok, rv = self:match(name, TOK.Identifier, optional)
    if ok then return rv end
end

---@generic T : Node
---@param node T
---@param tkBegin Token
---@param tkEnd? Token
---@return T
function Cls:setSourceInfo(node, tkBegin, tkEnd)
    tkEnd = tkEnd or self:lastMatch()
    local a, b, c, _, _, _ = self.m_Tokenizer:getLineInfo(tkBegin)
    local _, _, _, d, e, f = self.m_Tokenizer:getLineInfo(tkEnd)
    ---@cast node Node
    node:setSourceInfo(a, b, c, d, e, f)
    return node
end

return Cls
