---@enum TokenType
local Enum = {
    Invalid     = 0,
    Uknown      = 1 << 0,
    Whitespace  = 1 << 1,
    Number      = 1 << 2,
    String      = 1 << 3,
    Identifier  = 1 << 4,
    Symbol      = 1 << 5,
    Comment     = 1 << 6,
    Range       = 1 << 7,
    Keyword     = 1 << 8,

    Hex         = 1 << 16,
    Decimal     = 1 << 17,
    Scientific  = 1 << 18,
    Multiline   = 1 << 19,
    KnownSymbol = 1 << 20,

    TypeMask    = 0x0000FFFF,
    FlagMask    = 0xFFFF0000
}

do
    local tbl = {}
    for k, v in pairs(Enum) do
        if v ~= 0 then
            tbl[#tbl + 1] = { k, v }
        end
    end
    table.sort(tbl, function(a, b) return a[2] < b[2] end)
    function Enum.name(value)
        local b = {}
        for _, v in ipairs(tbl) do
            local name, mask = table.unpack(v)
            if value & mask == mask then
                b[#b + 1] = name
            end
        end
        return table.concat(b, ", ")
    end
end

do
    Enum.UNK = Enum.Uknown
    Enum.WS  = Enum.Whitespace
    Enum.NUM = Enum.Number
    Enum.STR = Enum.String
    Enum.ID  = Enum.Identifier
    Enum.SYM = Enum.Symbol
    Enum.COM = Enum.Comment
    Enum.RNG = Enum.Range
    Enum.HEX = Enum.Hex
    Enum.DEC = Enum.Decimal
    Enum.SCI = Enum.Scientific
    Enum.ML  = Enum.Multiline
    Enum.KWD = Enum.Keyword
    Enum.KNW = Enum.KnownSymbol
end

return Enum