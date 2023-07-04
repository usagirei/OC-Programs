local Class = require("libpack.class")

---@alias notnil table|string|number|function

---@class Solver
local Cls = Class.NewClass()
Cls.Sentinel = {}

---@class OperatorData
---@field bin boolean
---@field rassoc boolean
---@field prec integer
---@field op string

---@param apply fun(bin,op,v1,v2):any # function that applies the operator `op` to the operands `v1` and `v2`, returns the new value
---@return Solver
function Cls.new(apply)
    return Class.NewObj(Cls, apply)
end

---@param apply fun(bin,op,v1,v2):any
function Cls:init(apply)
    self.m_Ops = {
        [true] = {},
        [false] = {}
    }
    self.m_Apply = apply
end

---@param bin boolean
---@param op string
---@param prec integer
---@param rassoc boolean
function Cls:setOperator(bin, op, prec, rassoc)
    self.m_Ops[bin][op] = { bin = bin, op = op, prec = prec, rassoc = rassoc }
end

---@param bin boolean
---@param op string|table
---@return OperatorData
function Cls:getOperator(bin, op)
    if type(op) ~= "string" then op = tostring(op) end
    assert(self.m_Ops[bin][op], "no such operator")
    return self.m_Ops[bin][op]
end

---@private
---@param a OperatorData
---@param b OperatorData
function Cls:cmpOperator(a, b)
    if a.bin and b.bin then
        return (a.prec > a.prec) or (not a.rassoc and a.prec == a.prec)
    elseif a.bin and not b.bin then
        return (a.prec >= b.prec)
    end
    return false
end

---@param opStack OperatorData[]
---@param valStack any[]
---@return boolean
function Cls:popOp(opStack, valStack)
    local opStr, opVal = table.unpack(opStack[#opStack])
    if opStr.op == Cls.Sentinel then return false end

    local r
    if opStr.bin then
        local rhs = self:popVal(valStack)
        local lhs = self:popVal(valStack)
        r = self.m_Apply(true, opVal, lhs, rhs)
    else
        local val = self:popVal(valStack)
        r = self.m_Apply(false, opVal, val, nil)
    end
    opStack[#opStack] = nil
    self:pushVal(valStack, r)
    return true
end

---@param opStack OperatorData[]
---@param valStack notnil[]
---@param opData OperatorData
function Cls:pushOp(opStack, valStack, opData, opVal)
    while self:cmpOperator(opStack[#opStack], opData) do self:popOp(opStack, valStack) end
    opStack[#opStack + 1] = { opData, opVal }
end

---@param valStack notnil[]
---@param val notnil
function Cls:pushVal(valStack, val)
    valStack[#valStack + 1] = val
end

---@param valStack notnil[]
---@return notnil
function Cls:popVal(valStack)
    local val = valStack[#valStack]
    valStack[#valStack] = nil
    return val
end

---@param next fun(what:'b'|'u'|'v'):boolean,any # function that returns `true` if the next token is a `b`inary operator, `u`nary operator, or `v`alue and the token itself, or `false` otherwise
function Cls:solve(next)
    ---@type Expr[]
    local vals = {}
    local ops = {
        { { bin = false, op = Cls.Sentinel, prec = -1, rassoc = false }, Cls.Sentinel }
    }

    local ok, res, opStr
    ::unary::
    ok, res = next("u")
    if not ok then
        ok, res = next("v")
        if not ok then return end
        self:pushVal(vals, res)
    else
        opStr = tostring(res)
        self:pushOp(ops, vals, self:getOperator(false, opStr), res)
        goto unary
    end

    ::binary::
    ok, res = next("b")
    if not ok then
        goto resolve
    end
    opStr = tostring(res)
    self:pushOp(ops, vals, self:getOperator(true, opStr), res)
    goto unary

    ::resolve::
    while self:popOp(ops, vals) do
        -- Nothing
    end

    return vals[#vals]
end

return Cls
