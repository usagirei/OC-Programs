local Class = require("libpack.class")
local Super = require("libpack.ast.node")

-----------------------------------------------------------

---@class Stat : Node
local Cls = Class.NewClass(Super, "stat")

function Cls:validate()
    Super.validate(self)
    return self
end

return Cls
