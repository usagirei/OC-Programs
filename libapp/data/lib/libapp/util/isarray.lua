---@param arr table
local function is_array(arr)
    local c = 0
    for _ in pairs(arr) do
        c = c + 1
        if arr[c] == nil then
            return false
        end
    end
    return true
end
return is_array
