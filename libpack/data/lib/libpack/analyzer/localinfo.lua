local Class = require("libpack.class")
local AST = require("libpack.ast")
local TOK = require("libpack.tokenizer.type")

---@class LocalInfo
local Cls = Class.NewClass()

---@class LocalInfo_Var
Cls.Var = Class.NewClass()

---@class LocalInfo_VarDecl : LocalInfo_Var
Cls.VarDecl = Class.NewClass(Cls.Var)

--------------------------------------------------------------------

---@param node ValueVarExpr
function Cls.Var.new(node)
    return Class.NewObj(Cls.VarDecl, node)
end

---@param node Node
function Cls.Var:init(node)
    self.m_Node = node
end

function Cls.Var:node() return self.m_Node end

--------------------------------------------------------------------

---@param node ValueVarExpr
---@param scope Scope
---@param order integer
function Cls.VarDecl.new(node, scope, order)
    return Class.NewObj(Cls.VarDecl, node, scope, order)
end

---@param node ValueVarExpr
---@param scope Scope
---@param order integer
function Cls.VarDecl:init(node, scope, order)
    Cls.Var.init(self, node)
    self.m_Scope = scope
    self.m_Refs = { self }
    self.m_Order = order
end

---@return LocalInfo_Var[]
function Cls.VarDecl:refs() return self.m_Refs end

function Cls.VarDecl:scope() return self.m_Scope end

function Cls.VarDecl:order() return self.m_Order end

--------------------------------------------------------------------

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    ---@type {[string]:LocalInfo_VarDecl[]}
    self.m_Locals = {}
    ---@type {[string]:LocalInfo_Var[]}
    self.m_Globals = {}
    ---@type Scope[]
    self.m_Scopes = {}
    ---@type LocalInfo_VarDecl[]
    self.m_Decls = {}
end

function Cls:enterScope(scope)
    self.m_Scopes[#self.m_Scopes + 1] = scope
end

function Cls:exitScope(scope)
    assert(self.m_Scopes[#self.m_Scopes] == scope)
    self.m_Scopes[#self.m_Scopes] = nil
end

---@param node ValueVarExpr
function Cls:declare(node)
    assert(node:isDecl())
    local name = node:name():value()
    if not self.m_Locals[name] then
        self.m_Locals[name] = {}
    end
    local x = self.m_Locals[name]
    local scope = self.m_Scopes[#self.m_Scopes]
    assert(scope)
    local n = #self.m_Decls + 1
    local d = Cls.VarDecl.new(node, scope, n)
    self.m_Decls[n] = d
    x[#x + 1] = d
end

---@param node ValueVarExpr
function Cls:use(node)
    assert(not node:isDecl())
    local name = node:name():value()
    local var = Cls.Var.new(node)

    local decl
    for i = #self.m_Scopes, 1, -1 do
        local s = self.m_Scopes[i]
        decl = self:lastDecl(name, s)
        if decl then break end
    end

    if decl == nil then
        if not self.m_Globals[name] then self.m_Globals[name] = {} end
        local x = self.m_Globals[name]
        x[#x + 1] = var
    else
        ---@cast decl LocalInfo_VarDecl
        local r = decl:refs()
        r[#r + 1] = var
    end
end

---@param name string
---@param scope? Scope
---@return LocalInfo_VarDecl?
function Cls:lastDecl(name, scope)
    if not self.m_Locals[name] then return nil end

    local decls = self.m_Locals[name]
    for i = #decls, 1, -1 do
        local decl = decls[i]
        if (not scope) or (decl:scope() == scope) then
            return decl
        end
    end
    return nil
end

---@param name string
---@param scope? Scope
---@return LocalInfo_VarDecl?
function Cls:firstDecl(name, scope)
    if not self.m_Locals[name] then return nil end

    local decls = self.m_Locals[name]
    for i = 1, #decls do
        local decl = decls[i]
        if (not scope) or (decl:scope() == scope) then
            return decl
        end
    end
    return nil
end

---@param name string
function Cls:getDecls(name)
    if not self.m_Locals[name] then return {} end
    local d = self.m_Locals[name]
    return { table.unpack(d) }
end

---@return {name:string, decl:ValueVarExpr, refs:ValueVarExpr[]}[]
function Cls:getLocals(scope)
    local rv = {}
    for name, decls in pairs(self.m_Locals) do
        for _, decl in pairs(decls) do
            if (not scope) or (decl:scope() == scope) then
                local refs = {}
                for _, var in pairs(decl:refs()) do
                    refs[#refs + 1] = var:node()
                end
                rv[#rv + 1] = { name = name, decl = decl:node(), refs = refs, num=decl:order() }
            end
        end
    end
    table.sort(rv, function(a, b) return a.num < b.num end)
    return rv
end

return Cls
