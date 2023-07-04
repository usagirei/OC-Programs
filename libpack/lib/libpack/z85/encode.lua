local SET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#'
assert(((#SET) ^ 5) >= (256 ^ 4))

local LEN = #SET
local ENC = {}
for i = 1, #SET do
    local j = string.byte(SET, i)
    assert(j >= 32 and j <= 126)
    ENC[i - 1] = j
end

---@param b4 integer
---@param b3 integer
---@param b2 integer
---@param b1 integer
---@return integer,integer,integer,integer,integer
local function z85_frame(b4, b3, b2, b1)
    local dword =
        ((b4 & 0xFF) << 24)|
        ((b3 & 0xFF) << 16)|
        ((b2 & 0xFF) << 8)|
        ((b1 & 0xFF) << 0)

    local div, c5, c4, c3, c2, c1, mod

    div = dword // LEN
    mod = dword - (div * LEN)
    c1 = ENC[mod]
    dword = div

    div = dword // LEN
    mod = dword - (div * LEN)
    c2 = ENC[mod]
    dword = div

    div = dword // LEN
    mod = dword - (div * LEN)
    c3 = ENC[mod]
    dword = div

    div = dword // LEN
    mod = dword - (div * LEN)
    c4 = ENC[mod]

    c5 = ENC[div]

    return c5, c4, c3, c2, c1
end

---@param str string
local function z85_encode(str)
    local n = #str
    local N = (n // 4) * 4
    local R = (n - N)
    local tbl = {}
    for i = 1, N, 4 do
        local b4, b3, b2, b1 = str:byte(i, i + 4)
        local frame = string.char(z85_frame(b4, b3, b2, b1))
        tbl[#tbl + 1] = frame
    end
    if R ~= 0 then
        local b4, b3, b2, b1 = str:byte(N + 1, N + 1 + R)
        if R == 3 then
            b1 = 49
        elseif R == 2 then
            b2, b1 = 49, 50
        elseif R == 1 then
            b3, b2, b1 = 49, 50, 51
        end
        local frame = string.char(z85_frame(b4, b3, b2, b1))
        tbl[#tbl + 1] = frame
        tbl[#tbl + 1] = tostring(4 - R)
    end

    return table.concat(tbl)
end

return z85_encode
