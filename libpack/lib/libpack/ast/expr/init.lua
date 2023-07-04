local Class = require("libpack.class")
local Super = require("libpack.ast.node")

-----------------------------------------------------------

---@class Expr : Node
local Cls = Class.NewClass(Super, "expr")


function Cls:init()
    Super.init(self)
end

function Cls:validate()
    Super.validate(self)
    return self
end

return Cls
