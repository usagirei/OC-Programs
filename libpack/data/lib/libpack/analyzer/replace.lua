local AST = require("libpack.ast")
local Class = require("libpack.class")
local Switch = require("libpack.switch")
local TokenWriter = require("libpack.tokenizer.writer")
local KWD = require("libpack.parser.syntax").Keywords
local SYM = require("libpack.parser.syntax").Symbols
local TOK = require("libpack.tokenizer.type")
local ARR = require("libpack.array")

---@class NodeReplacer
local Cls = Class.NewClass(nil, "NodeReplacer")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    self:createSwitch()
end

---@param old Node
---@param new Node
function Cls:replace(old, new)
    local parent = old:parentNode()
    assert(parent, "old node has no parent")
    return self:_replace(parent, old, new)
end

---@private
---@param root Node
---@param old Node
---@param new Node
function Cls:_replace(root, old, new)
    return self.m_Nodes:Match(root, old, new)
end

--------------------------------------------------------------------

---@private
function Cls:createSwitch()
    self.m_Nodes = Switch.new()

    local same = rawequal
    local function checkType(node, type, ...)
        if not type then return false end
        if Class.IsInstance(type, node) then return true end
        return checkType(node, ...)
    end

    ---@param nodes Node[]
    ---@param old Node
    ---@param new Node
    ---@param ... table
    local function replace_array(nodes, old, new, ...)
        assert(new, "replacement value must not be nil")
        if not checkType(new, ...) then return false end
        assert(ARR.is_array(nodes))
        local idx, oldNode = ARR.find(nodes, old, same)
        if idx then
            nodes[idx] = new
            return true, oldNode
        end
        return false, nil
    end

    ---@param node Node
    ---@param old Node
    ---@param new Node
    ---@param get fun(self:Node):Node
    ---@param set fun(self:Node, value:Node):Node
    ---@param ... table
    local function replace(node, old, new, get, set, ...)
        assert(new, "replacement value must not be nil")
        if not checkType(new, ...) then return false end
        if same(get(node), old) then
            set(node, new)
            return true
        end
        return false
    end


    self.m_Nodes:Case(AST.Chunk,
        ---@param old Node
        ---@param new Node
        function(c, old, new)
            return self:_replace(c:innerScope(), old, new)
        end
    )

    self.m_Nodes:Case(AST.FuncScope,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace(s, old, new, s.varArg, s.setVarArg, AST.ValueVarArgsExpr)
                or replace_array(s:args(), old, new, AST.ValueVarExpr)
                or replace_array(s:statements(), old, new, AST.Stat)
        end
    ):Case(AST.ForScope,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace_array(s:stateVars(), old, new, AST.ValueVarExpr)
                or replace_array(s:initValues(), old, new, AST.ValueExpr)
                or replace_array(s:statements(), old, new, AST.Stat)
        end
    ):Case(AST.CondScope,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace(s, old, new, s.condition, s.setCondition, AST.ValueExpr)
                or replace_array(s:statements(), old, new, AST.Stat)
        end
    ):Case(AST.Scope,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace_array(s:statements(), old, new, AST.Stat)
        end
    )

    self.m_Nodes:Case(AST.BinaryExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.leftOperand, e.setLeftOperand, AST.ValueExpr)
                or replace(e, old, new, e.rightOperand, e.setRightOperand, AST.ValueExpr)
        end
    ):Case(AST.UnaryExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.operand, e.setOperand, AST.ValueExpr)
        end
    ):Case(AST.ValueParExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.value, e.setValue, AST.ValueExpr)
        end
    ):Case(AST.ValueTableExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace_array(e:fields(), old, new, AST.ValueTableExpr.Field)
        end
    ):Case(AST.IndexAccessExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.indexee, e.setIndexee, AST.ValueExpr)
                or replace(e, old, new, e.index, e.setIndex, AST.ValueExpr)
        end
    ):Case(AST.FieldAccessExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.indexee, e.setIndexee, AST.ValueExpr)
        end
    ):Case(AST.SelfAccessExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.indexee, e.setIndexee, AST.ValueExpr)
        end
    ):Case(AST.CallExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return replace(e, old, new, e.callee, e.setCallee, AST.ValueExpr)
                or replace_array(e:args(), old, new, AST.ValueExpr)
        end
    ):Case(AST.ValueFuncExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new)
            return self:_replace(e:innerScope(), old, new)
        end
    ):Case(AST.ValueVarArgsExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new) error("not supported") end
    ):Case(AST.ValueConstExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new) error("not supported") end
    ):Case(AST.ValueVarExpr,
        ---@param old Node
        ---@param new Node
        function(e, old, new) error("not supported") end
    ):Case(AST.ValueTableExpr.Field,
        ---@param old Node
        ---@param new Node
        function(e, old, new) error("not supported") end
    )

    self.m_Nodes:Case(AST.LocalStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace(s, old, new, s.stat, s.setStat, AST.Stat)
        end
    ):Case(AST.AssignStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace_array(s:lvalues(), old, new, AST.ValueExpr)
                or replace_array(s:rvalues(), old, new, AST.ValueExpr)
        end
    ):Case(AST.CallStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace(s, old, new, s.callExpr, s.setCallExpr, AST.CallExpr)
        end
    ):Case(AST.FuncStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace(s, old, new, s.name, s.setName, AST.AccessExpr, AST.ValueVarExpr)
                or self:_replace(s:innerScope(), old, new)
        end
    ):Case(AST.ReturnStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return replace_array(s:returnValues(), old, new)
        end
    ):Case(AST.IfStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            if self:_replace(s:ifScope(), old, new) then
                return true
            elseif s:hasElse() and self:_replace(s:elseScope(), old, new) then
                return true
            elseif s:hasElseIf() then
                for i = 1, s:numElseIfCases() do
                    if self:_replace(s:elseIfScope(i), old, new) then
                        return true
                    end
                end
            end
            return false
        end
    ):Case(AST.DoStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return self:_replace(s:innerScope(), old, new)
        end
    ):Case(AST.RepeatStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return self:_replace(s:innerScope(), old, new)
        end
    ):Case(AST.WhileStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return self:_replace(s:innerScope(), old, new)
        end
    ):Case(AST.ForStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new)
            return self:_replace(s:innerScope(), old, new)
        end
    ):Case(AST.GotoStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new) error("not supported") end
    ):Case(AST.LabelStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new) error("not supported") end
    ):Case(AST.BreakStat,
        ---@param old Node
        ---@param new Node
        function(s, old, new) error("not supported") end
    ):Else(
        function(s)
            error(Class.TypeName(s) .. ": replace not implemented")
        end
    )
end

--------------------------------------------------------------------

return Cls
