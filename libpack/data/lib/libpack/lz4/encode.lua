--- Ported from https://github.com/Benzinga/lz4js/blob/master/lz4.js

---@param src string
---@return string? # String
---@return integer # Checksum
local function lz4_decode(src)
    local LZ4_MIN_LENGHT = 13
    local LZ4_MIN_MATCH = 4
    local LZ4_SKIP_TRIGGER = 6
    local LZ4_SEARCH_LIMIT = 5

    local res = {}
    local buf = {}
    local bsz = 0
    local function flush()
        if bsz == 0 then return end
        res[#res + 1] = string.char(table.unpack(buf, 1, bsz))
        bsz = 0
    end
    ---@param v integer
    local function writeU8(v)
        bsz = bsz + 1
        buf[bsz] = v
        if bsz == 16 then flush() end
    end

    ---@param i integer
    local function readU8(i)
        return src:byte(i)
    end

    ---@param i integer
    local function readU32(i)
        local b4, b3, b2, b1 = src:byte(i, i + 4)
        return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1
    end

    local p = 0x01000193
    local h  = 0x811C9DC5
    for i = 1, #src do
        h = ((readU8(i) ~ h) * p) & 0xFFFFFFFF
    end

    local mIndex, mLength, mOffset, mStep
    local literalCount

    local hashTable = {}

    -- Setup initial state.
    local sIndex = 1
    local sLength = #src
    local sEnd = sLength + sIndex
    local mAnchor = sIndex

    -- Process only if block is large enough.
    if (sLength >= LZ4_MIN_LENGHT) then
        local searchMatchCount = (1 << LZ4_SKIP_TRIGGER) + 3;

        -- Consume until last n literals (Lz4 spec limitation.)
        while ((sIndex + LZ4_MIN_MATCH) < (sEnd - LZ4_SEARCH_LIMIT)) do
            local seq = readU32(sIndex)

            mIndex = hashTable[seq]
            hashTable[seq] = sIndex

            -- Determine if there is a match (within range.)
            if (mIndex == nil or ((sIndex - mIndex) >> 16) > 0 or readU32(mIndex) ~= seq) then
                mStep = searchMatchCount >> LZ4_SKIP_TRIGGER
                searchMatchCount = searchMatchCount + 1
                sIndex = sIndex + mStep
                goto continue
            end
            searchMatchCount = (1 << LZ4_SKIP_TRIGGER) + 3

            -- Calculate literal count and offset.
            literalCount = sIndex - mAnchor
            mOffset = sIndex - mIndex

            -- We've already matched one word, so get that out of the way.
            sIndex = sIndex + LZ4_MIN_MATCH
            mIndex = mIndex + LZ4_MIN_MATCH

            -- Determine match length.
            -- N.B.: mLength does not include minMatch, Lz4 adds it back
            -- in decoding.
            mLength = sIndex
            while ((sIndex < sEnd - LZ4_SEARCH_LIMIT) and (readU8(sIndex) == readU8(mIndex))) do
                sIndex = sIndex + 1
                mIndex = mIndex + 1
            end
            mLength = sIndex - mLength;

            -- Write token + literal count.
            local token = (mLength < 0x0F) and mLength or 0x0F;
            if (literalCount >= 0x0F) then
                writeU8(0xF0 + token)
                local n = literalCount - 0x0F
                while n >= 0xFF do
                    writeU8(0xFF)
                    n = n - 0xFF
                end
                writeU8(n)
            else
                writeU8((literalCount << 4) + token)
            end

            -- Write literals.
            local i = 0
            while i < literalCount do
                writeU8(readU8(mAnchor + i))
                i = i + 1
            end

            -- Write offset.
            assert(mOffset < 0xFFFF)
            writeU8(mOffset & 0xFF)
            writeU8((mOffset >> 8) & 0xFF)

            -- Write match length.
            if (mLength >= 0x0F) then
                local n = mLength - 0x0F
                while n >= 0xFF do
                    writeU8(0xFF)
                    n = n - 0xFF
                end
                writeU8(n)
            end

            -- Move the anchor.
            mAnchor = sIndex
            ::continue::
        end
    end

    -- Nothing was encoded.
    if (mAnchor == 1) then
        return nil, h
    end

    -- Write remaining literals.
    -- Write literal token+count.
    literalCount = sEnd - mAnchor
    if (literalCount >= 0x0F) then
        writeU8(0xF0)
        local n = literalCount - 0x0F
        while n >= 0xFF do
            writeU8(0xFF)
            n = n - 0xFF
        end
        writeU8(n)
    elseif literalCount > 0 then
        writeU8(literalCount << 4)
    end

    -- Write literals.
    sIndex = mAnchor;
    while (sIndex < sEnd) do
        writeU8(readU8(sIndex))
        sIndex = sIndex + 1
    end
    flush()
    return table.concat(res), h
end

return lz4_decode
