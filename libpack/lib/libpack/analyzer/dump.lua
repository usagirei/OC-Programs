local AST = require("libpack.ast")
local Class = require("libpack.class")
local Switch = require("libpack.switch")
local TokenWriter = require("libpack.tokenizer.writer")
local KWD = require("libpack.parser.syntax").Keywords
local SYM = require("libpack.parser.syntax").Symbols
local TOK = require("libpack.tokenizer.type")

---@class LuaDumper
local Cls = Class.NewClass(nil, "LuaDumper")

---@param indent? string
---@param pretty? boolean
function Cls.new(indent, pretty)
    return Class.NewObj(Cls, indent, pretty)
end

---@param indent? string
---@param pretty? boolean
function Cls:init(indent, pretty)
    self.m_Writer = TokenWriter.new(indent, pretty)
    self:createSwitch()
end

---@param pretty? boolean
---@param indent? string
function Cls:reset(pretty, indent)
    self.m_Writer:clear()
    self.m_Writer:setPretty(pretty)
    self.m_Writer:setIndent(indent)
end

function Cls:tostring()
    return self.m_Writer:tostring()
end

---@param node Chunk|Stat|Expr
function Cls:dump(node)
    self.m_Nodes:Match(node, self.m_Writer)
end

---@private
---@param ... Stat
function Cls:_dumpStat(...)
    local function f(x, y, ...)
        if not x then return end
        self.m_Nodes:Match(x, self.m_Writer)
        if y then self.m_Writer:hardLF() end
        f(y, ...)
    end
    f(...)
    return self.m_Writer
end

---@private
---@param ... Expr
function Cls:_dumpExpr(...)
    local function f(x, y, ...)
        if not x then return end
        self.m_Nodes:Match(x, self.m_Writer)
        if y then self.m_Writer:token(SYM.Comma, "p", "y") end
        f(y, ...)
    end
    f(...)
    return self.m_Writer
end

--------------------------------------------------------------------

--------------------------------------------------------------------

---@private
function Cls:createSwitch()
    ---@param t string|StringView
    ---@param p? "y"|"n"|"p"|"q"
    ---@param e? "y"|"n"|"p"|"q"
    local _TOKN_ = function(t, p, e) return self.m_Writer:token(t, p or "y", e or "n") end
    ---@param sta Stat
    local _STAT_ = function(sta) self:_dumpStat(sta) end
    ---@param stats Stat[]
    local _STAX_ = function(stats) self:_dumpStat(table.unpack(stats)) end
    ---@param exp Expr
    local _EXPR_ = function(exp) self:_dumpExpr(exp) end
    ---@param exprs Expr[]
    local _EXPX_ = function(exprs) self:_dumpExpr(table.unpack(exprs)) end
    local _SOFT_ = function() return self.m_Writer:softLF() end
    local _HARD_ = function() return self.m_Writer:hardLF() end
    local _PSHI_ = function() return self.m_Writer:pushIndent() end
    local _POPI_ = function() return self.m_Writer:popIndent() end

    self.m_Nodes = Switch.new()

    self.m_Nodes:Case(AST.Chunk,
        function(e)
            local U = table.unpack
            self:_dumpStat(U(e:body()))
        end
    )

    self.m_Nodes:Case(AST.BinaryExpr,
        function(e)
            _EXPR_(e:leftOperand())
            if e:operator():isType(TOK.Symbol) then
                _TOKN_(e:operator(), "p", "q")
            else
                _TOKN_(e:operator())
            end
            _EXPR_(e:rightOperand())
        end
    ):Case(AST.UnaryExpr,
        function(e)
            if e:operator():isType(TOK.Symbol) then
                _TOKN_(e:operator(), "n", "q")
            else
                _TOKN_(e:operator())
            end
            _EXPR_(e:operand())
        end
    ):Case(AST.ValueConstExpr,
        function(e)
            _TOKN_(e:token())
        end
    ):Case(AST.ValueVarExpr,
        function(e)
            _TOKN_(e:name())
        end
    ):Case(AST.ValueParExpr,
        function(e)
            _TOKN_(SYM.OpenPar, "n", "n")
            _EXPR_(e:value())
            _TOKN_(SYM.ClosePar, "p", "y")
        end
    ):Case(AST.ValueFuncExpr,
        function(e)
            _TOKN_(KWD.Function, "n")
            _TOKN_(SYM.OpenPar, "n", "y")
            local args = e:args()
            if e:isVarArg() then
                ---@type ValueExpr[]
                args = { table.unpack(args) }
                args[#args + 1] = e:varArg()
            end
            _EXPX_(args)
            _TOKN_(SYM.ClosePar, "y", "y")
            if #e:body() > 0 then
                _SOFT_()
                _PSHI_()
                _STAX_(e:body())
                _SOFT_()
                _POPI_()
            end
            _TOKN_(KWD.End)
        end
    ):Case(AST.ValueTableExpr,
        function(e)
            local inline = (#e:fields() < 2)
            if #e:fields() > 0 then
                _TOKN_(SYM.OpenCurly, "p", "q")
                if not inline then
                    _SOFT_()
                    _PSHI_()
                end
                for i, j in pairs(e:fields()) do
                    local last = i == #e:fields()
                    local k = j:key()
                    local v = j:value()
                    if k then
                        if Class.IsInstance(k, AST.ValueExpr) then
                            _TOKN_(SYM.OpenBracket, "n")
                            _EXPR_(k --[[@as ValueExpr]])
                            _TOKN_(SYM.CloseBracket, "p", "y")
                        else
                            _TOKN_(k --[[@as Token]])
                        end
                        _TOKN_(SYM.Assign, "p", "q")
                    end
                    _EXPR_(v)
                    if not last then
                        _TOKN_(SYM.Comma, "p", "y")
                    end
                    if not inline then
                        _SOFT_()
                    end
                end
                if not inline then
                    _SOFT_()
                    _POPI_()
                end
                _TOKN_(SYM.CloseCurly, "p", "q")
            else
                _TOKN_(SYM.OpenCurly, "n")
                _TOKN_(SYM.CloseCurly, "p")
            end
        end
    ):Case(AST.ValueVarArgsExpr,
        function(e)
            _TOKN_(e:token())
        end
    ):Case(AST.IndexAccessExpr,
        function(e)
            _EXPR_(e:indexee())
            _TOKN_(SYM.OpenBracket, "n", "y")
            _EXPR_(e:index())
            _TOKN_(SYM.CloseBracket, "p", "y")
        end
    ):Case(AST.FieldAccessExpr,
        function(e)
            _EXPR_(e:indexee())
            _TOKN_(SYM.Dot, "n", "y")
            _TOKN_(e:index())
        end
    ):Case(AST.SelfAccessExpr,
        function(e)
            _EXPR_(e:indexee())
            _TOKN_(SYM.Colon, "n", "y")
            _TOKN_(e:index())
        end
    ):Case(AST.CallExpr,
        function(e)
            _EXPR_(e:callee())
            _TOKN_(SYM.OpenPar, "n", "y")
            _EXPX_(e:args())
            _TOKN_(SYM.ClosePar, "p", "y")
        end
    ):Else(
        function(stat)
            error(Class.TypeName(stat) .. ": dump not implemented")
        end
    )

    self.m_Nodes:Case(AST.DoStat,
        function(s)
            _TOKN_(KWD.Do)
            _SOFT_()
            _PSHI_()
            _STAX_(s:body())
            _SOFT_()
            _POPI_()
            _TOKN_(KWD.End)
            _HARD_()
        end
    ):Case(AST.RepeatStat,
        function(s)
            _TOKN_(KWD.Repeat)
            _SOFT_()
            _PSHI_()
            _STAX_(s:body())
            _SOFT_()
            _POPI_()
            _TOKN_(KWD.Until)
            _EXPR_(s:condition())
            _HARD_()
        end
    ):Case(AST.WhileStat,
        function(s)
            _TOKN_(KWD.While)
            _EXPR_(s:condition())
            _TOKN_(KWD.Do)
            _SOFT_()
            _PSHI_()
            _STAX_(s:body())
            _SOFT_()
            _POPI_()
            _TOKN_(KWD.End)
            _HARD_()
        end
    ):Case(AST.LocalStat,
        function(s)
            _TOKN_(KWD.Local)
            _STAT_(s:stat())
            _HARD_()
        end
    ):Case(AST.AssignStat,
        function(s)
            _EXPX_(s:lvalues())
            if #s:rvalues() > 0 then
                _TOKN_(SYM.Assign, "p", "q")
                _EXPX_(s:rvalues())
            end
            _HARD_()
        end
    ):Case(AST.CallStat,
        function(s)
            _EXPR_(s:callExpr())
            _HARD_()
        end
    ):Case(AST.FuncStat,
        function(s)
            _TOKN_(KWD.Function)
            _EXPR_(s:name())
            _TOKN_(SYM.OpenPar, "n", "y")
            local args = s:args()
            if s:isVarArg() then
                ---@type ValueExpr[]
                args = { table.unpack(args) }
                args[#args + 1] = s:varArg()
            end
            _EXPX_(args)
            _TOKN_(SYM.ClosePar, "n", "y")
            _SOFT_()
            _PSHI_()
            _STAX_(s:body())
            _SOFT_()
            _POPI_()
            _TOKN_(KWD.End)
            _HARD_()
        end
    ):Case(AST.IfStat,
        function(s)
            _TOKN_(KWD.If)
            _EXPR_(s:ifCondition())
            _TOKN_(KWD.Then)
            _SOFT_()
            _PSHI_()
            _STAX_(s:ifBody())
            _SOFT_()
            _POPI_()
            if s:hasElseIf() then
                for i = 1, s:numElseIfCases() do
                    _TOKN_(KWD.ElseIf)
                    _EXPR_(s:elseIfCondition(i))
                    _TOKN_(KWD.Then)
                    _SOFT_()
                    _PSHI_()
                    _STAX_(s:elseIfBody(i))
                    _SOFT_()
                    _POPI_()
                end
            end
            if s:hasElse() then
                _TOKN_(KWD.Else)
                _SOFT_()
                _PSHI_()
                _STAX_(s:elseBody())
                _SOFT_()
                _POPI_()
            end
            _TOKN_(KWD.End)
            _HARD_()
        end
    ):Case(AST.ForStat,
        function(s)
            _TOKN_(KWD.For)
            _EXPX_(s:stateVars())
            if s:isForIn() then
                _TOKN_(KWD.In)
            else
                _TOKN_(SYM.Assign, "p", "q")
            end
            _EXPX_(s:initValues())
            _TOKN_(KWD.Do)
            _SOFT_()
            _PSHI_()
            _STAX_(s:body())
            _SOFT_()
            _POPI_()
            _TOKN_(KWD.End)
            _HARD_()
        end
    ):Case(AST.GotoStat,
        function(s)
            _TOKN_(KWD.Goto)
            _TOKN_(s:label())
            _HARD_()
        end
    ):Case(AST.LabelStat,
        function(s)
            _TOKN_(SYM.Label, "n", "y")
            _TOKN_(s:label())
            _TOKN_(SYM.Label, "p", "y")
            _HARD_()
        end
    ):Case(AST.BreakStat,
        function(s)
            _TOKN_(KWD.Break)
            _HARD_()
        end
    ):Case(AST.ReturnStat,
        function(s)
            _TOKN_(KWD.Return)
            if #s:returnValues() > 0 then
                _EXPX_(s:returnValues())
            end
            _HARD_()
        end
    ):Else(
        function(s)
            error(Class.TypeName(s) .. ": dump not implemented")
        end
    )
end

--------------------------------------------------------------------

return Cls
