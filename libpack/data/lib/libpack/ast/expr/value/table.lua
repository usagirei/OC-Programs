local Class = require("libpack.class")
local Token = require("libpack.tokenizer.token")
local TOK = require("libpack.tokenizer.type")
local ValidIdentifier = require("libpack.ast.expr.value.var").IsValidIdentifier

-----------------------------------------------------------

local Super = require("libpack.ast.node")
---@class TableField : Node
local TableField = Class.NewClass(Super)

---@param key? ValueExpr|Token
---@param value ValueExpr
function TableField.new(key, value)
    return Class.NewObj(TableField, key, value)
end

---@param key? ValueExpr|Token
---@param value ValueExpr
function TableField:init(key, value)
    Super.init(self)
    if key == nil then
        self.m_Key = nil
    elseif Class.IsInstance(key, Token) then
        self.m_Key = key
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        self.m_Key = self:_setCheck(key)
    end
    self.m_Value = self:_setCheck(value)
end

function TableField:key() return self.m_Key end

function TableField:value() return self.m_Value end

function TableField:validate()
    local AST = require("libpack.ast")
    Super.validate(self)

    local k = self.m_Key
    local v = self.m_Value
    if not Class.IsInstance(v, AST.Expr) then
        error("invalid table field value")
    end
    if k then
        if Class.IsInstance(k, AST.Expr) then
            -- OK
        elseif Class.IsInstance(k, Token) then
            local tok = k --[[@as Token]]
            if not ValidIdentifier(tok) then
                error("invalid table key value")
            end
        else
            error("invalid table key type: " .. Class.TypeName(k))
        end
    end
end

-----------------------------------------------------------

local Super = require("libpack.ast.expr.value")
---@class ValueTableExpr : ValueExpr
local Cls = Class.NewClass(Super, "value-table")

Cls.Field = TableField

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    Super.init(self, false)
    self.m_Fields = nil
end

---@param fields TableField[]
function Cls:setFields(fields)
    assert(fields ~= nil, "fields must not be nil")
    self.m_Fields = self:_setCheckArr(fields)
    return self
end

function Cls:fields() return self.m_Fields end

function Cls:validate()
    local AST = require("libpack.ast")

    Super.validate(self)
    if not self.m_Fields then error("missing table fields") end
    for i, j in pairs(self.m_Fields) do
        j:validate()
    end

    return self
end

return Cls
