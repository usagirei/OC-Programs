local AST = require("libpack.ast")
local Class = require("libpack.class")
local Switch = require("libpack.switch")
local TokenWriter = require("libpack.tokenizer.writer")
local KWD = require("libpack.parser.syntax").Keywords
local SYM = require("libpack.parser.syntax").Symbols
local TOK = require("libpack.tokenizer.type")
local ARR = require("libpack.array")

---@generic T : Node
---@alias VisitCallback fun(node:T)

---@class LuaVisitor
local Cls = Class.NewClass(nil, "LuaVisitor")

function Cls.new()
    return Class.NewObj(Cls)
end

function Cls:init()
    self:initNodes()
end

---@param root Node
---@param onEnter? VisitCallback<Node>
---@param onExit? VisitCallback<Node>
function Cls:visit(root, onEnter, onExit)
    self.m_Nodes:Match(root, function(node, isEnter)
        if isEnter and onEnter then
            onEnter(node)
        elseif not isEnter and onExit then
            onExit(node)
        end
    end)
end

---@param node Node
---@param func fun(node:Node,isEnter:boolean)
function Cls:_visit(node, func)
    func(node, true)
    self.m_Nodes:Match(node, func)
    func(node, false)
end

---@private
function Cls:initNodes()
    self.m_Nodes = Switch.new()

    ---@param node Node[]
    ---@param func VisitCallback
    local function visit(node, func)
        if not node then return end
        self:_visit(node, func)
    end

    ---@param nodes Node[]
    ---@param func VisitCallback
    local function visit_arr(nodes, func)
        assert(ARR.is_array(nodes))
        for i, j in ipairs(nodes) do visit(j, func) end
    end


    self.m_Nodes:Case(AST.Chunk,
        ---@param func VisitCallback
        function(c, func)
            visit(c:innerScope(), func)
        end
    )

    self.m_Nodes:Case(AST.FuncScope,
        ---@param func VisitCallback
        function(c, func)
            visit_arr(c:args(), func)
            visit(c:varArg(), func)
            visit_arr(c:statements(), func)
        end
    ):Case(AST.ForScope,
        ---@param func VisitCallback
        function(c, func)
            visit_arr(c:stateVars(), func)
            visit_arr(c:initValues(), func)
            visit_arr(c:statements(), func)
        end
    ):Case(AST.CondScope,
        ---@param func VisitCallback
        function(c, func)
            visit(c:condition(), func)
            visit_arr(c:statements(), func)
        end
    ):Case(AST.Scope,
        ---@param func VisitCallback
        function(c, func)
            visit_arr(c:statements(), func)
        end
    )

    self.m_Nodes:Case(AST.BinaryExpr,
        ---@param func VisitCallback
        function(c, func)
            visit(c:leftOperand(), func)
            visit(c:rightOperand(), func)
        end
    ):Case(AST.UnaryExpr,
        ---@param func VisitCallback
        function(c, func)
            visit(c:operand(), func)
        end
    ):Case(AST.ValueConstExpr,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.ValueVarExpr,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.ValueParExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:value(), func)
        end
    ):Case(AST.ValueFuncExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.ValueTableExpr,
        ---@param func VisitCallback
        function(e, func)
            visit_arr(e:fields(), func)
        end
    ):Case(AST.ValueTableExpr.Field,
        ---@param func VisitCallback
        function(e, func)
            if Class.IsInstance(e:key(), AST.Node) then
                visit(e:key() --[[@as Node]], func)
            end
            visit(e:value(), func)
        end
    ):Case(AST.ValueVarArgsExpr,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.IndexAccessExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:indexee(), func)
            visit(e:index(), func)
        end
    ):Case(AST.FieldAccessExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:indexee(), func)
        end
    ):Case(AST.SelfAccessExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:indexee(), func)
        end
    ):Case(AST.CallExpr,
        ---@param func VisitCallback
        function(e, func)
            visit(e:callee(), func)
            visit_arr(e:args(), func)
        end
    )

    self.m_Nodes:Case(AST.DoStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.RepeatStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.WhileStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.ForStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.IfStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:ifScope(), func)
            visit_arr(e:elseIfScopes(), func)
            visit(e:elseScope(), func)
        end
    ):Case(AST.LocalStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:stat(), func)
        end
    ):Case(AST.AssignStat,
        ---@param func VisitCallback
        function(e, func)
            visit_arr(e:lvalues(), func)
            visit_arr(e:rvalues(), func)
        end
    ):Case(AST.CallStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:callExpr(), func)
        end
    ):Case(AST.FuncStat,
        ---@param func VisitCallback
        function(e, func)
            visit(e:name(), func)
            visit(e:innerScope(), func)
        end
    ):Case(AST.GotoStat,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.LabelStat,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.BreakStat,
        ---@param func VisitCallback
        function(e, func) end
    ):Case(AST.ReturnStat,
        ---@param func VisitCallback
        function(e, func)
            visit_arr(e:returnValues(), func)
        end
    ):Else(
        function(s)
            error(Class.TypeName(s) .. ": visit not implemented")
        end
    )
end

return Cls
