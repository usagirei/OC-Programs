local TokenReader = require("libpack.tokenizer.reader")
local TokenType = require("libpack.tokenizer.type")

local RangeTail = function(token)
    local eq = (token:value():match("%[(=*)%[$") or "")
    return "]" .. eq .. "]"
end

local NumberTypes = {
    ["^0[xX]%x-%.%x-p[+-]?%d+$"] = TokenType.NUM | TokenType.HEX | TokenType.DEC | TokenType.SCI,
    ["^0[xX]%x-%.%x+$"] = TokenType.NUM | TokenType.HEX | TokenType.DEC,
    ["^0[xX]%x-p[+-]?%d+$"] = TokenType.NUM | TokenType.HEX | TokenType.SCI,
    ["^0[xX]%x+$"] = TokenType.NUM | TokenType.HEX,
    ["^%d-%.%d-e[+-]?%d+$"] = TokenType.NUM | TokenType.DEC | TokenType.SCI,
    ["^%d-%.%d+$"] = TokenType.NUM | TokenType.DEC,
    ["^%d-e[+-]?%d+$"] = TokenType.NUM | TokenType.SCI,
    ["^%d+$"] = TokenType.NUM,
}

---@type RangeData[]
local ComRange = {
    { head = "%-%-%[=*%[", tail = RangeTail, test = nil,                               multiline = true },
    { head = "%-%-",       tail = '\n',      test = TokenReader.RangeEscapeTest('\\'), multiline = false }
}

local StrRange = {
    { head = "%[=*%[", tail = RangeTail, test = nil,                               multiline = true },
    { head = "'",      tail = "'",       test = TokenReader.RangeEscapeTest('\\'), multiline = false },
    { head = '"',      tail = '"',       test = TokenReader.RangeEscapeTest('\\'), multiline = false }
}

local Sym = {
    VarArg = "...",
    Concat = "..",

    CmpEqu = "==",
    CmpNeq = "~=",
    CmpLte = "<=",
    CmpGte = ">=",
    CmpLt = "<",
    CmpGt = ">",

    Add = "+",
    Sub = "-",
    Mul = "*",
    Div = "/",
    Mod = "%",
    Exp = "^",
    Len = "#",
    Assign = "=",

    OpenPar = "(",
    ClosePar = ")",
    OpenCurly = "{",
    CloseCurly = "}",
    OpenBracket = "[",
    CloseBracket = "]",

    SemiColon = ";",
    Colon = ":",
    Comma = ",",
    Dot = ".",

    IDiv = "//",
    BitXor = "~",
    BitAnd = "&",
    BitOr = "|",
    BitLsh = "<<",
    BitRsh = ">>",
    Label = "::"
}

local Kwd = {
    And = 'and',
    Or = 'or',
    Not = 'not',

    For = 'for',
    In = 'in',
    Do = 'do',
    While = 'while',
    Repeat = 'repeat',
    Until = 'until',
    If = 'if',
    Then = 'then',
    Else = 'else',
    ElseIf = 'elseif',
    End = 'end',
    Break = 'break',
    Return = 'return',
    Goto = 'goto',

    Local = 'local',
    Function = 'function',
    True = 'true',
    False = 'false',
    Nil = 'nil',
}

local Ops = {
    { "b", "k", Kwd.Or,     1,  false },
    { "b", "k", Kwd.And,    2,  false },

    { "b", "s", Sym.CmpLt,  3,  false },
    { "b", "s", Sym.CmpGt,  3,  false },
    { "b", "s", Sym.CmpLte, 3,  false },
    { "b", "s", Sym.CmpGte, 3,  false },
    { "b", "s", Sym.CmpNeq, 3,  false },
    { "b", "s", Sym.CmpEqu, 3,  false },

    { "b", "s", Sym.BitOr,  4,  false },
    { "b", "s", Sym.BitXor, 5,  false },
    { "b", "s", Sym.BitAnd, 6,  false },
    { "b", "s", Sym.BitLsh, 7,  false },
    { "b", "s", Sym.BitRsh, 7,  false },

    { "b", "s", Sym.Concat, 8,  true },

    { "b", "s", Sym.Add,    9,  false },
    { "b", "s", Sym.Sub,    9,  false },
    { "b", "s", Sym.Mul,    10, false },
    { "b", "s", Sym.Div,    10, false },
    { "b", "s", Sym.IDiv,   10, false },
    { "b", "s", Sym.Mod,    10, false },

    { "u", "k", Kwd.Not,    11, false },
    { "u", "s", Sym.Len,    11, false },
    { "u", "s", Sym.Sub,    11, false },
    { "u", "s", Sym.BitXor, 11, false },

    { "b", "s", Sym.Exp,    12, true },
}

return {
    Symbols = Sym,
    Keywords = Kwd,
    CommentRange = ComRange,
    StringRange = StrRange,
    Operators = Ops,
    Numbers = NumberTypes
}
