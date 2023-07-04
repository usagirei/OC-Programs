local Class = require("libpack.class")

---@class Node : Object
local Cls = Class.NewClass()

---@param a Node
---@param b Node
function Cls:_sameType(a, b)
    assert(rawequal(Class.TypeOf(a), Class.TypeOf(b)), "node type mismatch")
end

---@param arr Node[]
---@param a Node
---@param b Node
function Cls:_replaceInArray(arr, a, b)
    for i, j in ipairs(arr) do
        if rawequal(a, j) then
            arr[i] = b
            return true
        end
    end
    return false
end

---@protected
---@generic T : Node
---@param nodes T[]
---@return T[]
function Cls:_setCheckArr(nodes)
    for _, node in ipairs(nodes) do self:_setCheck(node) end
    return nodes
end

---@protected
---@generic T : Node
---@param node T
---@return T
function Cls:_setCheck(node)
    ---@cast node Node
    assert(Class.IsInstance(node, Cls))
    node:setParentNode(self)
    node:validate()
    return node
end

function Cls:init()
    self.m_SourceInfo = nil
end

function Cls:parentNode()
    return self.m_ParentNode
end

---@param node Node
function Cls:setParentNode(node)
    assert(node ~= nil, "containing node must not be nil")
    self.m_ParentNode = node
    return self
end

function Cls:validate()
    if not self.m_ParentNode then error("parent node not set") end
end

---@param startPos integer
---@param startLine integer
---@param startCol integer
---@param endPos integer
---@param endLine integer
---@param endCol integer
function Cls:setSourceInfo(startPos, startLine, startCol, endPos, endLine, endCol)
    self.m_SourceInfo = { startPos, startLine, startCol, endPos, endLine, endCol }
end

---@return integer startPos
---@return integer startLine
---@return integer startCol
---@return integer endPos
---@return integer endLine
---@return integer endCol
function Cls:getSourceInfo()
    if not self.m_SourceInfo then
        return 0, 0, 0, 0, 0, 0
    else
        return table.unpack(self.m_SourceInfo)
    end
end

return Cls
