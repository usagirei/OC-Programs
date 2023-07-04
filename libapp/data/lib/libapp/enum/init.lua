---@class Enum
---@field values any[]
---@field keys string[]
---@field name string
---@field hasValue fun(any):boolean

local Enum = {}

function Enum.NewEnum(name, enum)
    if type(name) ~= "string" then
        error("enum name must be a string: '" .. name .. "'", 3)
    end

    local vlookup = {}
    local keys = {}
    local values = {}
    for k, v in pairs(enum) do
        keys[#keys + 1] = k
        values[#values + 1] = v
        vlookup[v] = k
        if type(k) ~= "string" then
            error("enum keys must be strings", 3)
        end
    end

    local function hasValue(v)
        return vlookup[v] ~= nil
    end

    local mt = {}
    function mt.__index(tbl, index)
        if index == "values" then
            return values
        elseif index == "keys" then
            return keys
        elseif index == "name" then
            return name
        elseif index == "hasValue" then
            return hasValue
        end

        error(string.format("invalid enum key '%s::%s'", name, index), 2)
    end

    return setmetatable(enum, mt)
end

return Enum
