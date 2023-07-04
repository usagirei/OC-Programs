local Class = require("libapp.class")
local Args = require("libapp.util.args")
local Point = require("libapp.struct.point")
local PointF = require("libapp.struct.pointf")

---@class Rect : Object
---@operator mul(Rect) : Rect
---@operator add(Rect) : Rect
local Rect = Class.NewClass(nil, "Rect")

---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@return Rect
function Rect.new(x, y, w, h)
	return Class.NewObj(Rect, x, y, w, h)
end

---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@private
function Rect:init(x, y, w, h)
	Args.isInteger(1, x)
	Args.isInteger(2, y)
	Args.isInteger(3, w)
	Args.isInteger(4, h)

	self.left = x
	self.right = x + w
	self.top = y
	self.bottom = y + h
end

---@return integer
function Rect:x()
	return self.left
end

---@return integer
function Rect:y()
	return self.top
end

---@return integer
function Rect:width()
	return self.right - self.left
end

---@return integer
function Rect:height()
	return self.bottom - self.top
end

---@return Point
function Rect:tl()
	return Point.new(self.left, self.top)
end

---@return Point
function Rect:tr()
	return Point.new(self.right, self.top)
end

---@return Point
function Rect:bl()
	return Point.new(self.left, self.bottom)
end

---@return Point
function Rect:br()
	return Point.new(self.right, self.bottom)
end

---@param left integer
---@param right? integer
---@param up? integer
---@param down? integer
---@return Rect
function Rect:inflated(left, up, right, down)
	up = up or left
	right = right or left
	down = down or up

	local x0 = self.left - left
	local x1 = self.right + right
	local y0 = self.top - up
	local y1 = self.bottom + down

	return Rect.new(x0, y0, x1 - x0, y1 - y0)
end

---@param r Rect
---@param p Point
function Rect.offset(r, p)
	return Rect.new(r.left + p.x, r.top + p.y, r:width(), r:height())
end

---@param other Rect
function Rect:intersects(other)
	if (self.left == self.right) or (self.top == self.bottom) or (other.left == other.right) or (other.top == other.bottom) then
		return false
	end

	if (self.left > other.right) or (other.left > self.right) then
		return false
	end

	if (self.top > other.bottom) or (other.top > self.bottom) then
		return false
	end

	return true
end

---@param other Rect | Point | PointF
function Rect:contains(other)
	Args.isAnyClass(1, other, false, Rect, Point, PointF)

	if Class.IsInstance(other, Point) then
		local p = other --[[@as Point]]
		return (p.x >= self.left) and
			(p.x < self.right) and
			(p.y >= self.top) and
			(p.y < self.bottom)
	elseif Class.IsInstance(other, PointF) then
		local p = other --[[@as PointF]]
		return (p.x >= self.left) and
			(p.x < self.right) and
			(p.y >= self.top) and
			(p.y < self.bottom)
	elseif Class.IsInstance(other, Rect) then
		local r = other --[[@as Rect]]
		return (r.left >= self.left) and
			(r.right <= self.right) and
			(r.top >= self.top) and
			(r.bottom <= self.bottom)
	end
end

---@param lhs Rect
---@param rhs Rect
function Rect.combine(lhs, rhs)
	Args.isClass(1, lhs, Rect)
	Args.isClass(2, rhs, Rect)

	local l = math.min(lhs.left, rhs.left)
	local r = math.max(lhs.right, rhs.right)
	local t = math.min(lhs.top, rhs.top)
	local b = math.max(lhs.bottom, rhs.bottom)
	local w = math.max(r - l, 0)
	local h = math.max(b - t, 0)

	return Rect.new(l, t, w, h)
end

---@param lhs Rect
---@param rhs Rect
function Rect.intersection(lhs, rhs)
	Args.isClass(1, lhs, Rect)
	Args.isClass(2, rhs, Rect)

	local l = math.max(lhs.left, rhs.left)
	local r = math.min(lhs.right, rhs.right)
	local t = math.max(lhs.top, rhs.top)
	local b = math.min(lhs.bottom, rhs.bottom)
	local w = math.max(r - l, 0)
	local h = math.max(b - t, 0)

	return Rect.new(l, t, w, h)
end

Rect.prototype.__mul = Rect.intersection
Rect.prototype.__add = Rect.combine

return Rect
