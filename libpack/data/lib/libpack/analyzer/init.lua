local Class = require("libpack.class")
local Switch = require("libpack.switch")
local AST = require("libpack.ast")
local LocalInfo = require("libpack.analyzer.localinfo")

---@class Analyzer
local Cls = Class.NewClass()

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    self.m_Visitor = nil
end

---@param node Node
---@param onEnter? VisitCallback
---@param onExit? VisitCallback
function Cls:visit(node, onEnter, onExit)
    if not self.m_Visitor then
        local Visit = require("libpack.analyzer.visit")
        self.m_Visitor = Visit.new()
    end
    self.m_Visitor:visit(node, onEnter, onExit)
end

---@param node Node
---@return Scope?
function Cls:getScope(node)
    local cur = node:parentNode()
    if not cur then return nil end
    while true do
        if Class.IsInstance(cur, AST.Scope) then
            ---@cast cur Scope
            return cur
        end
        cur = cur:parentNode()
    end
end

---@param node Node
function Cls:getRootScope(node)
    if Class.IsInstance(node, AST.Chunk) then
        ---@cast node Chunk
        return node:innerScope()
    end
    local cur = self:getScope(node)
    if cur == nil then
        if Class.IsInstance(node, AST.Scope) then return node end
        error("failed to find root scope")
    end
    while true do
        local tmp = self:getScope(cur)
        if tmp == nil then break end
        cur = tmp
    end
    return assert(cur)
end

---@param expr Expr
function Cls:getStatement(expr)
    assert(Class.IsInstance(expr, AST.Expr))
    local cur = expr:parentNode()
    while cur ~= nil do
        if Class.IsInstance(cur, AST.Stat) then
            return cur
        end
        cur = cur:parentNode()
    end
    return nil
end

---@param scope Scope
---@param rootOnly? boolean
function Cls:getLocals(scope, rootOnly)
    local dcl = LocalInfo.new()

    ---@param node Node
    local function onEnter(node)
        if Class.IsInstance(node, AST.Scope) then
            ---@cast node Scope
            dcl:enterScope(node)
        elseif Class.IsInstance(node, AST.ValueVarExpr, true) then
            ---@cast node ValueVarExpr
            if node:isDecl() then
                dcl:declare(node)
            else
                dcl:use(node)
            end
        end
    end

    local function onExit(node)
        if Class.IsInstance(node, AST.Scope) then
            dcl:exitScope(node)
        elseif Class.IsInstance(node, AST.ValueVarExpr) then
        end
    end

    dcl:enterScope(scope)
    self:visit(scope, onEnter, onExit)
    dcl:exitScope(scope)

    if rootOnly then
        return dcl:getLocals(scope)
    else
        return dcl:getLocals()
    end
end

---@param chunk Chunk
function Cls:getScopes(chunk)
    local scope = chunk:innerScope()
    local stack = { scope }
    local rv = {}
    rv[scope] = false
    local function onEnter(node)
        if Class.IsInstance(node, AST.Scope) then
            assert(rv[node] == nil)
            rv[node] = stack[#stack]
            stack[#stack + 1] = node
        end
    end
    local function onExit(node)
        if Class.IsInstance(node, AST.Scope) then
            assert(stack[#stack] == node)
            stack[#stack] = nil
        end
    end
    assert(stack[#stack] == scope)
    self:visit(scope, onEnter, onExit)
    return rv
end

---@generic T : Node
---@param root Node
---@param nodeType T
---@param pred? fun(node:T):boolean
---@return T[]
function Cls:findNodes(root, nodeType, pred)
    local rv = {}
    local function onEnter(node)
        if Class.IsInstance(node, nodeType) and (not pred or pred(node)) then
            rv[#rv + 1] = node
        end
    end
    self:visit(root, onEnter)
    return rv
end

---@param oldNode Node
---@param newNode Node
function Cls:replace(oldNode, newNode)
    if not self.m_Replacer then
        local Replace = require("libpack.analyzer.replace")
        self.m_Replacer = Replace.new()
    end
    return self.m_Replacer:replace(oldNode, newNode)
end

---@param node Chunk|Stat|Expr
---@param pretty? boolean
---@param indent? string
function Cls:dump(node, pretty, indent)
    if not self.m_Dumper then
        local Dumper = require("libpack.analyzer.dump")
        self.m_Dumper = Dumper.new()
    end

    if self.m_Dumping then error("already dumping a node") end
    self.m_Dumping = true
    self.m_Dumper:reset(pretty, indent)
    self.m_Dumper:dump(node)
    local str = self.m_Dumper:tostring()
    self.m_Dumper:reset()
    self.m_Dumping = false
    return str
end

return Cls
