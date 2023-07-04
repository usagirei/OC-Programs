local Class = require("libapp.class")
local Args = require("libapp.util.args")

---@class Point : Object
---@operator add(Point):Point
---@operator sub(Point):Point
---@operator unm(Point):Point
local Point = Class.NewClass(nil, "Point")

---@param x integer
---@param y integer
---@return Point
function Point.new(x, y) 
	return Class.NewObj(Point, x, y) 
end

---@param x integer
---@param y integer
---@private
function Point:init(x, y)
	Args.isInteger(1, x)
	Args.isInteger(2, y)

	self.x = x
	self.y = y
end

---@param lhs Point
---@param rhs Point
---@return Point
function Point.prototype.__add(lhs, rhs)
	Args.isClass(1, lhs, Point)
	Args.isClass(2, rhs, Point)

	return Point.new(lhs.x + rhs.x, lhs.y + rhs.y)
end

---@param lhs Point
---@param rhs Point
---@return Point
function Point.prototype.__sub(lhs, rhs)
	Args.isClass(1, lhs, Point)
	Args.isClass(2, rhs, Point)

	return Point.new(lhs.x - rhs.x, lhs.y - rhs.y)
end

---@param lhs Point
---@param rhs Point
function Point.prototype.__eq(lhs, rhs)
	Args.isClass(1, lhs, Point)
	Args.isClass(2, rhs, Point)

	return (lhs.x == rhs.x) and (lhs.y == rhs.y)
end

function Point.prototype.__unm(rhs)
	return Point.new(
		0 - rhs.x,
		0 - rhs.y
	)
end

return Point
