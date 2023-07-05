local lib = {}

local Rect = require("libapp.struct.rect")
local Enums = require("libapp.enums")

---@param gr Graphics
---@param area Rect
---@param value number
---@param dir Direction4
---@param style ProgressBarStyle
---@param fg integer
---@param bg integer
---@return Rect rZero
---@return Rect rFrac
---@return Rect rOne
function lib.progressbar(gr, area, value, dir, style, fg, bg)
    local subStyle = lib.selectSubStyle4way(style, dir)
    local frames = #subStyle
    local invCol = false
    if type(subStyle[#subStyle]) == "boolean" then
        invCol = subStyle[#subStyle]
        frames = frames - 1
    end
    local rZero, rFrac, rOne, r = lib.calculateProgressRects(area, value, dir, frames)
    local s = subStyle[frames]
    local t = subStyle[r]
    local u = subStyle[1]
    gr:pushClip(area)
    if invCol then
        gr:setColors(bg, fg)
    else
        gr:setColors(fg, bg)
    end
    gr:fillRect(rZero, s)
    gr:fillRect(rFrac, t)
    gr:fillRect(rOne, u)
    gr:popClip()
    return rZero, rFrac, rOne
end

---@param gr Graphics
---@param rect Rect
---@param thumbSize integer
---@param scroll number
---@param dir Direction4
---@param style TrackStyle
---@param thumbFg any
---@param thumbBg any
---@param trackFg any
---@param trackBg any
function lib.trackbar(gr, rect, thumbSize, scroll, dir, style, thumbFg, thumbBg, trackFg, trackBg)
    trackFg = trackFg or thumbFg
    trackBg = trackBg or thumbBg
    local subStyle = lib.selectSubStyle4way(style, dir)
    local invCol = false
    if type(subStyle[#subStyle]) == "boolean" then
        invCol = subStyle[#subStyle]
    end
    local rZero, rThumb, rOne = lib.calculateTrackRects(rect, scroll, dir, thumbSize)
    local cZero = subStyle[1]
    local cThumb = subStyle[2]
    local cOne = subStyle[3]
    gr:pushClip(rect)
    if invCol then
        gr:setColors(trackBg, trackFg)
    else
        gr:setColors(trackFg, trackBg)
    end
    gr:fillRect(rZero, cZero)
    gr:fillRect(rOne, cOne)
    if invCol then
        gr:setColors(thumbBg, thumbFg)
    else
        gr:setColors(thumbFg, thumbBg)
    end
    gr:fillRect(rThumb, cThumb)
    gr:popClip()
    return rZero, rThumb, rOne
end

---@param rect Rect
---@param border BorderStyle
function lib.getContentRectForBorder(rect, border)
    if not border then
        return rect
    else
        local l, u, r, d = lib.getBorderSizes(border)
        return Rect.new(rect:x() + l, rect:y() + u, rect:width() - l - r, rect:height() - u - d)
    end
end

---@param border BorderStyle
---@return integer left
---@return integer up
---@return integer right
---@return integer down
function lib.getBorderSizes(border)
    if border == nil then
        return 0, 0, 0, 0
    end
    local l = #border[1] > 0 and 1 or 0
    local r = #border[2] > 0 and 1 or 0
    local u = #border[3] > 0 and 1 or 0
    local d = #border[4] > 0 and 1 or 0
    return l, u, r, d
end

---@param rect Rect
---@param border BorderStyle
function lib.getBorderRectForContent(rect, border)
    if not border then
        return rect
    else
        local l, u, r, d = lib.getBorderSizes(border)
        return Rect.new(rect:x() - l, rect:y() - u, rect:width() + l + r, rect:height() + u + d)
    end
end

---@param rect Rect
---@param cW integer
---@param cH integer
---@param xA Alignment
---@param yA Alignment
function lib.alignRect(rect, cW, cH, xA, yA)
    local x, y
    if cW <= 0 then
        x = rect.left
        cW = rect:width()
    elseif xA < 0 then
        x = rect.left
    elseif xA > 0 then
        x = rect.right - cW
    else
        x = (rect.left + rect.right - cW) // 2
    end

    if cH <= 0 then
        y = rect.top
        cH = rect:height()
    elseif yA < 0 then
        y = rect.top
    elseif yA > 0 then
        y = rect.bottom - cH
    else
        y = (rect.top + rect.bottom - cH) // 2
    end

    return Rect.new(x, y, cW, cH)
end

---@param rect Rect
---@param border? BorderStyle
---@param sz integer
---@param xA Alignment
---@param yA Alignment
---@param vert boolean
---@param padding integer
---@return Rect
---@return integer
function lib.calculateLabelRect(rect, border, sz, xA, yA, vert, padding)
    local x0 = rect.left
    local x1 = rect.right
    local y0 = rect.top
    local y1 = rect.bottom

    local x, y
    local inBorder = lib.isLabelInsideBorder(border, xA, yA, vert)
    if inBorder then
        local l, u, r, d = lib.getBorderSizes(border)
        if vert then
            y0 = y0 + u
            y1 = y1 - d
            sz = math.min(sz, y1 - y0 - padding)
        else
            x0 = x0 + l
            x1 = x1 - r
            sz = math.min(sz, x1 - x0 - padding)
        end
    end

    if vert then
        if xA < 0 then
            x = x0
        elseif xA > 0 then
            x = x1 - 1
        else
            x = (x0 + x1) // 2
        end
        if yA < 0 then
            y = y0 + padding
        elseif yA > 0 then
            y = y1 - sz - padding
        else
            y = (y0 + y1 - sz) // 2
        end
    else
        if xA == -1 then
            x = x0 + padding
        elseif xA == 1 then
            x = x1 - sz - padding
        else
            x = (x0 + x1 - sz) // 2
        end
        if yA == -1 then
            y = y0
        elseif yA == 1 then
            y = y1 - 1
        else
            y = (y0 + y1) // 2
        end
    end

    if vert then
        return Rect.new(x, y, 1, sz), sz
    else
        return Rect.new(x, y, sz, 1), sz
    end
end

---@param rect Rect
---@param value number
---@param dir Direction4
---@param frames integer
---@return Rect rZero
---@return Rect rFrac
---@return Rect rOne
---@return integer sz
function lib.calculateProgressRects(rect, value, dir, frames)
    local sZero, sFrac, sOne
    local frame
    if dir == Enums.Direction4.Right then
        local sz = rect:width()
        sZero, sFrac, sOne, frame = lib.calculateProgressSizes(value, sz, frames)
    elseif dir == Enums.Direction4.Left then
        local sz = rect:width()
        sZero, sFrac, sOne, frame = lib.calculateProgressSizes(value, sz, frames)
    elseif dir == Enums.Direction4.Up then
        local sz = rect:height()
        sZero, sFrac, sOne, frame = lib.calculateProgressSizes(value, sz, frames)
    elseif dir == Enums.Direction4.Down then
        local sz = rect:height()
        sZero, sFrac, sOne, frame = lib.calculateProgressSizes(value, sz, frames)
    else
        error(string.format("invalid direction: %d", dir))
    end
    local rZero, rFrac, rOne = lib.splitTrackRect(rect, dir, sZero, sFrac, sOne)
    return rZero, rFrac, rOne, frame
end

---@param rect Rect
---@param scroll number
---@param dir Direction4
---@param thumbSize integer
function lib.calculateTrackRects(rect, scroll, dir, thumbSize)
    local zero, one
    if dir == Enums.Direction4.Right then
        local sz = rect:width()
        zero, one = lib.calculateTrackSizes(scroll, sz, thumbSize)
    elseif dir == Enums.Direction4.Left then
        local sz = rect:width()
        zero, one = lib.calculateTrackSizes(scroll, sz, thumbSize)
    elseif dir == Enums.Direction4.Up then
        local sz = rect:height()
        zero, one = lib.calculateTrackSizes(scroll, sz, thumbSize)
    elseif dir == Enums.Direction4.Down then
        local sz = rect:height()
        zero, one = lib.calculateTrackSizes(scroll, sz, thumbSize)
    else
        error(string.format("invalid direction: %d", dir))
    end
    local rZero, rThumb, rOne = lib.splitTrackRect(rect, dir, zero, thumbSize, one)
    return rZero, rThumb, rOne
end

---@param border any
---@param xA any
---@param yA any
---@param vert any
function lib.isLabelInsideBorder(border, xA, yA, vert)
    if not border then
        return false
    end
    local r
    if vert then
        if xA < 0 then
            r = #(border[1]) > 0
        elseif xA > 0 then
            r = #(border[2]) > 0
        else
            r = false
        end
    else
        if yA < 0 then
            r = #(border[3]) > 0
        elseif yA > 0 then
            r = #(border[4]) > 0
        else
            r = false
        end
    end
    return r
end

---@param border BorderStyle
---@param decor DecoratorStyle
---@param xA Alignment
---@param yA Alignment
---@param vert boolean
function lib.selectDecorator(border, decor, xA, yA, vert)
    local inBorder = lib.isLabelInsideBorder(border, xA, yA, vert)
    local subStyle
    if inBorder then
        if vert then
            if xA < 0 then
                subStyle = lib.selectSubStyle4way(decor, Enums.Direction4.Left)
            elseif xA > 0 then
                subStyle = lib.selectSubStyle4way(decor, Enums.Direction4.Right)
            end
        else
            if yA < 0 then
                subStyle = lib.selectSubStyle4way(decor, Enums.Direction4.Up)
            elseif yA > 0 then
                subStyle = lib.selectSubStyle4way(decor, Enums.Direction4.Down)
            end
        end
    end
    if subStyle == nil then
        return "", "", false
    end
    if #subStyle ~= 3 then
        error('invalid decorator', 2)
    end
    return subStyle[1], subStyle[2], subStyle[3]
end

---@param style table
---@param dir Direction4
function lib.selectSubStyle4way(style, dir)
    local r
    if dir == Enums.Direction4.Left then
        r = style['left']
    elseif dir == Enums.Direction4.Right then
        r = style['right']
    elseif dir == Enums.Direction4.Up then
        r = style['up']
    elseif dir == Enums.Direction4.Down then
        r = style['down']
    end
    if type(r) == "string" then
        r = style[r]
    end
    if type(r) ~= "table" then
        error('invalid style: ' .. type(r), 2)
    end
    return r
end

---@param style table
---@param dir Direction2
function lib.selectSubStyle2way(style, dir)
    local s
    if dir == Enums.Direction2.Horizontal then
        s = style['left'] or style['right']
    elseif dir == Enums.Direction2.Vertical then
        s = style['up'] or style['down']
    end
    if type(s) == "string" then
        s = style[s]
    end
    if type(s) ~= "table" then
        error('invalid style', 2)
    end
    return s
end

---@param cSize integer
---@param vSize integer
---@param sSize integer
---@return integer thumbSize
---@return number scrollStep
function lib.calculateScrollParams(cSize, vSize, sSize)
    local thumb = math.max(1, math.floor((sSize * vSize / cSize) + 0.5))
    local step = (cSize - vSize) / (vSize - thumb)
    return thumb, step
end

---@param fVal number
---@param sz integer
---@param frames integer
---@return integer szZero
---@return integer szFrac
---@return integer szOne
---@return integer fracIdx
function lib.calculateProgressSizes(fVal, sz, frames)
    local fSz = fVal * sz
    local iSz = math.floor(fSz)

    local x = fSz - iSz
    local y = frames - 1
    local fracIdx = math.floor(x * y + 0.5)

    local szFrac = 1
    local szZero = iSz
    local szOne = sz - iSz - szFrac
    if szZero >= sz then
        szZero = sz - szFrac
    end
    if szOne < 0 then
        szOne = 0
        fracIdx = y
    end
    return szZero, szFrac, szOne, fracIdx + 1
end

---@param scroll number
---@param size integer
---@param thumb integer
function lib.calculateTrackSizes(scroll, size, thumb)
    local rem = (size - thumb)
    local fVal = scroll * rem
    local zero = math.floor(fVal + 0.5)
    local one = rem - zero
    return zero, one
end

---@param rect Rect
---@param dir Direction4
---@param zero integer
---@param frac integer
---@param one integer
function lib.splitTrackRect(rect, dir, zero, frac, one)
    local total = zero + frac + one
    local rZero, rFrac, rOne, sz

    if dir == Enums.Direction4.Right then
        local h = rect:height()
        sz = rect:width()
        rZero = Rect.new(rect.left, rect.top, zero, h)
        rFrac = Rect.new(rZero.right, rect.top, frac, h)
        rOne = Rect.new(rFrac.right, rect.top, one, h)
    elseif dir == Enums.Direction4.Left then
        local h = rect:height()
        sz = rect:width()
        rZero = Rect.new(rect.right - zero, rect.top, zero, h)
        rFrac = Rect.new(rZero.left - frac, rect.top, frac, h)
        rOne = Rect.new(rFrac.left - one, rect.top, one, h)
    elseif dir == Enums.Direction4.Up then
        local w = rect:width()
        sz = rect:height()
        rZero = Rect.new(rect.left, rect.bottom - zero, w, zero)
        rFrac = Rect.new(rect.left, rZero.top - frac, w, frac)
        rOne = Rect.new(rect.left, rFrac.top - one, w, one)
    elseif dir == Enums.Direction4.Down then
        local w = rect:width()
        sz = rect:height()
        rZero = Rect.new(rect.left, rect.top, w, zero)
        rFrac = Rect.new(rect.left, rZero.bottom, w, frac)
        rOne = Rect.new(rect.left, rFrac.bottom, w, one)
    else
        error(string.format("invalid direction: %d", dir))
    end
    if (total ~= sz) then
        error(string.format("sum of sizes is different than area size: %d+%d+%d = %d != %d", zero, frac, one, total, sz))
    end
    return rZero, rFrac, rOne
end

return lib
