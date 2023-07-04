local Point = require("libapp.struct.point")
local PointF = require("libapp.struct.pointf")

local lib = {}

---@param p0 Point
---@param p1 Point
---@param plot fun(p:Point)
function lib.line(p0, p1, plot)
    local x0, y0, x1, y1 = p0.x, p0.y, p1.x, p1.y

    local dx = math.abs(x1 - x0)
    local dy = -math.abs(y1 - y0)

    local xStep = x0 < x1 and 1 or -1
    local yStep = y0 < y1 and 1 or -1
    local err = dx + dy

    while true do
        plot(Point.new(x0, y0))
        if x0 == x1 and y0 == y1 then
            break
        end

        local err2 = 2 * err
        if err2 >= dy then
            if x0 == x1 then break end
            err = err + dy
            x0 = x0 + xStep
        end

        if err2 <= dx then
            if y0 == y1 then break end
            err = err + dx
            y0 = y0 + yStep
        end
    end
end

---@param rect Rect
---@param plot fun(p:Point)
function lib.ellipse(rect, plot)
    local x0, y0, x1, y1 = rect.left, rect.top, rect.right, rect.bottom

    local a = math.abs(x1 - x0)
    local b = math.abs(y1 - y0)
    local b1 = b & 1

    local dx = 4 * (1.0 - a) * b * b
    local dy = 4 * (b1 + 1) * a * a
    local err = dx + dy + (b1 * a * a)
    local err2
    y0 = y0 + (b + 1) // 2
    y1 = y0 - b1
    a = 8 * a * a
    b1 = 8 * b * b
    repeat
        plot(Point.new(x1, y0))
        plot(Point.new(x0, y0))
        plot(Point.new(x0, y1))
        plot(Point.new(x1, y1))
        err2 = 2 * err
        if (err2 <= dy) then
            y0 = y0 + 1
            y1 = y1 - 1
            dy = dy + a
            err = err + dy
        end

        if ((err2 >= dx) or (2 * err > dy)) then
            x0 = x0 + 1
            x1 = x1 - 1
            dx = dx + b1
            err = err + dx
        end
    until (x0 > x1)

    while (y0 - y1 <= b) do
        plot(Point.new(x1 + 1, y0))
        plot(Point.new(x0 - 1, y1))
        plot(Point.new(x1 + 1, y1))
        y0 = y0 + 1
        y1 = y1 - 1
    end
end

---@param p0 PointF
---@param p1 PointF
---@param p2 PointF
---@param w number
---@param plot fun(p:Point)
function lib._quadraticBezierSegment(p0, p1, p2, w, plot)
    local x0, y0 = p0.x, p0.y
    local x1, y1 = p1.x, p1.y
    local x2, y2 = p2.x, p2.y

    local sx = x2 - x1
    local sy = y2 - y1

    local xx = x0 - x1
    local yy = y0 - y1
    local xy = (xx * sy) + (yy * sx)

    local cur = (xx * sy) - (yy * sx)
    local x02 = x0 - x2
    local y02 = y0 - y2

    -- sign of gradient must not change
    assert(xx * sx <= 0 and yy * sy <= 0)

    -- not a straight line
    if (cur ~= 0 and w > 0) then
        if ((sx * sx) + (sy * sy) > (xx * xx) + (yy * yy)) then
            -- swap p0 and p2
            x0, x2 = x2, x0
            y0, y2 = y2, y0
            cur = -cur
        end

        -- differences 2nd degree
        xx = 2 * ((4 * w * sx * xx) + (x02 * x02))
        yy = 2 * ((4 * w * sy * yy) + (y02 * y02))

        sx = x0 < x2 and 1 or -1
        sy = y0 < y2 and 1 or -1

        xy = -2 * sx * sy * ((2 * w * xy) + (x02 * y02))

        -- negated curvature?
        if (cur * sx * sy < 0) then
            xx = -xx
            yy = -yy
            xy = -xy
            cur = -cur
        end

        -- differences 1st degree
        local dx = (4 * w * (x1 - x0) * sy * cur) + (xx / 2) + xy
        local dy = (4 * w * (y0 - y1) * sx * cur) + (yy / 2) + xy

        -- flat ellipse, algorithm fails
        if (w < 0.5 and dy > dx) then
            local w2 = (w + 1) / 2
            w = math.sqrt(w)
            xy = 1 / (w + 1)

            -- subdivide curve in half
            sx = math.floor(((x0 + (2 * w * x1) + x2) * xy / 2) + 0.5)
            sy = math.floor(((y0 + (2 * w * y1) + y2) * xy / 2) + 0.5)

            local pAx = math.floor((w * x1 + x0) * xy + 0.5)
            local pAy = math.floor((y1 * w + y0) * xy + 0.5)
            lib._quadraticBezierSegment(
                PointF.new(x0, y0),
                PointF.new(pAx, pAy),
                PointF.new(sx, sy),
                w2,
                plot
            )

            local pBx = math.floor((((w * x1) + x2) * xy) + 0.5)
            local pBy = math.floor((((y1 * w) + y2) * xy) + 0.5)
            lib._quadraticBezierSegment(
                PointF.new(sx, sy),
                PointF.new(pBx, pBy),
                PointF.new(x2, y2),
                w2,
                plot
            )
            return
        end

        local err = dx + dy - xy
        repeat
            -- plot curve
            local x0i = math.floor(x0 + 0.5)
            local y0i = math.floor(y0 + 0.5)
            plot(Point.new(x0i, y0i))
            if (x0 == x2 and y0 == y2) then
                -- last pixel -> curve finished
                return
            end

            -- y step
            local yTest = 2 * (err + yy) < -dy
            local xTest = 2 * err > dy
            if (yTest or (2 * err < dx)) then
                y0 = y0 + sy
                dy = dy + xy
                dx = dx + xx
                err = err + dx
            end

            -- x step
            if (xTest or (2 * err > dx)) then
                x0 = x0 + sx
                dx = dx + xy
                dy = dy + yy
                err = err + dy
            end

            -- gradient negates -> algorithm fails
        until not (dy <= xy and dx >= xy)
    end

    local x0i = math.floor(x0 + 0.5)
    local y0i = math.floor(y0 + 0.5)
    local x2i = math.floor(x2 + 0.5)
    local y2i = math.floor(y2 + 0.5)
    lib.line(
        Point.new(x0i, y0i),
        Point.new(x2i, y2i),
        plot
    )
end

local QBEZ_MI = {}
QBEZ_MI[1] = 0.2
for i = 2, 6 do
    QBEZ_MI[i] = 1 / (6 - QBEZ_MI[i - 1])
end

---@param p0 Point
---@param p1 Point
---@param p2 Point
---@param w number
---@param plot fun(p:Point)
function lib.quadraticBezier(p0, p1, p2, w, plot)
    local x0, y0 = p0.x, p0.y
    local x1, y1 = p1.x, p1.y
    local x2, y2 = p2.x, p2.y

    local tx = x0 - (2 * x1) + x2
    local ty = y0 - (2 * y1) + y2

    local hSplit = (x0 - x1) * (x2 - x1) > 0
    local vSplit = (y0 - y1) * (y2 - y1) > 0

    assert(w >= 0, "w must be larger than or equal to zero")

    -- horizontal cut at (P4)
    -- vertical cut at (P6)
    -- vertical segment is longer
    if hSplit and vSplit and (math.abs((x0 - x1) * ty) > math.abs((y0 - y1) * tx)) then
        x0, y0, x2, y2 = x2, y2, x0, y0
    end

    if hSplit then
        local t
        -- non-rational or rational case
        if (x0 == x2 or w == 1) then
            t = (x0 - x1) / tx
        else
            -- t = (2w(p0-p1)-p0+p2 ± sqrt(u)) / (2(w-1)(p0-p2))
            -- u = 4w²(p0-p1)(p2-p1) + (p0-p2)²
            local sqrt_u = math.sqrt((4 * (w * w) * (x0 - x1) * (x2 - x1)) + ((x0 - x2) * (x0 - x2)))
            local sign = (x1 < x0) and -1 or 1
            -- t at P4
            t = ((2 * w * (x0 - x1)) - x0 + x2 + (sign * sqrt_u)) / (2 * (w - 1) * (x0 - x2))
        end

        -- = P4
        -- (t²(p0-2w*p1+p2) + 2t(w*p1-p0) + p0) / v
        -- u = (2t(1-t)(w-1)+1)
        local q = 1 / ((2 * t * (1 - t) * (w - 1)) + 1)

        local x4 = ((t * t * (x0 - (2 * w * x1) + x2)) + (2 * t * ((w * x1) - x0)) + x0) * q
        local y4 = ((t * t * (y0 - (2 * w * y1) + y2)) + (2 * t * ((w * y1) - y0)) + y0) * q
        local x4i = math.floor(x4 + 0.5)
        local y4i = math.floor(y4 + 0.5)

        -- squared weight for P3
        local w3 = (t * (w - 1)) + 1
        w3 = w3 * w3 * q
        w = (((1 - t) * (w - 1)) + 1) * math.sqrt(q)

        local y3 = ((x4 - x0) * (y1 - y0) / (x1 - x0)) + y0
        local y3i = math.floor(y3 + 0.5)
        local x3i = x4i

        lib._quadraticBezierSegment(
            PointF.new(x0, y0),
            PointF.new(x3i, y3i),
            PointF.new(x4i, y4i),
            w3,
            plot
        )

        local y8 = ((y1 - y2) * (x4 - x2) / (x1 - x2)) + y2
        local y8i = math.floor(y8 + 0.5)
        local x8i = x4i

        -- P0 = P4, P1 = P8
        x0, y0 = x4i, y4i
        x1, y1 = x8i, y8i
        -- recalculate ty
        ty = y0 - (2 * y1) + y2
        vSplit = (y0 - y1) * (y2 - y1) > 0
    end

    if (vSplit) then
        local t
        -- non-rational or rational case
        if (y0 == y2 or w == 1.0) then
            t = (y0 - y1) / ty
        else
            -- t = (2w(p0-p1)-p0+p2 ± sqrt(u)) / (2(w-1)(p0-p2))
            -- u = 4w²(p0-p1)(p2-p1) + (p0-p2)²
            local sqrt_u = math.sqrt(4 * (w * w) * (y0 - y1) * (y2 - y1) + (y2 - y0) * (y2 - y0))
            local sign = y1 < y0 and -1 or 1
            -- t at P6
            t = ((2 * w * (y0 - y1)) - y0 + y2 + (sign * sqrt_u)) / (2 * (w - 1) * (y0 - y2))
        end

        -- sub-divide at t
        local q = 1 / ((2 * t * (1 - t) * (w - 1)) + 1)
        local x6 = ((t * t * (x0 - (2 * w * x1) + x2)) + (2 * t * ((w * x1) - x0)) + x0) * q
        local y6 = ((t * t * (y0 - (2 * w * y1) + y2)) + (2 * t * ((w * y1) - y0)) + y0) * q
        local x6i = math.floor(x6 + 0.5)
        local y6i = math.floor(y6 + 0.5)

        -- squared weight P5
        local w5 = (t * (w - 1)) + 1
        w5 = w5 * w5 * q
        w = (((1 - t) * (w - 1)) + 1) * math.sqrt(q)

        -- intersect P6 | P0 P1
        local x5 = ((x1 - x0) * (y6 - y0) / (y1 - y0)) + x0
        local x5i = math.floor(x5 + 0.5)
        local y5i = y6i

        lib._quadraticBezierSegment(
            PointF.new(x0, y0),
            PointF.new(x5i, y5i),
            PointF.new(x6i, y6i),
            w5,
            plot
        )

        -- intersect P7 | P1 P2
        local x7 = ((x1 - x2) * (y6 - y2) / (y1 - y2)) + x2
        local x7i = math.floor(x7 + 0.5)
        local y7i = y6i

        -- P0 = P6, P1 = P7
        x0, y0 = x6i, y6i
        x1, y1 = x7i, y7i
    end

    lib._quadraticBezierSegment(
        PointF.new(x0, y0),
        PointF.new(x1, y1),
        PointF.new(x2, y2),
        w * w,
        plot
    )
end

---@param points Point[]
---@param w number
---@param plot fun(p:Point)
function lib.quadraticBSpline(points, w, plot)
    local n = #points
    assert(n >= 3, "requires at least 3 points, received " .. n)

    local x0 = (8 * points[2].x) - (2 * points[1].x)
    local y0 = (8 * points[2].y) - (2 * points[1].y)
    local x1, y1
    local x2, y2 = points[n].x, points[n].y

    points[2].x = x0
    points[2].y = y0

    local mi
    for i = 3, n do
        mi = QBEZ_MI[i - 2]
        x0 = math.floor((8 * points[i].x) - (x0 * mi) + 0.5)
        y0 = math.floor((8 * points[i].y) - (y0 * mi) + 0.5)
        points[i].x = x0
        points[i].y = y0
    end

    x1 = math.floor((x0 - 2 * x2) / (5 - mi) + 0.5)
    y1 = math.floor((y0 - 2 * y2) / (5 - mi) + 0.5)
    for i = (n - 1), 2, -1 do
        if i <= #QBEZ_MI then
            mi = QBEZ_MI[i - 1]
        end

        x0 = math.floor((points[i].x - x1) * mi + 0.5)
        y0 = math.floor((points[i].y - y1) * mi + 0.5)
        local xA = (x0 + x1) // 2
        local yA = (y0 + y1) // 2

        lib.quadraticBezier(
            Point.new(xA, yA),
            Point.new(x1, y1),
            Point.new(x2, y2),
            w,
            plot
        )

        x1, y1 = x0, y0
        x2, y2 = xA, yA
    end

    lib.quadraticBezier(
        points[1],
        Point.new(x1, y1),
        Point.new(x2, y2),
        w,
        plot
    )
end

return lib
