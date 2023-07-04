--- Ported from https://github.com/Benzinga/lz4js/blob/master/lz4.js

---@param src string
---@param checksum? integer
---@return string? # String
---@return integer # Checksum
local function lz4_decode(src, dst, checksum)
    local LZ4_MIN_MATCH = 4

    local sIndex = 1
    local sLength = #src
    local sEnd = sIndex + sLength

    local R = {}
    local B = {}
    local S = 0

    local function flush()
        if S == 0 then return end
        local v = string.char(table.unpack(B, 1, S))
        local i = #R
        R[i + 1] = v
        S = 0
    end

    ---@param v integer
    local function writeU8(v)
        S = S + 1
        B[S] = v
        if S == 16 then flush() end
    end

    local function copyback(o, n)
        if n == 0 then return end
        flush()
        if o > #R[#R] then
            local s, i = 0, #R + 1
            while s < o do
                i = i - 1
                s = s + #R[i]
            end
            local k = s - o + 1
            local l = k + n - 1
            while l > #R[i] and R[i + 1] do
                R[i] = R[i] .. R[i + 1]
                table.remove(R, i + 1)
            end
            if l <= #R[i] then
                R[#R + 1] = R[i]:sub(k, l)
            else
                copyback(o, n)
            end
        else
            local s = #R[#R]
            local k = s - o + 1
            local m = math.min(s - k + 1, n)
            local l = k + m - 1
            R[#R + 1] = R[#R]:sub(k, l)
            local r = n - m
            if r > 0 then
                copyback(o, r)
            end
        end
    end

    local function readU8()
        local r = src:byte(sIndex)
        sIndex = sIndex + 1
        return r
    end

    -- Consume entire input block.
    while sIndex < sEnd do
        local token = readU8()

        -- Copy literals.
        local literalCount = (token >> 4) & 0x0F
        if literalCount > 0 then
            -- Parse length.
            if literalCount == 15 then
                while true do
                    local n = readU8()
                    literalCount = literalCount + n
                    if n ~= 255 then
                        break
                    end
                end
            end

            -- Copy literals
            for i = 1, literalCount do
                writeU8(readU8())
            end
        end

        if (sIndex >= sEnd) then
            break
        end

        -- Copy match.
        local mLength = (token >> 0) & 0x0F

        -- Parse offset.
        local mOffset = readU8() | (readU8() << 8);

        -- Parse length.
        if (mLength == 15) then
            while true do
                local n = readU8()
                mLength = mLength + n;
                if (n ~= 255) then
                    break
                end
            end
        end

        mLength = mLength + LZ4_MIN_MATCH

        -- Copy match
        copyback(mOffset, mLength)
    end

    flush()
    local out = table.concat(R)

    if checksum == nil then
        return out, 0
    end

    local p = 0x01000193
    local h = 0x811C9DC5
    for i = 1, #out do
        h = ((out:byte(i) ~ h) * p) & 0xFFFFFFFF
    end


    return out, h
end

return lz4_decode
