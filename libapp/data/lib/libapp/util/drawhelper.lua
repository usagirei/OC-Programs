local lib = {}

local Rect = require("libapp.struct.rect")
local Enums = require("libapp.enums")

local c = require("libapp.styles")
function lib.progressbar(e, f, g, h, i, j, k)
    local l = lib.selectSubStyle4way(i, h)
    local m = #l
    local n = false
    if type(l[#l]) == "boolean" then
        n = l[#l]
        m = m - 1
    end
    local o, p, q, r = lib.calculateProgressRects(f, g, h, m)
    local s = l[m]
    local t = l[r]
    local u = l[1]
    e:pushClip(f)
    if n then
        e:setColors(k, j)
    else
        e:setColors(j, k)
    end
    e:fillRect(o, s)
    e:fillRect(p, t)
    e:fillRect(q, u)
    e:popClip()
    return o, p, q
end

function lib.trackbar(f, g, h, i, j, k, l, m, n, o)
    n = n or l
    o = o or m
    local p = lib.selectSubStyle4way(k, j)
    local q = false
    if type(p[#p]) == "boolean" then
        q = p[#p]
    end
    local r, s, t = lib.calculateTrackRects(g, i, j, h)
    local u = p[1]
    local v = p[2]
    local w = p[3]
    f:pushClip(g)
    if q then
        f:setColors(o, n)
    else
        f:setColors(n, o)
    end
    f:fillRect(r, u)
    f:fillRect(t, w)
    if q then
        f:setColors(m, l)
    else
        f:setColors(l, m)
    end
    f:fillRect(s, v)
    f:popClip()
    return r, s, t
end

function lib.getContentRectForBorder(g, h)
    if not h then
        return g
    else
        local i = #h[1] > 0 and 1 or 0
        local j = #h[2] > 0 and 1 or 0
        local k = #h[3] > 0 and 1 or 0
        local l = #h[4] > 0 and 1 or 0
        return Rect.new(g:x() + i, g:y() + k, g:width() - i - j, g:height() - k - l)
    end
end

function lib.getBorderSizes(h)
    if h == nil then
        return 0, 0, 0, 0
    end
    local i = #h[1] > 0 and 1 or 0
    local j = #h[2] > 0 and 1 or 0
    local k = #h[3] > 0 and 1 or 0
    local l = #h[4] > 0 and 1 or 0
    return i, k, j, l
end

function lib.getBorderRectForContent(i, j)
    if not j then
        return i
    else
        local k, l, m, n = lib.getBorderSizes(j)
        return Rect.new(i:x() - k, i:y() - l, i:width() + k + m, i:height() + l + n)
    end
end

function lib.alignRect(j, k, l, m, n)
    local o, p
    if k <= 0 then
        o = j.left
        k = j:width()
    elseif m < 0 then
        o = j.left
    elseif m > 0 then
        o = j.right - k
    else
        o = (j.left + j.right - k) // 2
    end
    if l <= 0 then
        p = j.top
        l = j:height()
    elseif n < 0 then
        p = j.top
    elseif n > 0 then
        p = j.bottom - l
    else
        p = (j.top + j.bottom - l) // 2
    end
    return Rect.new(o, p, k, l)
end

function lib.calculateLabelRect(k, l, m, n, o, p, q)
    local r = k.left
    local s = k.right
    local t = k.top
    local u = k.bottom
    local v, w
    local x = lib.isLabelInsideBorder(l, n, o, p)
    if x then
        local y, z, A, B = lib.getBorderSizes(l)
        if p then
            t = t + z
            u = u - B
            m = math.min(m, u - t - q)
        else
            r = r + y
            s = s - A
            m = math.min(m, s - r - q)
        end
    end
    if p then
        if n < 0 then
            v = r
        elseif n > 0 then
            v = s - 1
        else
            v = (r + s) // 2
        end
        if o < 0 then
            w = t + q
        elseif o > 0 then
            w = u - m - q
        else
            w = (t + u - m) // 2
        end
    else
        if n == -1 then
            v = r + q
        elseif n == 1 then
            v = s - m - q
        else
            v = (r + s - m) // 2
        end
        if o == -1 then
            w = t
        elseif o == 1 then
            w = u - 1
        else
            w = (t + u) // 2
        end
    end
    if p then
        return Rect.new(v, w, 1, m), m
    else
        return Rect.new(v, w, m, 1), m
    end
end

function lib.calculateProgressRects(l, m, n, o)
    local p, q, r
    local s
    if n == Enums.Direction4.Right then
        local t = l:width()
        p, q, r, s = lib.calculateProgressSizes(m, t, o)
    elseif n == Enums.Direction4.Left then
        local u = l:width()
        p, q, r, s = lib.calculateProgressSizes(m, u, o)
    elseif n == Enums.Direction4.Up then
        local v = l:height()
        p, q, r, s = lib.calculateProgressSizes(m, v, o)
    elseif n == Enums.Direction4.Down then
        local w = l:height()
        p, q, r, s = lib.calculateProgressSizes(m, w, o)
    else
        error(string.format("invalid direction: %d", n))
    end
    local x, y, z = lib.splitTrackRect(l, n, p, q, r)
    return x, y, z, s
end

function lib.calculateTrackRects(m, n, o, p)
    local q, r
    if o == Enums.Direction4.Right then
        local s = m:width()
        q, r = lib.calculateTrackSizes(n, s, p)
    elseif o == Enums.Direction4.Left then
        local t = m:width()
        q, r = lib.calculateTrackSizes(n, t, p)
    elseif o == Enums.Direction4.Up then
        local u = m:height()
        q, r = lib.calculateTrackSizes(n, u, p)
    elseif o == Enums.Direction4.Down then
        local v = m:height()
        q, r = lib.calculateTrackSizes(n, v, p)
    else
        error(string.format("invalid direction: %d", o))
    end
    local w, x, y = lib.splitTrackRect(m, o, q, p, r)
    return w, x, y
end

function lib.isLabelInsideBorder(n, o, p, q)
    if not n then
        return false
    end
    local r
    if q then
        if o < 0 then
            r = #(n[1]) > 0
        elseif o > 0 then
            r = #(n[2]) > 0
        else
            r = false
        end
    else
        if p < 0 then
            r = #(n[3]) > 0
        elseif p > 0 then
            r = #(n[4]) > 0
        else
            r = false
        end
    end
    return r
end

function lib.selectDecorator(o, p, q, r, s)
    local t = lib.isLabelInsideBorder(o, q, r, s)
    local u
    if t then
        if s then
            if q < 0 then
                u = lib.selectSubStyle4way(p, Enums.Direction4.Left)
            elseif q > 0 then
                u = lib.selectSubStyle4way(p, Enums.Direction4.Right)
            end
        else
            if r < 0 then
                u = lib.selectSubStyle4way(p, Enums.Direction4.Up)
            elseif r > 0 then
                u = lib.selectSubStyle4way(p, Enums.Direction4.Down)
            end
        end
    end
    if u == nil then
        return "", "", false
    end
    if #u ~= 3 then
        error('invalid decorator', 2)
    end
    return u[1], u[2], u[3]
end

function lib.selectSubStyle4way(p, q)
    local r
    if q == Enums.Direction4.Left then
        r = p['left']
    elseif q == Enums.Direction4.Right then
        r = p['right']
    elseif q == Enums.Direction4.Up then
        r = p['up']
    elseif q == Enums.Direction4.Down then
        r = p['down']
    end
    if type(r) == "string" then
        r = p[r]
    end
    if type(r) ~= "table" then
        error('invalid style: ' .. type(r), 2)
    end
    return r
end

function lib.selectSubStyle2way(q, r)
    local s
    if r == Enums.Direction2.Horizontal then
        s = q['left'] or q['right']
    elseif r == Enums.Direction2.Vertical then
        s = q['up'] or q['down']
    end
    if type(s) == "string" then
        s = q[s]
    end
    if type(s) ~= "table" then
        error('invalid style', 2)
    end
    return s
end

function lib.calculateScrollParams(r, s, t)
    local u = math.max(1, math.floor((t * s / r) + 0.5))
    local v = (r - s) / (s - u)
    return u, v
end

function lib.calculateProgressSizes(s, t, u)
    local v = s * t
    local w = math.floor(v)
    local x = v - w
    local y = u - 1
    local z = math.floor(x * y + 0.5)
    local A = 1
    local B = w
    local C = t - w - A
    if B >= t then
        B = t - A
    end
    if C < 0 then
        C = 0
        z = u - 1
    end
    return B, A, C, z + 1
end

function lib.calculateTrackSizes(t, u, v)
    local w = (u - v)
    local x = t * w
    local y = math.floor(x + 0.5)
    local z = y
    local A = w - z
    return z, A
end

function lib.splitTrackRect(u, v, w, x, y)
    local z = w + x + y
    local A, B, C, D
    if v == Enums.Direction4.Right then
        local E = u:height()
        D = u:width()
        A = Rect.new(u.left, u.top, w, E)
        B = Rect.new(A.right, u.top, x, E)
        C = Rect.new(B.right, u.top, y, E)
    elseif v == Enums.Direction4.Left then
        local F = u:height()
        D = u:width()
        A = Rect.new(u.right - w, u.top, w, F)
        B = Rect.new(A.left - x, u.top, x, F)
        C = Rect.new(B.left - y, u.top, y, F)
    elseif v == Enums.Direction4.Up then
        local G = u:width()
        D = u:height()
        A = Rect.new(u.left, u.bottom - w, G, w)
        B = Rect.new(u.left, A.top - x, G, x)
        C = Rect.new(u.left, B.top - y, G, y)
    elseif v == Enums.Direction4.Down then
        local H = u:width()
        D = u:height()
        A = Rect.new(u.left, u.top, H, w)
        B = Rect.new(u.left, A.bottom, H, x)
        C = Rect.new(u.left, B.bottom, H, y)
    else
        error(string.format("invalid direction: %d", v))
    end
    if (z ~= D) then
        error(string.format("sum of sizes is different than area size: %d+%d+%d = %d != %d", w, x, y, z, D))
    end
    return A, B, C
end

return lib
