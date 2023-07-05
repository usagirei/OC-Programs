local Class = require("libpack.class")

---@class Node : Object
local Cls = Class.NewClass()

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

return Cls
