local KWD = require("libpack.parser.syntax").Keywords
local SYM = require("libpack.parser.syntax").Symbols
local OPS = require("libpack.parser.syntax").Operators
local TOK = require("libpack.tokenizer.type")
local AST = require("libpack.ast")
local Class = require("libpack.class")

local util = {}

-----------------------------------------------------------

---@param id string
---@param stats Stat[]
---@param data ScopeData
---@param names ValueVarExpr[]
---@param va ValueVarArgsExpr
function util.funcScope(id, stats, data, names, va)
    local scope = AST.FuncScope.new()
    scope:setArgs(names)
    scope:setStatements(stats)
    if va then
        scope:setVarArg(va)
    end
    return scope
end

---@param id string
---@param stats Stat[]
---@param data ScopeData
---@param names ValueVarExpr[]
---@param init ValueVarArgsExpr
function util.forScope(id, stats, data, names, init)
    return AST.ForScope.new():setStateVars(names):setInitExprs(init):setStatements(stats)
end

---@param id string
---@param stats Stat[]
---@param data ScopeData
---@param cond ValueExpr[]
function util.condScope(id, stats, data, cond)
    return AST.CondScope.new():setCondition(cond):setStatements(stats)
end

---@param parser LuaParser
function util.chunk(parser)
    local start = parser:reader():token()
    local id = parser:scopeBegin(true, false)
    local stats = util.statList(parser)
    local scope = parser:scopeEnd(id, stats)

    local rv = AST.Chunk.new()
    rv:setInnerScope(scope)
    parser:setSourceInfo(rv, start)

    --assert(parser:reader():eof())
    return rv
end

---@param parser LuaParser
---@return Stat[]
function util.statList(parser)
    local stmts = {}
    while true do
        local stmt = util.stat(parser)
        if not stmt then break end
        stmts[#stmts + 1] = stmt
    end
    return stmts
end

---@param parser LuaParser
---@return Expr[]
function util.exprList(parser)
    local tbl = {}
    while true do
        local expr = util.expr(parser)
        if not expr then
            break
        end
        tbl[#tbl + 1] = expr
        if not parser:symbol(SYM.Comma, true) then
            break
        end
    end
    return tbl
end

---@return ValueExpr?
function util.expr(parser)
    if parser.m_Tokenizer:eof() then return nil end

    ---@param what "u"|"b"|"v"
    local function nextToken(what)
        if what == "v" then
            local val = util.expr_value(parser)
            return val ~= nil, val
        else
            for _, dat in ipairs(OPS) do
                local bu, sk, op = table.unpack(dat)
                if bu == what then
                    local tk
                    if sk == "s" then
                        tk = parser:symbol(op, true)
                    else
                        tk = parser:keyword(op, true)
                    end
                    if tk then
                        return true, tk
                    end
                end
            end
            return false
        end
    end

    return parser.m_Solver:solve(nextToken)
end

---@return Node?
function util.stat(parser)
    if parser.m_Tokenizer:eof() then return nil end
    while parser:match(";", TOK.Symbol, true) do
        -- Ignore
    end

    ---@param keyword? string
    ---@param doFn fun(...):Stat?
    local function caseKywd(keyword, doFn, ...)
        if keyword and not parser:keyword(keyword, true) then return nil end
        return doFn(...)
    end

    ---@param symb string
    ---@param doFn fun(...):Stat?
    local function caseSymb(symb, doFn, ...)
        if not parser:symbol(symb, true) then return nil end
        return doFn(...)
    end

    local function caseElse(doFn, ...)
        return doFn(...)
    end

    local rv = nil
        or caseKywd(KWD.Local, util.stat_local, parser)
        or caseKywd(KWD.Function, util.stat_func, parser)
        or caseKywd(KWD.For, util.stat_for, parser)
        or caseKywd(KWD.If, util.stat_if, parser)
        or caseKywd(KWD.Repeat, util.stat_repeat, parser)
        or caseKywd(KWD.While, util.stat_while, parser)
        or caseKywd(KWD.Do, util.stat_do, parser)
        or caseKywd(KWD.Goto, util.stat_goto, parser)
        or caseKywd(KWD.Break, util.stat_break, parser)
        or caseSymb(SYM.Label, util.stat_label, parser)
        or caseKywd(KWD.Return, util.stat_return, parser)
        or caseElse(util.stat_call_assign, parser)

    return rv
end

-----------------------------------------------------------

---@param parser LuaParser
---@return boolean, string
function util.scopeGetBreak(parser)
    for i = 1, parser:scopeDepth() do
        local scope = parser:scopeGet(i)
        if not scope then break end
        if scope:canBreak() then
            return true, scope:id()
        end
    end
    return false, ''
end

---@param parser LuaParser
---@return boolean, string
function util.scopeGetReturn(parser)
    for i = 1, parser:scopeDepth() do
        local scope = parser:scopeGet(i)
        if not scope then break end
        if scope:isClosure() then
            return true, scope:id()
        end
    end
    return false, ''
end

-----------------------------------------------------------

---@param parser LuaParser
---@return FuncScope
function util.parseFunc(parser)
    local scopeId = parser:scopeBegin(true, false)

    parser:symbol(SYM.OpenPar, true)
    local names, va = util.nameList(parser, true, true)
    parser:symbol(SYM.ClosePar, true)

    local stats = util.statList(parser)
    parser:keyword(KWD.End)
    local body = parser:scopeEnd(scopeId, stats, util.funcScope, names, va)

    return body --[[@as FuncScope]]
end

---@param parser LuaParser
---@param isDecl boolean
---@param allowVarArgs boolean
---@return ValueVarExpr[] args
---@return ValueVarArgsExpr vaToken
function util.nameList(parser, isDecl, allowVarArgs)
    local tbl = {}
    local vaToken = nil
    while true do
        if allowVarArgs and parser:symbol(SYM.VarArg, true) then
            vaToken = AST.ValueVarArgsExpr.new():setToken(parser:lastMatch())
            break
        elseif parser:identifier(nil, true) then
            tbl[#tbl + 1] = AST.ValueVarExpr.new():setName(parser:lastMatch()):setDecl(isDecl)
        else
            break
        end
        if not parser:symbol(SYM.Comma, true) then break end
    end
    return tbl, vaToken
end

-----------------------------------------------------------


---@param parser LuaParser
---@return ValueExpr?
function util.expr_value(parser)
    return nil
        or util.expr_table(parser)
        or util.expr_name_index_call(parser)
        or util.expr_func(parser)
        or util.expr_const(parser)
        or util.expr_varags(parser)
end

---@param parser LuaParser
---@return ValueExpr?
function util.expr_const(parser)
    local constVal = nil
        or parser:keyword(KWD.Nil, true)
        or parser:keyword(KWD.True, true)
        or parser:keyword(KWD.False, true)
        or parser:number(true)
        or parser:string(true)
    if constVal then
        local rv = AST.ValueConstExpr.new():setValue(parser:lastMatch())
        return parser:setSourceInfo(rv, constVal)
    end

    return nil
end

---@param parser LuaParser
function util.call_args(parser)
    -- String Arg
    if parser:string(true) then
        local str = parser:lastMatch()
        local val = AST.ValueConstExpr.new():setValue(str)
        return { val }
    end

    -- Table Arg
    local tbl = util.expr_table(parser)
    if tbl then
        return { tbl }
    end

    -- Regular Arg List
    if parser:symbol(SYM.OpenPar, true) then
        local args = util.exprList(parser)
        parser:symbol(SYM.ClosePar)
        return args
    end

    return nil
end

---@param parser LuaParser
---@return ValueExpr?
function util.expr_name_index_call(parser)
    local value
    if parser:symbol(SYM.OpenPar, true) then
        local openPar = parser:lastMatch()
        local expr = util.expr(parser)
        assert(expr, "Expected Expression")
        parser:symbol(SYM.ClosePar)
        local rv = AST.ValueParExpr.new():setValue(expr)
        parser:setSourceInfo(rv, openPar)
        value = rv
    else
        if parser:identifier(nil, true) then
            local name = parser:lastMatch()
            local rv = AST.ValueVarExpr.new():setName(name):setDecl(false)
            parser:setSourceInfo(rv, name)
            value = rv
        else
            return nil
        end
    end

    while true do
        if parser:symbol(SYM.OpenBracket, true) then
            -- Index
            local open = parser:lastMatch()
            local index = util.expr(parser)
            assert(index, "Expected Expression")
            parser:symbol(SYM.CloseBracket)
            value = AST.IndexAccessExpr.new():setIndex(index):setIndexee(value)
            parser:setSourceInfo(value, open)
        elseif parser:symbol(SYM.Dot, true) then
            -- Field Access
            local dot = parser:lastMatch()
            local name = parser:identifier(nil)
            value = AST.FieldAccessExpr.new():setIndex(name):setIndexee(value)
            parser:setSourceInfo(value, dot)
        elseif parser:symbol(SYM.Colon, true) then
            -- Self Call
            local col = parser:lastMatch()
            local index = parser:identifier(nil)
            value = AST.SelfAccessExpr.new():setIndex(index):setIndexee(value)
            parser:setSourceInfo(value, col)

            local cBeg = parser:reader():token()
            local args = util.call_args(parser)
            assert(args, "expected function arguments")
            value = AST.CallExpr.new():setCallee(value):setArgs(args)
            parser:setSourceInfo(value, cBeg)
        else
            -- Regular Call?
            local cBeg = parser:reader():token()
            local args = util.call_args(parser)
            if not args then
                break
            end
            value = AST.CallExpr.new():setCallee(value):setArgs(args)
            parser:setSourceInfo(value, cBeg)
        end
    end

    return value
end

---@param parser LuaParser
---@return ValueExpr?
function util.expr_table(parser)
    ---@return TableField?
    local function field()
        if parser:symbol(SYM.OpenBracket, true) then
            local open = parser:lastMatch()
            local key = util.expr(parser)
            assert(key, "expected key")
            parser:symbol(SYM.CloseBracket)

            parser:symbol(SYM.Assign)
            local value = util.expr(parser)
            assert(value, "expected value")

            local rv = AST.ValueTableExpr.Field.new(key, value)
            parser:setSourceInfo(rv, open)
            return rv
        else
            local value = util.expr(parser)
            if not value then return nil end

            if parser:symbol(SYM.Assign, true) then
                assert(Class.IsInstance(value, AST.ValueVarExpr), "expected identifier before = ")
                local key = (value --[[@as ValueVarExpr]]):name()

                value = util.expr(parser)
                assert(value, "expected value")

                local rv = AST.ValueTableExpr.Field.new(key, value)

                return parser:setSourceInfo(rv, key)
            else
                local rv = AST.ValueTableExpr.Field.new(nil, value)
                rv:setSourceInfo(value:getSourceInfo())
                return rv
            end
        end
    end

    ---@return TableField[]
    local function fieldList()
        local tbl = {}
        while true do
            local f = field()
            if not f then break end
            tbl[#tbl + 1] = f
            if not parser:symbol(SYM.Comma, true) then break end
        end
        return tbl
    end

    local openTbl = parser:symbol(SYM.OpenCurly, true)
    if openTbl then
        local fields = fieldList()
        parser:symbol(SYM.CloseCurly)
        local rv = AST.ValueTableExpr.new():setFields(fields)
        parser:setSourceInfo(rv, openTbl)
        return rv
    end
    return nil
end

---@param parser LuaParser
---@return ValueExpr?
function util.expr_varags(parser)
    local sym = parser:symbol(SYM.VarArg, true)
    if sym then
        local rv = AST.ValueVarArgsExpr.new():setToken(sym)
        parser:setSourceInfo(rv, sym)
        return rv
    end
    return nil
end

---@param parser LuaParser
---@return ValueExpr?
function util.expr_func(parser)
    local fnKwd = parser:keyword(KWD.Function, true)
    if fnKwd then
        local scope = util.parseFunc(parser)
        local rv = AST.ValueFuncExpr.new():setInnerScope(scope)
        return parser:setSourceInfo(rv, fnKwd)
    end
    return nil
end

-----------------------------------------------------------


---@param parser LuaParser
---@return LocalStat|FuncStat
function util.stat_local(parser)
    if parser:keyword(KWD.Function, true) then
        local fnKeyword = parser:lastMatch()
        local token = parser:identifier()
        local name = AST.ValueVarExpr.new():setName(token):setDecl(true)
        local scope = util.parseFunc(parser)
        local fun = AST.FuncStat.new():setName(name):setInnerScope(scope)
        local loc = AST.LocalStat.new():setStat(fun)
        parser:setSourceInfo(fun, fnKeyword)
        return loc
    else
        local names = util.nameList(parser, true, false)
        if #names ~= 0 then
            local values
            if parser:symbol(SYM.Assign, true) then
                values = util.exprList(parser)
                assert(#values > 0, "expected values")
            else
                values = {}
            end
            local ass = AST.AssignStat.new():setLValues(names):setRValues(values)
            local loc = AST.LocalStat.new():setStat(ass)
            return parser:setSourceInfo(loc, names[1]:name())
        end
    end
    error("expected function or variables")
end

---@param parser LuaParser
---@return FuncStat?
function util.stat_func(parser)
    local funcKw = parser:lastMatch()

    local name, var

    local rv = AST.FuncStat.new()
    do
        local token = parser:identifier(nil)
        var = AST.ValueVarExpr.new():setName(token):setDecl(true)
        parser:setSourceInfo(var, token)
    end
    name = var
    
    while parser:symbol(SYM.Dot, true) do
        var:setDecl(false)
        local dot = parser:lastMatch()
        local index = parser:identifier(nil)
        name = AST.FieldAccessExpr.new():setIndex(index):setIndexee(name)
        parser:setSourceInfo(name, dot)
    end

    if parser:symbol(SYM.Colon, true) then
        var:setDecl(false)
        local colon = parser:lastMatch()
        local index = parser:identifier(nil)
        name = AST.SelfAccessExpr.new():setIndex(index):setIndexee(name)
        parser:setSourceInfo(name, colon)
    end

    local scope = util.parseFunc(parser)
    rv:setInnerScope(scope):setName(name)
    parser:setSourceInfo(name, funcKw)

    return rv
end

---@param parser LuaParser
---@return ForStat?
function util.stat_for(parser)
    local forKwd = parser:lastMatch()
    local names = util.nameList(parser, true, false)

    local stat, initExpr
    local sId = parser:scopeBegin(false, true)
    if parser:symbol(SYM.Assign, true) then
        -- for var=start, stop, [step] do ... end
        assert(#names == 1, "for = expects a single loop variable")
        stat = AST.ForStat.new(false)
        initExpr = util.exprList(parser)
        assert(#initExpr >= 2 and #initExpr <= 3, "for = expects 2 or 3 init variables")
    elseif parser:keyword(KWD.In, true) then
        --- for ... in ... do ... end
        stat = AST.ForStat.new(true)
        initExpr = util.exprList(parser)
    else
        error("expected = or in")
    end

    parser:keyword(KWD.Do)
    local stats = util.statList(parser)
    parser:keyword(KWD.End)
    local scope = parser:scopeEnd(sId, stats, util.forScope, names, initExpr)

    stat:setInnerScope(scope --[[@as ForScope]])

    return parser:setSourceInfo(stat, forKwd)
end

---@param parser LuaParser
---@return RepeatStat
function util.stat_repeat(parser)
    local stat = AST.RepeatStat.new()

    local rptKwd = parser:lastMatch()
    local sId = parser:scopeBegin(false, true)
    local stats = util.statList(parser)
    parser:keyword(KWD.Until)
    local cond = util.expr(parser)
    local scope = parser:scopeEnd(sId, stats, util.condScope, cond) --[[@as CondScope]]
    stat:setInnerScope(scope)

    return parser:setSourceInfo(stat, rptKwd)
end

---@param parser LuaParser
---@return WhileStat
function util.stat_while(parser)
    local stat = AST.WhileStat.new()

    local rptKwd = parser:lastMatch()
    local sId = parser:scopeBegin(false, true)
    local cond = util.expr(parser)
    parser:keyword(KWD.Do)
    local stats = util.statList(parser)
    local scope = parser:scopeEnd(sId, stats, util.condScope, cond) --[[@as CondScope]]
    stat:setInnerScope(scope)
    parser:keyword(KWD.End)

    return parser:setSourceInfo(stat, rptKwd)
end

---@param parser LuaParser
---@return IfStat
function util.stat_if(parser)
    local ifKwd = parser:lastMatch()

    local stat = AST.IfStat.new()
    do
        local sId = parser:scopeBegin(false, false)
        local cond = util.expr(parser)
        assert(cond, "expr expected")
        parser:keyword(KWD.Then)
        local stats = util.statList(parser)
        local ifScope = parser:scopeEnd(sId, stats, util.condScope, cond) --[[@as CondScope]]
        stat:setIfScope(ifScope)
    end
    do
        local elifScopes = {}
        while parser:keyword(KWD.ElseIf, true) do
            local sId = parser:scopeBegin(false, false)
            local cond = util.expr(parser)
            assert(cond, "expr expected")
            parser:keyword(KWD.Then)
            local stats = util.statList(parser)
            local elifScope = parser:scopeEnd(sId, stats, util.condScope, cond) --[[@as CondScope]]
            elifScopes[#elifScopes + 1] = elifScope
        end
        stat:setElseIfScopes(elifScopes)
    end
    do
        if parser:keyword(KWD.Else, true) then
            local sId = parser:scopeBegin(false, false)
            local stats = util.statList(parser)
            local elseScope = parser:scopeEnd(sId, stats)
            stat:setElseScope(elseScope)
        end
    end
    parser:keyword(KWD.End)

    return parser:setSourceInfo(stat, ifKwd)
end

---@param parser LuaParser
---@return DoStat?
function util.stat_do(parser)
    local doKwd = parser:lastMatch()
    local sId = parser:scopeBegin(false, false)
    local stats = util.statList(parser)
    parser:keyword(KWD.End)
    local scope = parser:scopeEnd(sId, stats) --[[@as Scope]]
    local rv = AST.DoStat.new()
    rv:setInnerScope(scope)

    return parser:setSourceInfo(rv, doKwd)
end

---@param parser LuaParser
---@return LabelStat?
function util.stat_label(parser)
    local labelTok = parser:lastMatch()

    local lbl = parser:identifier(nil)
    parser:symbol(SYM.Label)
    local rv = AST.LabelStat.new():setLabel(lbl)

    return parser:setSourceInfo(rv, labelTok)
end

---@param parser LuaParser
---@return GotoStat?
function util.stat_goto(parser)
    local gotoKwd = parser:lastMatch()
    local lbl = parser:identifier(nil)
    local rv = AST.GotoStat.new():setLabel(lbl)

    return parser:setSourceInfo(rv, gotoKwd)
end

---@param parser LuaParser
---@return BreakStat?
function util.stat_break(parser)
    local breakKwd = parser:lastMatch()
    local canbreak, tgtScope = util.scopeGetBreak(parser)
    assert(canbreak, "not inside a break-able scope")
    local rv = AST.BreakStat.new()

    return parser:setSourceInfo(rv, breakKwd)
end

---@param parser LuaParser
---@return ReturnStat?
function util.stat_return(parser)
    local retKwd = parser:lastMatch()
    local canReturn, tgtScope = util.scopeGetReturn(parser)
    assert(canReturn, "not inside a return-able scope")
    local values = util.exprList(parser)
    local rv = AST.ReturnStat.new():setReturnValues(values)
    return parser:setSourceInfo(rv, retKwd)
end

---@param parser LuaParser
---@return CallStat|AssignStat?
function util.stat_call_assign(parser)
    local start = parser:lastMatch()
    local var = util.expr_name_index_call(parser)
    if not var then return nil end
    if Class.IsInstance(var, AST.CallExpr) then
        local expr = var --[[@as CallExpr]]
        local rv = AST.CallStat.new():setCallExpr(expr)
        return parser:setSourceInfo(rv, start)
    else
        local vars = {}
        while true do
            assert(Class.IsInstance(var, AST.ValueExpr), "expected a value-expression")
            assert(var:isLValue(), "expected an l-value expression")
            vars[#vars + 1] = var
            if not parser:symbol(SYM.Comma, true) then break end
            var = util.expr(parser) --[[@as ValueExpr]]
        end
        local eq = parser:symbol(SYM.Assign)
        local vals = util.exprList(parser)

        local rv = AST.AssignStat.new():setLValues(vars):setRValues(vals)

        return parser:setSourceInfo(rv, eq)
    end
end

return util
