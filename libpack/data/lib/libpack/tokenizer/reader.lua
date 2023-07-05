local class = require("libpack.class")
local StringView = require("libpack.stringview")
local TokenType = require("libpack.tokenizer.type")
local Token = require("libpack.tokenizer.token")
local ARR = require("libpack.array")

-------------------

---@class TokenReader
local Cls = class.NewClass(nil, "TokenReader")

Cls.LF = StringView.new('\n')
Cls.CR = StringView.new('\r')
Cls.NUL = StringView.new('\0')
Cls.BS = StringView.new('\\')
-- "^$()%.[]*+-?" but escaped
Cls.PatternEscape = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

--- Returns a function that returns false (ignore the match) if the first character behind the token is the specified one
---@param esc string
---@return fun(token:Token):boolean
function Cls.RangeEscapeTest(esc)
    local escByte = esc:byte()
    ---@param token Token
    return function(token)
        local tokHead = token:data():byte(token:head() - 1)
        return tokHead ~= escByte
    end
end

---@param str? string
---@return TokenReader
function Cls.new(str)
    return class.NewObj(Cls, str or "")
end

---@param str string
function Cls:init(str)
    self:setData(str, 1, #str)
    self:createToken(1, 0, false, TokenType.Uknown)
    self:seek(0, "set")

    self:withString()
        :withComments()
        :withSymbols()
        :withKeywords()
end

---@private
function Cls:setupLocationInfo()
    local prev = 1
    local lines = {}
    while prev < #self.m_View do
        local i, j = self:data():find("^.-\n", prev, false)
        if not i then break end
        lines[#lines + 1] = { i, j }
        prev = j + 1
    end
    if prev ~= #self.m_View then
        lines[#lines + 1] = { prev, #self }
    end
    self.m_LineInfo = lines
end

function Cls:data()
    return self.m_View:data()
end

function Cls:setData(str, i, j)
    self.m_View = StringView.new(str, i, j)
    self:createToken(1, 0, false, TokenType.Uknown)
    self:seek(0, "set")
    self:setupLocationInfo()
end

---@param str string
function Cls:withSource(str)
    self:setData(str, 1, #str)
    return self
end

---@class RangeData : table
---@field multiline boolean # `true` for multi-line (Ignores LF), `false` for single-line (Errors at LF, escape with `cEnd`)
---@field head string # begin pattern
---@field tail string|fun(token:Token):string # a string or function that takes the matched head token, returns the end pattern
---@field test (fun(token:Token):boolean)? # optional function that takes the matched tail token, returns true to accept - false otherwise

---@param ... RangeData
function Cls:withComments(...)
    ---@type RangeData[]
    local tbl = { ... }
    for _, r in pairs(tbl) do
        assert(type(r.head) == "string", r.head and "invalid begin pattern" or "missing begin pattern")
    end
    self.m_Comment = tbl
    return self
end

---@param ... RangeData
function Cls:withString(...)
    ---@type RangeData[]
    local tbl = { ... }
    for _, r in pairs(tbl) do
        assert(type(r.head) == "string", r.head and "invalid begin pattern" or "missing begin pattern")
    end
    self.m_String = tbl
    return self
end

---@param symbols? string|string[]
function Cls:withSymbols(symbols)
    if type(symbols) == "string" then
        local tbl = {}
        if symbols then
            for s in symbols:gmatch("%S+") do
                tbl[#tbl + 1] = s
            end
        end
        self.m_Symbols = tbl
    elseif type(symbols) == "table" then
        local tbl = {}
        for _, v in pairs(symbols) do
            tbl[#tbl + 1] = v
        end
        self.m_Symbols = tbl
    else
        self.m_Symbols = {}
    end
    table.sort(self.m_Symbols, function(a, b) return #a > #b end)
    for i, s in ipairs(self.m_Symbols) do
        self.m_Symbols[i] = s:gsub(Cls.PatternEscape, '%%%1')
    end
    return self
end

---@param keywords? string|string[]
function Cls:withKeywords(keywords)
    if type(keywords) == "string" then
        local tbl = {}
        if keywords then
            for s in keywords:gmatch("%S+") do
                tbl[s] = true
            end
        end
        self.m_Keywords = tbl
    elseif type(keywords) == "table" then
        local tbl = {}
        for _, v in pairs(keywords) do
            tbl[v] = true
        end
        self.m_Keywords = tbl
    else
        self.m_Keywords = {}
    end
    return self
end

--- Last Matched Token
---@return Token
function Cls:token()
    return self.m_Tok
end

function Cls:emptyToken()
    return self:createToken(1, 0, true, TokenType.Invalid)
end

--- End of File
---@return boolean
function Cls:eof()
    return self.m_Pos > #self.m_View
end

--- Set Token Absolute
---@private
---@param i integer
---@param j integer
---@param dryRun? boolean # if true, does not save the token
---@param type? TokenType
---@return Token
function Cls:createToken(i, j, dryRun, type)
    local token = Token.new(type or TokenType.UNK, self:data(), i, j)
    if not dryRun then
        self.m_Tok = token
    end
    return token
end

---@param tk Token
---@return integer startLine
---@return integer startCol
---@return integer endLine
---@return integer endCol
function Cls:getLineInfo(tk)
    local function rangeTest(node, key)
        if key < node[1] then
            return -1
        elseif key > node[2] then
            return 1
        else
            return 0
        end
    end
    local headPos, tailPos = tk:head(), tk:tail()
    local tbl = self.m_LineInfo

    local hL, hP, tL, tP, _

    hL = ARR.bfind(tbl, headPos, rangeTest)
    if not hL then return 0, 0, 0, 0 end
    hP, _ = table.unpack(tbl[hL])

    tL = ARR.bfind(tbl, tailPos, rangeTest, hL)
    if not tL then
        tP, _ = table.unpack(tL and tbl[tL] or { hP, nil })
    else
        tP = hP
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return hL, (headPos - hP + 1), tL, (tailPos - tP + 1)
end

--- Set Position
---@param offset integer
---@param mode? "set"|"cur"|"end"
function Cls:seek(offset, mode)
    mode = mode or "cur"
    local newPos
    if mode == "set" then
        newPos = offset
    elseif mode == "cur" then
        newPos = self.m_Pos + offset
    elseif mode == "end" then
        newPos = self.m_View:tail() + offset
    else
        error("invalid seek mode", 3)
    end
    self.m_Pos = math.max(math.min(self.m_View:tail() + 1, newPos), self.m_View:head())
end

--- Cur Position
function Cls:tell()
    return self.m_Pos
end

function Cls:error(msg, level)
    local eMsg = string.format("at %d: " .. msg, self:token():head())
    error(eMsg, level)
end

--- Geneneric Token (Non-Anchored)
---@private
---@param pattern string
---@param dryRun boolean # if true does not save the token or move the read head
---@param seekPast? boolean
---@param plain? boolean
---@param startPos? integer
---@return Token?
function Cls:find(pattern, dryRun, seekPast, plain, startPos)
    startPos = startPos or self.m_Pos
    seekPast = seekPast or false
    plain = plain or false
    local i, j = self:data():find(pattern, startPos, plain)
    if i then
        if not dryRun then
            self:seek((seekPast and j or i) + 1, "set") -- New Token Head or Tail
        end
        return self:createToken(i, j, dryRun, TokenType.Uknown)
    else
        return nil
    end
end

--- Generic Token (Anchored)
--- Starts from current position, saves the token and moves the read head on a match
---@param pattern string
---@return Token? token
function Cls:match(pattern)
    return self:find("^" .. pattern, false, true, false)
end

--- Generic Token (Dry-run) (Anchored)
--- Starts from current position, but does not save the token or move the read head
---@param pattern string
---@return Token? token
function Cls:dryMatch(pattern)
    return self:find("^" .. pattern, true, true, false)
end

--- Consumes the previously dry-matched token
---@param token Token
---@param seekPast? boolean
function Cls:consume(token, seekPast)
    assert(token:head() == self.m_Pos, "invalid state")
    self.m_Tok = token
    self:seek(token:tail() + 1, "set")
end

local asType = Token.withType
local T = TokenType

--- Single-Line Range (Escape-capable)
---@param scanBegin string
---@param scanEnd string|fun(token:Token):string
---@param scanEndTest? fun(token:Token):boolean
---@param breakOnLF boolean
---@return Token?
function Cls:scanRange(scanBegin, scanEnd, scanEndTest, breakOnLF)
    if self:match(scanBegin) then
        local tkBeg = self:token()
        if type(scanEnd) == "function" then
            scanEnd = scanEnd(tkBeg)
        end
        local pat = scanEnd
        local pos = tkBeg:tail() + 1

        local escLF = self:find('\\n', true, true, false, pos)
        local rawLF = self:find("[^\\]\n", true, true, false, pos)

        local tkEnd
        while true do
            local tk = self:find(pat, false, true, false, pos)
            if not tk then
                self:error("unfinished range")
                break
            end

            if breakOnLF and rawLF then
                local inside = (rawLF:tail() > tkBeg:head()) and (rawLF:tail() < tk:head())
                if inside then
                    self:error("unescaped line break", 2)
                    break
                end
            end

            if not scanEndTest or scanEndTest(tk) == true then
                tkEnd = tk
                break
            end
            pos = tk:tail() + 1
        end

        local i, j = tkBeg:head(), tkEnd:tail()
        if rawLF and rawLF:tail() == tkEnd:tail() then
            j = j - 1
            self:seek(rawLF:tail(), "set")
        end

        local tk = self:createToken(i, j)
        local tkType = T.RNG
        if escLF and escLF:tail() < tkEnd:tail() then tkType = tkType | T.ML end
        return asType(tk, tkType)
    end
end

--- Whitespace
function Cls:whitespace()
    -- local rv = self:match("[^%S\n]+") or self:match("\n")
    local rv
    if self:dryMatch("%s") then
        rv = nil
            or self:match("[^%S\n]+")
            or self:match("\n%s*")
    end
    return asType(rv, TokenType.Whitespace)
end

--- Comment
function Cls:comment()
    for i = 1, #self.m_Comment do
        local r = self.m_Comment[i]
        if self:scanRange(r.head, r.tail, r.test, not r.multiline) then
            local tk = self:token()
            local ml = tk:type() & T.ML
            return asType(tk, T.COM | ml)
        end
    end
end

--- String
---@return Token?
function Cls:string()
    for i = 1, #self.m_String do
        local r = self.m_String[i]
        if self:scanRange(r.head, r.tail, r.test, not r.multiline) then
            local tk = self:token()
            local ml = tk:type() & T.ML
            return asType(tk, T.STR | ml)
        end
    end
    return nil
end

--- Number
---@return Token?
function Cls:number()
    if self:dryMatch("[%d%.]") then
        if self:dryMatch("0[xX]") then
            return nil
                -- Hex Decimal Scientific
                or asType(self:match("0[xX]%x-%.%x-p[+-]?%d+"), T.NUM | T.HEX | T.DEC | T.SCI)
                -- Hex Decimal
                or asType(self:match("0[xX]%x-%.%x+"), T.NUM | T.HEX | T.DEC)
                -- Hex Scientific
                or asType(self:match("0[xX]%x-p[+-]?%d+"), T.NUM | T.HEX | T.SCI)
                -- Hex
                or asType(self:match("0[xX]%x+"), T.NUM | T.HEX)
        elseif self:dryMatch("%d-%.%d+") then
            return nil
                -- Decimal Scientific
                or asType(self:match("%d-%.%d-e[+-]?%d+"), T.NUM | T.DEC | T.SCI)
                -- Decimal
                or asType(self:match("%d-%.%d+"), T.NUM | T.DEC)
        elseif self:dryMatch("%d+") then
            return nil
                -- Scientific
                or asType(self:match("%d-e[+-]?%d+"), T.NUM | T.SCI)
                --
                or asType(self:match("%d+"), T.NUM)
        end
    end
    return nil
end

--- Identifier
---@return Token?
function Cls:identifier()
    local tk = self:dryMatch("[%a_][%w_]*")
    if tk and not self.m_Keywords[tk:value()] then
        self:consume(tk)
        local tkType = T.ID
        return asType(tk, tkType)
    end
    return nil
end

--- Keyword
---@return Token?
function Cls:keyword()
    local tk = self:dryMatch("[%a_][%w_]*")
    if tk and self.m_Keywords[tk:value()] then
        self:consume(tk)
        local tkType = T.KWD
        return asType(tk, tkType)
    end
    return nil
end

--- Symbol
---@return Token?
function Cls:symbol()
    for _, symb in pairs(self.m_Symbols) do
        if self:match(symb) then
            return asType(self:token(), T.SYM | T.KNW)
        end
    end
    return asType(self:match("."), T.SYM)
end

---@param tk? Token
function Cls:reset(tk)
    if tk then
        assert(tk:data() == self:data(), "token/tokenizer source data mismatch")
        self:seek(tk:head() + 1, "set")
        self.m_Tok = tk
    else
        self:withSource(self:data())
    end
end

---@return Token?
function Cls:next()
    if self:eof() then
        self.m_Tok = nil
        return nil
    end
    local rv = nil
        or self:whitespace()
        or self:comment()
        or self:string()
        or self:keyword()
        or self:identifier()
        or self:number()
        or self:symbol()

    if not rv then
        if not self:eof() then error("failed to read token") end
        return nil
    end

    return rv
end

function Cls:tokenize()
    return Cls.next, self, nil
end

---@param fun function
local function checked(fun)
    ---@param self TokenReader
    return function(self, ...)
        local value = { fun(self, ...) }

        if value[1] == nil and not self:eof() then
            self:error("got nil but EOF was not reached")
        end

        return table.unpack(value)
    end
end

---@param fun function
---@param type TokenType
local function typed(fun, type)
    ---@param self TokenReader
    return function(self, ...)
        local value = fun(self, ...)

        if value ~= nil then
            local tt = value:type()
            local test = (tt & type) == type
            if not test then
                self:error("invalid token type")
            end
        end

        return value
    end
end

Cls.string = typed(Cls.string, TokenType.String)
Cls.number = typed(Cls.number, TokenType.Number)
Cls.identifier = typed(Cls.identifier, TokenType.Identifier)
Cls.keyword = typed(Cls.keyword, TokenType.Keyword)
Cls.whitespace = typed(Cls.whitespace, TokenType.Whitespace)
Cls.comment = typed(Cls.comment, TokenType.Comment)
Cls.symbol = typed(Cls.symbol, TokenType.Symbol)
Cls.tokenize = checked(Cls.tokenize)

---

return Cls
