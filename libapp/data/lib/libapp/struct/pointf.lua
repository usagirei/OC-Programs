local Class = require("libapp.class")
local Args = require("libapp.util.args")

---@class PointF : Object
---@operator add(PointF):PointF
---@operator sub(PointF):PointF
---@operator unm(PointF):PointF
local PointF = Class.NewClass(nil, "PointF")

---@param x number
---@param y number
---@return PointF
function PointF.new(x, y) 
	return Class.NewObj(PointF, x, y) 
end

---@param x number
---@param y number
---@private
function PointF:init(x, y)
	Args.isValue(1, x, Args.ValueType.Number)
	Args.isValue(2, y, Args.ValueType.Number)

	self.x = x
	self.y = y
end

---@param lhs PointF
---@param rhs PointF
---@return PointF
function PointF.prototype.__add(lhs, rhs)
	Args.isClass(1, lhs, PointF)
	Args.isClass(2, rhs, PointF)

	return PointF.new(lhs.x + rhs.x, lhs.y + rhs.y)
end

---@param lhs PointF
---@param rhs PointF
---@return PointF
function PointF.prototype.__sub(lhs, rhs)
	Args.isClass(1, lhs, PointF)
	Args.isClass(2, rhs, PointF)

	return PointF.new(lhs.x - rhs.x, lhs.y - rhs.y)
end

---@param lhs PointF
---@param rhs PointF
function PointF.prototype.__eq(lhs, rhs)
	Args.isClass(1, lhs, PointF)
	Args.isClass(2, rhs, PointF)

	return (lhs.x == rhs.x) and (lhs.y == rhs.y)
end

function PointF.prototype.__unm(rhs)
	return PointF.new(
		0 - rhs.x,
		0 - rhs.y
	)
end

return PointF
