local lib = {}
local Prime = 0x01000193
local Seed = 0x811C9DC5

---@param value string|integer
---@param hash? integer
function lib.fnv1a(value, hash)
    hash = hash or Seed
    if type(value) == "string" then
        for _, byte in utf8.codes(value) do
            hash = hash ~ byte
            hash = (hash * Prime) & 0xFFFFFFFF
        end
    elseif type(value) == "number" then
        assert(math.floor(value) == value, "not an integer")
        hash = hash ~ value
        hash = (hash * Prime) & 0xFFFFFFFF
    end
    return hash
end

---@param value string|table|boolean|integer
function lib.getHashcode(value)
    local vType = type(value)
    if vType == "nil" then
        return 0
    elseif vType == "boolean" then
        return vType and 2 or 1
    elseif vType == "number" and math.floor(value) == value then
        return value
    elseif vType == "string" then
        return lib.fnv1a(vType)
    elseif vType == "table" then
        if value.hashcode ~= nil then
            if type(value.hashcode) == "function" then
                return value:hashcode()
            elseif type(value.hashcode) == "number" then
                local h = value.hashcode
                assert(math.floor(h) == h, "hashcode is not an integer")
                return h
            else
                error("unsupported hashcode")
            end
        else
            local hash = nil
            for kk, vv in pairs(value) do
                if (type(kk) == "number" and math.floor(kk) == kk) or (type(kk) == "string" and string.match(kk, "^_") == nil) then
                    local n = lib.getHashcode(vv)
                    hash = lib.fnv1a(kk --[[@as integer]], hash)
                    hash = lib.fnv1a(n, hash)
                end
            end
            return hash
        end
    else
        local k = tostring(value)
        return lib.fnv1a(k)
    end
end

return lib
