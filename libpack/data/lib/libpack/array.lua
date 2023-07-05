local lib = {}

---@param tbl table
function lib.is_array(tbl)
    local i = 0
    for _ in pairs(tbl) do
        i = i + 1
        if tbl[i] == nil then return false end
    end
    return true
end

function lib.reverse(x)
    local n, m = #x, #x / 2
    for i = 1, m do
        x[i], x[n - i + 1] = x[n - i + 1], x[i]
    end
    return x
end

---@generic TNode
---@generic TKey
---@param arr TNode[]
---@param key TKey
---@param compare fun(elem:TNode, key:TKey):integer
---@param i? integer
---@param j? integer
---@return integer? index
---@return TNode node
function lib.bfind(arr, key, compare, i, j)
    i = i or 1
    j = j or #arr
    if(i > j) then return nil, nil end

    local m = (i + j) // 2
    local node = arr[m]
    if not node then
        return nil, nil
    end
    local r = compare(node, key)
    if r == 0 then
        return m, node
    elseif r < 0 then
        i, j = i, m - 1
    else
        i, j = m + 1, j
    end
    return lib.bfind(arr, key, compare, i, j)
end

---@generic TNode
---@generic TKey
---@param arr TNode[]
---@param key TKey
---@param pred? fun(elem:TNode, key:TKey):boolean
---@param i? integer
---@param j? integer
---@return integer? index
---@return TNode node
function lib.find(arr, key, pred, i, j)
    i = i or 1
    j = j or #arr
    assert(i <= j)
    for ii = i, j, 1 do
        local node = arr[ii]
        if not pred then
            if node == key then return ii, node end
        else
            if pred(node, key) then return ii, node end
        end
    end
    return nil, nil
end

---@generic TNode
---@generic TKey
---@param arr TNode[]
---@param key TKey
---@param pred fun(elem:TNode, key:TKey):boolean
---@param i? integer
---@param j? integer
---@return integer? index
---@return TNode node
function lib.rfind(arr, key, pred, i, j)
    i = i or 1
    j = j or #arr
    assert(i <= j)
    for ii = j, i, -1 do
        local node = arr[ii]
        if not pred then
            if node == key then return ii, node end
        else
            if pred(node, key) then return ii, node end
        end
    end
    return nil, nil
end

return lib
