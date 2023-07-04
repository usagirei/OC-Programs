local Class = require("libapp.class")
local Args = require("libapp.util.args")
local Enums = require("libapp.enums")
local Rect = require("libapp.struct.rect")
local Sort = require("libapp.util.sort")

local Super = require("libapp.gui.widget")
---@class Container : Widget
local Container = Class.NewClass(Super, "Container")

---@param w integer
---@param h integer
function Container:init(w, h)
    Super.init(self, w, h)

    ---@type Widget[]
    self.m_Children = {}
    self.m_ActiveChildren = {}
    self.m_ChildRects = setmetatable({}, { __mode = "k" })

    self:setLabel("")
    self:setLabelMode(Enums.LabelMode.Border)
    self:setLabelAlignment(Enums.Alignment.Near, Enums.Alignment.Near)
end

function Container:dispose()
    self:clearChildren()
    Super.dispose(self)
end

---@param g Graphics
function Container:beginDraw(g)
    Super.beginDraw(self, g)

    local tmp = self:activeChildren()
    for i = 1, #tmp do
        local c = tmp[i]
        c:beginDraw(g)
    end
end

---@param g Graphics
function Container:draw(g)
    Super.draw(self, g)

    local cRect = self:contentRect()
    g:pushClip(cRect)

    local tmp = self:activeChildren()
    local nChild = #tmp
    if (nChild ~= 0) then
        for i = 1, nChild do
            local child = tmp[i]
            if child:visible() then
                local ok, _ = g:clipTest(cRect)
                if ok then
                    local occluded = false
                    for j = i + 1, nChild do
                        local nextChild = tmp[j]
                        if nextChild:visible() and nextChild:occludes(child) then
                            occluded = true
                            break
                        end
                    end
                    if not occluded then
                        child:draw(g)
                    end
                end
            end
        end
    end

    g:popClip()
end

---@param g Graphics
function Container:endDraw(g)
    Super.endDraw(self, g)

    local tmp = self:activeChildren()
    self:onDrawOverlay(g)
    for i = 1, #tmp do
        local c = tmp[i]
        c:endDraw(g)
    end
end

---@class app Application
function Container:setApplication(app)
    Super.setApplication(self, app)

    local tmp = self:children()
    for i = 1, #tmp do
        local c = tmp[i]
        c:setApplication(app)
    end
end

function Container:invalidate()
    self.m_ActiveChildren = nil
    Super.invalidate(self)
end

---@return Rect
---@param child Widget
function Container:getChildRect(child)
    Args.isClass(1, child, "libapp.gui.widget")

    return self.m_ChildRects[child]
end

---@param child Widget
---@param rect Rect
---@protected
function Container:setChildRect(child, rect)
    Args.isClass(1, child, "libapp.gui.widget")
    Args.isClass(2, rect, Rect)

    self.m_ChildRects[child] = rect
end

---@param c Widget
function Container:addChild(c)
    Args.isClass(1, c, "libapp.gui.widget")

    local oldPar = c:parent() --[[@as Container]]
    if oldPar == self then
        return
    elseif oldPar ~= nil then
        local tmp = oldPar:children()
        for i = 1, #tmp do
            if tmp[i] == c then
                table.remove(tmp, i)
                break
            end
        end
        oldPar:invalidate()
    end

    table.insert(self.m_Children, c)
    c:setApplication(self:application())

    self:setChildRect(c, Rect.new(0, 0, 0, 0))
    c:setParent(self)

    self:invalidate()
    c:invalidate()

    self:invalidateLayout()
end

function Container:clearChildren()
    if #self.m_Children == 0 then
        return
    end

    for i = 1, #self.m_Children do
        local c = self.m_Children[i]
        c:dispose()
    end

    self.m_Children = {}
    self.m_ChildRects = {}

    self:invalidate()
    self:invalidateLayout()
end

---@param a Widget
---@param b Widget
local function z_less(a, b) return a:zIndex() < b:zIndex() end

---@return Widget[]
---@protected
function Container:activeChildren()
    if self.m_ActiveChildren == nil then
        local tmp = self:children()
        local active = {}
        for i = 1, #tmp do
            local c = tmp[i]
            if c:visible() then
                active[#active + 1] = c
            end
        end
        Sort.stable_sort(active, z_less)
        self.m_ActiveChildren = active
    end
    return self.m_ActiveChildren
end

---@return Widget[]
function Container:children()
    return self.m_Children
end

---

---@param kbd string # keyboard address
---@param string string # pasted string
---@param usr string # user
function Container:event_clipboard(kbd, string, usr)
    if not self:visible() then return false end
    if not self:interactive() then return false end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            local consumed = c:event_clipboard(kbd, string, usr)
            if consumed then
                return true
            end
        end
    end

    return Super.event_clipboard(self, kbd, string, usr)
end

---@param down boolean # true if key is down
---@param kbd string # keyboard address
---@param chr integer # Character codepoint
---@param code integer # Keycode
---@param usr string # user
function Container:event_key(down, kbd, chr, code, usr)
    if not self:visible() then return false end
    if not self:interactive() then return false end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            local consumed = c:event_key(down, kbd, chr, code, usr)
            if consumed then
                return true
            end
        end
    end

    return Super.event_key(self, down, kbd, chr, code, usr)
end

---@param down boolean # true if is drag (button down), false if is drop (button up)
---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Container:event_dragdrop(down, scr, p, btn, player)
    if not self:visible() then return false end
    if not self:interactive() then return false end

    local consumed = Super.event_dragdrop(self, down, scr, p, btn, player)
    if consumed then return true end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            consumed = c:event_dragdrop(down, scr, p, btn, player)
            if consumed then return true end
        end
    end

    return false
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Container:event_touch_overlay(scr, p, btn, player)
    if not self:visible() then
        self.m_LastTouchPoint = nil
        return false
    end
    if not self:interactive() then return false end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            local consumed = c:event_touch_overlay(scr, p, btn, player)
            if consumed then return true end
        end
    end

    return Super.event_touch_overlay(self, scr, p, btn, player)
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param btn integer # 0 for left button, 1 for right button
---@param player string # user
function Container:event_touch(scr, p, btn, player)
    if not self:visible() then return false end
    if not self:interactive() then return false end

    local isHit = self:hitTest(p, false)
    if not isHit then return false end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            local consumed = c:event_touch(scr, p, btn, player)
            if consumed then
                return true
            end
        end
    end

    return Super.event_touch(self, scr, p, btn, player)
end

---@param scr string # screen address
---@param p PointF # screen coordinates
---@param delta integer # scroll delta
---@param player string # user
function Container:event_scroll(scr, p, delta, player)
    if not self:visible() then return false end
    if not self:interactive() then return false end

    local tmp = self:activeChildren()

    local n = #tmp
    if n ~= 0 then
        for i = n, 1, -1 do
            local c = tmp[i]
            local consumed = c:event_scroll(scr, p, delta, player)
            if consumed then
                return true
            end
        end
    end

    return Super.event_scroll(self, scr, p, delta, player)
end

return Container
