local lib = {}
lib.max_chunk_size = 32

---@param array table
---@param first integer
---@param last integer
---@param less fun(a:any,b:any):boolean
function lib._insertion_sort_impl(array, first, last, less)
    for i = first + 1, last do
        local k = first
        local v = array[i]
        for j = i, first + 1, -1 do
            if less(v, array[j - 1]) then
                array[j] = array[j - 1]
            else
                k = j
                break
            end
        end
        array[k] = v
    end
end

---@param array table
---@param workspace table
---@param low integer
---@param middle integer
---@param high integer
---@param less fun(a:any,b:any):boolean
function lib._merge(array, workspace, low, middle, high, less)
    local i, j, k
    i = 1
    -- copy first half of array to auxiliary array
    for j = low, middle do
        workspace[i] = array[j]
        i = i + 1
    end
    -- sieve through
    i = 1
    j = middle + 1
    k = low
    while true do
        if (k >= j) or (j > high) then
            break
        end
        if less(array[j], workspace[i]) then
            array[k] = array[j]
            j = j + 1
        else
            array[k] = workspace[i]
            i = i + 1
        end
        k = k + 1
    end
    -- copy back any remaining elements of first half
    for l = k, j - 1 do
        array[l] = workspace[i]
        i = i + 1
    end
end

---@param array table
---@param workspace table
---@param low integer
---@param high integer
---@param less fun(a:any,b:any):boolean
function lib._merge_sort_impl(array, workspace, low, high, less)
    if high - low <= lib.max_chunk_size then
        lib._insertion_sort_impl(array, low, high, less)
    else
        local mid = math.floor((low + high) / 2)
        lib._merge_sort_impl(array, workspace, low, mid, less)
        lib._merge_sort_impl(array, workspace, mid + 1, high, less)
        lib._merge(array, workspace, low, mid, high, less)
    end
end

local builtinTypes = {
    ["number"] = 1,
    ["string"] = 2
}

---@param a any
---@param b any
local function lessFn(a, b)
    local aType = builtinTypes[type(a)]
    local bType = builtinTypes[type(b)]
    if not aType or not bType then
        return false
    end
    if aType ~= bType then
        return aType < bType
    end
    return a < b
end
lib._default_less = lessFn

---@param array table
---@param less fun(a:any,b:any):boolean
function lib._setup(array, less)
    less = less or function(a, b) return a < b end
    local n = #array
    local trivial = (n <= 1)
    if not trivial then
        if less(array[1], array[1]) then
            error("invalid order function for sorting, less(v, v) should not be true for any v.")
        end
    end
    return trivial, n, less
end

---@param array table
---@param less fun(a:any,b:any):boolean
function lib.stable_sort(array, less)
    local trivial, n
    trivial, n, less = lib._setup(array, less)
    if not trivial then
        local aux = {}
        local mid = math.ceil(n / 2)
        aux[mid] = array[1]
        lib._merge_sort_impl(array, aux, 1, n, less)
    end
end

---@param arr table
---@param less fun(a:any,b:any):boolean
function lib.insertion_sort(arr, less)
    local trivial, n
    trivial, n, less = lib._setup(arr, less)
    if not trivial then
        lib._insertion_sort_impl(arr, 1, n, less)
    end
end

lib.unstable_sort = table.sort
table.insertion_sort = lib.insertion_sort
table.stable_sort = lib.stable_sort
table.unstable_sort = lib.unstable_sort
return lib
