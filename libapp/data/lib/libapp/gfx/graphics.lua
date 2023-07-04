local component = require("component")
local term = require("term")
local unicode = require("unicode")

local hashlib = require("libapp.util.hash")

local Args = require("libapp.util.args")
local Class = require("libapp.class")
local Rect = require("libapp.struct.rect")
local Point = require("libapp.struct.point")
local PointF = require("libapp.struct.pointf")
local Rasterizer = require("libapp.gfx.rasterizer")
local Text = require("libapp.util.text")
local DrawHelper = require("libapp.util.drawhelper")
local Enums = require("libapp.enums")

---@class Graphics : Object
local Graphics = Class.NewClass(nil, "Graphics")

Graphics.ShapeKind = {
	Line = 0,
	Ellipse = 1,
	QBez = 2,
	QBSpline = 3
}

---@class PreparedText
---@field textRect Rect
---@field lines TextRun[]

Graphics.ShapeCache = setmetatable({}, { __mode = "v" })

-- The fromCol and fromRow of bitblt arguments are swapped around on older versions of OpenComputers / OCEmu <br>
-- set this to true so top and left are passed instead of left and top as source coordinates  <br>
-- See: https://github.com/MightyPirates/OpenComputers/issues/3609 <br>
-- See: https://github.com/MightyPirates/OpenComputers/commit/d3d887f22fb0444aae4bca7abce8648eddd7c1b5

Graphics.BitBlitAxisSwap = false
do
	local gpu = component.gpu
	local buf = gpu.allocateBuffer(2,2)
	gpu.setActiveBuffer(buf)
	gpu.set(1,1,"x0")
	gpu.set(1,2,"1x")
	gpu.bitblt(0,1,1,1,1,buf,1,2)
	gpu.setActiveBuffer(0)
	local c = gpu.get(1,1)
	Graphics.BitBlitAxisSwap = c == '0'
end

--- Creates a new Graphics Object
---@param gpu table? # GPU component
---@param dstBuf integer? # GPU Buffer. Defaults to screen (0)
---@param area Rect? # Area inside the destination buffer to work in. Defautls to the whole buffer
---@param direct? boolean # pass true to work directly into the destination buffer, or false to create a new area sized buffer to work in then blit. Defaults to false <br />
---@return Graphics
function Graphics.new(gpu, dstBuf, area, direct) 
	return Class.NewObj(Graphics, gpu, dstBuf, area, direct) 
end

---@param gpu? table
---@param dstBuf? integer
---@param area? Rect
---@param direct? boolean
---@private
function Graphics:init(gpu, dstBuf, area, direct)
	--TODO: Use Typed GPU comp class
	Args.isValue(1, gpu, Args.ValueType.Table, true)
	Args.isInteger(2, dstBuf, true)
	Args.isClass(3, area, Rect, true)
	Args.isValue(4, direct, Args.ValueType.Boolean, true)

	if gpu == nil then
		gpu = component.gpu
	end
	if dstBuf == nil then
		dstBuf = 0
	end
	if area == nil then
		local sx, sy = gpu.getBufferSize(dstBuf)
		area = Rect.new(0, 0, sx, sy)
	end
	if direct == nil then
		direct = dstBuf ~= 0
	end
	self.m_Gpu = gpu

	self.m_ClipStack = {}
	self.m_Area = area
	self.m_DstBuf = dstBuf
	self.m_DrawBuf = direct and dstBuf or gpu.allocateBuffer(area:width(), area:height())
	self.m_DirtyRect = area
end

--- Releases the allocated internal buffer and all internal state
function Graphics:dispose()
	if self.m_DrawBuf ~= self.m_DstBuf then
		self.m_Gpu.freeBuffer(self.m_DrawBuf)
		self.m_DrawBuf = -1
		self.m_DstBuf = -1
		self.m_Area = nil
		self.m_DirtyRect = nil
		self.m_ClipStack = nil
		self.m_Gpu = nil
	end
end

function Graphics:gpu()
	return self.m_Gpu
end

function Graphics:screen()
	local scrAddr = self.m_Gpu.getScreen()
	return component.proxy(scrAddr)
end

---@return Rect
function Graphics:area()
	return self.m_Area
end

--- Marks a buffer area as dirty, so it'll be blitted on the destination
---@param rect? Rect # Area to mark as dirty, or nil for the whole buffer
---@see Graphics.flush
function Graphics:setDirtyRect(rect)
	Args.isClass(1, rect, Rect, true)

	rect = rect or self:area()
	if self.m_DirtyRect == nil then
		self.m_DirtyRect = rect
	else
		self.m_DirtyRect = self.m_DirtyRect + rect
	end
end

--- Gets the currently dirty area
---@return Rect
function Graphics:dirtyRect()
	return self.m_DirtyRect
end

--- Width of drawing area
---@return integer
function Graphics:width()
	return self.m_Area:width()
end

--- Height of drawing area
---@return integer
function Graphics:height()
	return self.m_Area:height()
end

--- Current clip area
---@return Rect
function Graphics:clip()
	if #self.m_ClipStack == 0 then
		return self.m_Area
	else
		return self.m_ClipStack[#self.m_ClipStack]
	end
end

--- Resets the clip area stack
function Graphics:resetClip()
	self.m_ClipStack = {}
end

---Pops a clip rect from the stack
---@return Rect
function Graphics:popClip()
	local rv = self.m_ClipStack[#self.m_ClipStack]
	self.m_ClipStack[#self.m_ClipStack] = nil
	return rv
end

---Pushes a clip rect onto the stack
---@param r Rect
function Graphics:pushClip(r)
	Args.isClass(1, r, Rect, true)

	local visible, r1 = self:clipTest(r)
	self.m_ClipStack[#self.m_ClipStack + 1] = r1
	return visible
end

---Sets active foreground and background color
---@param fg? integer # nil to keep current
---@param bg? integer # nil to keep current
function Graphics:setColors(fg, bg)
	Args.isInteger(1, fg, true)
	Args.isInteger(2, bg, true)

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	if bg ~= nil then
		self.m_Gpu.setBackground(bg)
	end
	if fg ~= nil then
		self.m_Gpu.setForeground(fg)
	end
end

--- Gets active foreground and background colors
---@return integer foreground
---@return integer background
function Graphics:colors()
	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	return self.m_Gpu.getForeground(), self.m_Gpu.getBackground()
end

--- Flushes the buffer to the screen, or destination buffer, when not working in `direct` mode
---@param sync boolean # if true a full refresh will be done regardless of dirty area, will only update the dirty area otherwise
---@return boolean # true if destination buffer was updated
---@see Graphics.setDirty
function Graphics:flush(sync)
	Args.isValue(1, sync, Args.ValueType.Boolean)

	local dr = self.m_DirtyRect
	self.m_DirtyRect = nil
	if self.m_DstBuf == self.m_DrawBuf then
		return false
	end

	if sync then
		local dstRect = self:area()
		self.m_Gpu.bitblt(
			self.m_DstBuf,
			dstRect:x() + 1, dstRect:y() + 1,
			dstRect:width(), dstRect:height(),
			self.m_DrawBuf,
			1, 1
		)
		return true
	elseif dr ~= nil then
		local dstRect = self:area()
		local clip = dr * dstRect
		local ok = clip:width() ~= 0 and clip:height() ~= 0
		if ok then
			if Graphics.BitBlitAxisSwap then
				self.m_Gpu.bitblt(self.m_DstBuf,
					clip.left + 1, clip.top + 1,
					clip:width(), clip:height(),
					self.m_DrawBuf,
					dr.top + 1, dr.left + 1
				)
			else
				self.m_Gpu.bitblt(
					self.m_DstBuf,
					clip.left + 1, clip.top + 1,
					clip:width(), clip:height(),
					self.m_DrawBuf,
					dr.left + 1, dr.top + 1
				)
			end
		end
		return true
	end
	return false
end

--- Clears the buffer
function Graphics:clear()
	local area = self:clip()
	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	self.m_Gpu.fill(area:x() + 1, area:y() + 1, area:width(), area:height(), ' ')
end

---Tests if a point is inside the active clip area, or a rectangle overlaps with it
---@param x Rect|Point # Point or Rectangle
---@return boolean # `true` if check passed the test
---@return Rect # intersection of `x` with clip area, or the clip area itself if `x` was a Point
function Graphics:clipTest(x)
	Args.isAnyClass(1, x, false, Rect, Point)

	local r0 = self:clip()
	if Class.IsInstance(x, Rect) then
		local r1 = r0 * x
		return (r1:width() > 0 and r1:height() > 0), r1
	elseif Class.IsInstance(x, Point) then
		local p = x --[[@as Point]]
		return r0:contains(p), r0
	elseif Class.IsInstance(x, PointF) then
		local p = x --[[@as PointF]]
		return r0:contains(p), r0
	end
	error('invalid argument: r - ' .. type(x))
end

---Fills a rectangle with the specified character
---@param rect Rect # fill rect
---@param str string # character to fill with
function Graphics:fillRect(rect, str)
	Args.isClass(1, rect, Rect)
	Args.isValue(2, str, Args.ValueType.String)

	local ok, area = self:clipTest(rect)
	if not ok then
		return
	end

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	self.m_Gpu.fill(area:x() + 1, area:y() + 1, area:width(), area:height(), str)
end

--- Gets the character, foreground, and background colors at a specified point <br />
--- If the destination buffer is working on palette mode, returns the palette indices on the 4th and 5th values
---@param p Point # coordinates
---@return string character # character at coordinate p, if p is out of bounds returns '\0'
---@return integer foreground # Foreground Color
---@return integer background # Background Color
---@return integer? foregroundIndex # Foreground Index, when applicable
---@return integer? backgroundIndex # Background Index, when applicable
function Graphics:getChar(p)
	Args.isClass(1, p, Point)

	local area = self.m_Area
	if not area:contains(p) then return '\0', 0, 0 end
	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	return self.m_Gpu.get(p.x + 1, p.y + 1)
end

--- Sets the character at the specified coordinate
---@param p Point # coordinates
---@param chr string # character
function Graphics:setChar(p, chr)
	Args.isClass(1, p, Point)
	Args.isValue(2, chr, Args.ValueType.String)

	assert(unicode.len(chr) == 1, "invalid argument: chr - must be of length 1")

	local area = self:clip()
	if not area:contains(p) then return end

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	self.m_Gpu.set(p.x + 1, p.y + 1, chr, false)
end

--- Sets all characters in a row to the specified one
---@param start integer # start row
---@param count integer # number of rows
---@param chr string # character to fill with
function Graphics:setRows(start, count, chr)
	Args.isInteger(1, start)
	Args.isInteger(2, count)
	Args.isValue(3, chr, Args.ValueType.String)

	assert(unicode.len(chr) == 1, "invalid argument: chr - must be of length 1")

	local r0 = self:clip()
	local r1 = Rect.new(r0:x(), start, r0:width(), count)
	local clip = r0 * r1

	if clip:height() == 0 then
		return
	end

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	self.m_Gpu.fill(clip:x() + 1, clip:y() + 1, clip:width(), clip:height(), chr)
end

--- Sets all characters in a column to the specified one
---@param start integer # start column
---@param count integer # number of columns
---@param chr string # character to fill with
function Graphics:setColumns(start, count, chr)
	Args.isInteger(1, start)
	Args.isInteger(2, count)
	Args.isValue(3, chr, Args.ValueType.String)

	assert(unicode.len(chr) == 1, "invalid argument: chr - must be of length 1")

	local r0 = self:clip()
	local r1 = Rect.new(start, r0:y(), count, r0:height())
	local clip = r0 * r1

	if clip:width() == 0 then
		return
	end

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	self.m_Gpu.fill(clip:x() + 1, clip:y() + 1, clip:width(), clip:height(), chr)
end

--- Draws a border inside a specified rectangle
---@param rect Rect
---@param style BorderStyle
function Graphics:drawBorder(rect, style)
	Args.isClass(1, rect, Rect)
	Args.isValue(2, style, Args.ValueType.Table)

	assert(#style == 8, "invalid style table")

	local ok, clip = self:clipTest(rect)
	if not ok then
		return
	end

	local x0 = rect.left
	local y0 = rect.top
	local x1 = rect.right - 1
	local y1 = rect.bottom - 1

	local ul = Point.new(x0, y0)
	local ur = Point.new(x1, y0)
	local bl = Point.new(x0, y1)
	local br = Point.new(x1, y1)

	local left = #style[1] > 0 and clip.left <= rect.left
	local right = #style[2] > 0 and clip.right >= rect.right
	local up = #style[3] > 0 and clip.top <= rect.top
	local down = #style[4] > 0 and clip.bottom >= rect.bottom

	local _ = left and self.m_Gpu.fill(clip.left + 1, clip.top + 1, 1, clip:height(), style[1])
	_ = right and self.m_Gpu.fill(clip.right, clip.top + 1, 1, clip:height(), style[2])
	_ = up and self.m_Gpu.fill(clip.left + 1, clip.top + 1, clip:width(), 1, style[3])
	_ = down and self.m_Gpu.fill(clip.left + 1, clip.bottom, clip:width(), 1, style[4])


	if (left or up) and clip:contains(ul) then
		self.m_Gpu.set(ul.x + 1, ul.y + 1, style[5])
	end
	if (right or up) and clip:contains(ur) then
		self.m_Gpu.set(ur.x + 1, ur.y + 1, style[6])
	end
	if (down or left) and clip:contains(bl) then
		self.m_Gpu.set(bl.x + 1, bl.y + 1, style[7])
	end
	if (down or right) and clip:contains(br) then
		self.m_Gpu.set(br.x + 1, br.y + 1, style[8])
	end
end

--- Draws a Label, with optional padding and decorator
---@param rect Rect
---@param label string
---@param padding integer
---@param xAlign Alignment
---@param yAlign Alignment
---@param vertical boolean
---@param border BorderStyle
---@param decor DecoratorStyle
---@return Rect # Label Rect
---@return integer # Label Size
function Graphics:drawLabel(rect, label, xAlign, yAlign, vertical, padding, border, decor)
	Args.isClass(1, rect, Rect)
	Args.isValue(2, label, Args.ValueType.String)
	Args.isEnum(3, xAlign, Enums.Alignment)
	Args.isEnum(4, yAlign, Enums.Alignment)
	Args.isValue(5, vertical, Args.ValueType.Boolean)
	Args.isInteger(6, padding)
	Args.isValue(7, border, Args.ValueType.Table)
	Args.isValue(8, decor, Args.ValueType.Table)

	padding = padding or 0
	vertical = vertical or false

	if label == nil then
		return Rect.new(rect.left, rect.top, 0, 0), 0
	end
	local ncts, len = Text.stripColorTokens(label)
	if len == 0 then
		return Rect.new(rect.left, rect.top, 0, 0), 0
	end

	local pre, post, inverted = DrawHelper.selectDecorator(border, decor, xAlign, yAlign, vertical)
	local preSz = unicode.len(pre)
	local postSz = unicode.len(post)
	local nctsSz = unicode.len(ncts)

	local lRect, lSize = DrawHelper.calculateLabelRect(rect, border, (preSz + postSz + nctsSz), xAlign, yAlign, vertical,
		padding)

	local pLabel, pPre, pPost, pElip
	if vertical then
		local offset = Point.new(0, preSz)
		pPre = lRect:tl()
		pLabel = lRect:tl() + offset
		pPost = lRect:bl() - offset
		pElip = pPost - Point.new(0, 1)
	else
		local offset = Point.new(preSz, 0)
		pPre = lRect:tl()
		pLabel = lRect:tl() + offset
		pPost = lRect:tr() - offset
		pElip = pPost - Point.new(1, 0)
	end

	local f, b = self:colors()
	if inverted then self:setColors(b, f) end
	self:pushClip(lRect)
	self:drawString(pLabel, label, vertical)
	if nctsSz > lSize then
		local e = vertical and '⋮' or '…'
		self:drawString(pElip, e, false, true)
	end
	self:popClip()

	self:setColors(f, b)
	if preSz ~= 0 then
		self:drawString(pPre, pre, vertical, true)
	end
	if postSz ~= 0 then
		self:drawString(pPost, post, vertical, true)
	end


	return lRect, (lSize + preSz + postSz)
end

--- Draws a string at the specified point
---@param p Point
---@param str string
---@param vertical? boolean # defaults to false
---@param rawText? boolean # Set to true to not draw the text as-is, without color processing, defaults to false
---@return Rect rect
function Graphics:drawString(p, str, vertical, rawText)
	Args.isClass(1, p, Point)
	Args.isValue(2, str, Args.ValueType.String)
	Args.isValue(3, vertical, Args.ValueType.Boolean, true)
	Args.isValue(4, rawText, Args.ValueType.Boolean, true)

	rawText = rawText or false
	vertical = vertical or false

	if type(str) ~= 'string' then
		str = tostring(str)
	end

	if rawText == false and Text.hasColorTokens(str) == false then
		rawText = true
	end

	local strLen
	if rawText then
		strLen = unicode.len(str)
	else
		local _
		_, strLen = Text.stripColorTokens(str)
	end

	local lRect
	if vertical then
		lRect = Rect.new(p.x, p.y, 1, strLen)
	else
		lRect = Rect.new(p.x, p.y, strLen, 1)
	end

	local ok, clip = self:clipTest(lRect)
	if not ok then return clip end

	local dx = clip.left - p.x
	local dy = clip.top - p.y

	if rawText then
		local cs = (vertical and dy or dx)
		local cl = vertical and clip:height() or clip:width()
		local s2 = unicode.sub(str, cs + 1, cs + cl)
		self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
		self.m_Gpu.set(clip:x() + 1, clip:y() + 1, s2, vertical)
	else
		local parsed = self:prepareText(str, nil)
		self:drawPreparedText(parsed, clip, -1, -1, vertical)
	end

	return clip
end

--- Prepares a text block to be drawn at a later time
---@param text string|string[] # Text
---@param lineWidth? integer # if not nil, value is used to do word wrapping
---@return PreparedText # a table with the prepared text
function Graphics:prepareText(text, lineWidth)
	Args.isValue(1, text, Args.ValueType.String)
	Args.isInteger(2, lineWidth, true)

	local lines, maxLine, _
	local tRect

	if lineWidth ~= nil then
		lines, maxLine, _ = Text.preprocessWordWrap(text, lineWidth, math.huge)
	else
		lines, maxLine, _ = Text.preprocessColorOnly(text, math.huge, math.huge)
	end
	tRect = Rect.new(0, 0, maxLine, #lines)

	return {
		textRect = tRect,
		lines = lines,
	}
end

--- Draws a previously prepared text into the screen
---@param preparedText PreparedText
---@param rect Rect
---@param xAlign Alignment
---@param yAlign Alignment
---@param vertical boolean
---@return Rect # area used to draw the text
---@see Graphics.prepareText
function Graphics:drawPreparedText(preparedText, rect, xAlign, yAlign, vertical)
	Args.isValue(1, preparedText, Args.ValueType.Table)
	Args.isClass(2, rect, Rect)
	Args.isEnum(3, xAlign, Enums.Alignment)
	Args.isEnum(4, yAlign, Enums.Alignment)
	Args.isValue(5, vertical, Args.ValueType.Boolean)

	local lines = preparedText.lines
	local textRect = preparedText.textRect

	local pX, pY
	local rX = rect:width() - (vertical and textRect:height() or textRect:width())
	local rY = rect:height() - (vertical and textRect:width() or textRect:height())

	if xAlign < 0 then
		pX = rect.left
	elseif xAlign > 0 then
		pX = rect.left + rX
	else
		pX = rect.left + math.ceil(rX / 2)
	end

	if yAlign < 0 then
		pY = rect.top
	elseif yAlign > 0 then
		pY = rect.top + rY
	else
		pY = rect.top + math.ceil(rY / 2)
	end

	local _, test = self:clipTest(rect)

	local startIdx = math.max(0, math.min(test.top - rect.top, #lines - 1))
	local iEnd = math.max(0, math.min(rect:height() - 1, #lines - 1 - startIdx))

	local pBase = Point.new(pX, pY + startIdx)
	for i = 0, iEnd do
		local line = lines[i + startIdx + 1]
		local pLine
		local rSize = textRect:width()
		if vertical then
			local lOff
			if yAlign < 0 then
				lOff = 0
			elseif yAlign > 0 then
				lOff = rSize - line.size
			else
				lOff = (rSize - line.size) // 2
			end
			pLine = pBase + Point.new(i, lOff)
		else
			local lOff
			if xAlign < 0 then
				lOff = 0
			elseif xAlign > 0 then
				lOff = rSize - line.size
			else
				lOff = (rSize - line.size) // 2
			end
			pLine = pBase + Point.new(lOff, i)
		end
		self:drawTextRun(pLine, line, vertical)
	end

	return Rect.new(pBase.x, pBase.y, textRect:width(), textRect:height())
end

--- Draws a single prepared text run
---@param p Point
---@param textRun TextRun
---@param vertical boolean
function Graphics:drawTextRun(p, textRun, vertical)
	Args.isClass(1, p, Point)
	Args.isValue(2, textRun, Args.ValueType.Table)
	Args.isValue(3, vertical, Args.ValueType.Boolean)

	local fg, bg = self:colors()
	for i = 1, #textRun do
		local block = textRun[i]
		local wFg = block.fg or fg
		local wBg = block.bg or bg
		self:setColors(wFg, wBg)

		local p1 = p + Point.new(
			vertical and 0 or block.offset,
			vertical and block.offset or 0
		)
		self:drawString(p1, block.str, vertical, true)
	end
	self:setColors(fg, bg)
end

--- Draws a styled separator line
---@param p Point # Start Point
---@param size integer
---@param dir Direction2
---@param style SeparatorStyle
---@see Graphics.Separator
function Graphics:drawSeparator(p, size, dir, style)
	Args.isClass(1, p, Point)
	Args.isInteger(2, size)
	Args.isEnum(3, dir, Enums.Direction2)
	Args.isValue(4, style, Args.ValueType.Table)

	local rect
	local vert = dir == Enums.Direction2.Vertical

	if vert then
		rect = Rect.new(p.x, p.y, 1, size)
	else
		rect = Rect.new(p.x, p.y, size, 1)
	end

	style = DrawHelper.selectSubStyle2way(style, dir)

	local v, clip = self:clipTest(rect)
	if not v then
		return
	end

	local cl = vert and clip:height() or clip:width()

	local flip = style[4] or false
	local fg, bg = self:colors()
	if flip then
		self:setColors(bg, fg)
	end

	self.m_Gpu.setActiveBuffer(self.m_DrawBuf)
	if vert then
		self.m_Gpu.fill(clip.left + 1, clip.top + 1, 1, cl, style[1])
		self.m_Gpu.set(clip.left + 1, clip.top + 1, style[2])
		self.m_Gpu.set(clip.left + 1, clip.top + 1, style[3])
	else
		self.m_Gpu.fill(clip.left + 1, clip.top + 1, cl, 1, style[2])
		self.m_Gpu.set(clip.left + 1, clip.top + 1, style[1])
		self.m_Gpu.set(clip.left + cl, clip.top + 1, style[3])
	end

	self:setColors(fg, bg)
end

---@private
function Graphics:_setPixel_Sub(p, col)
	local trueX = (p.x)
	local trueY = (p.y // 2)
	local upper = (p.y & 1) == 0
	local clip = self:clip()
	clip = Rect.new(clip.left, clip.top * 2, clip:width(), clip:height() * 2)
	if not clip:contains(Point.new(trueX, trueY)) then
		return
	end
	trueX = trueX + 1
	trueY = trueY + 1

	local uCol, lCol
	local oFg, oBg = self:colors()

	local ch, fg, bg = self.m_Gpu.get(trueX, trueY)
	if ch == '▀' then
		uCol, lCol = fg, bg
	elseif ch == '▄' then
		uCol, lCol = bg, fg
	elseif ch == '█' then
		uCol, lCol = fg, fg
	else
		uCol, lCol = bg, bg
	end

	local col2 = upper and lCol or uCol
	local same = col == col2

	self.m_Gpu.setForeground(col)
	self.m_Gpu.setBackground(col2)
	if same then
		self.m_Gpu.set(trueX, trueY, ' ')
	elseif upper then
		self.m_Gpu.set(trueX, trueY, '▀')
	else
		self.m_Gpu.set(trueX, trueY, '▄')
	end

	self:setColors(oFg, oBg)
end

---@private
function Graphics:_setPixel_Full(p, col)
	if not self:clip():contains(p) then return end

	self.m_Gpu.setBackground(col)
	self.m_Gpu.set(p.x + 1, p.y + 1, ' ')
end

--- Sets the specified coordinate to a "pixel" of the specified color, with optional double vertical resolution mode using half block characters
---@param p Point # coordinates
---@param color integer # color
---@param doubleRes? boolean # if true, the `y` component of `p` can be up to 2 vertical resolutions, and the upper or lower half blocks of a character will be set insted
function Graphics:setPixel(p, color, doubleRes)
	Args.isClass(1, p, Point)
	Args.isInteger(2, color)
	Args.isValue(3, doubleRes, Args.ValueType.Boolean, true)

	local fg, bg = self:colors()
	if doubleRes then
		self:_setPixel_Sub(p, color)
	else
		self:_setPixel_Full(p, color)
	end
	self:setColors(fg, bg)
end

--- Draws a line from point p0 to point p1
---@param p0 Point # Start Point
---@param p1 Point # End Point
---@param doubleRes? boolean # Double Vertical Resolution Mode
---@see Graphics.setPixel
function Graphics:drawLine(p0, p1, doubleRes)
	Args.isClass(1, p0, Point)
	Args.isClass(2, p1, Point)
	Args.isValue(3, doubleRes, Args.ValueType.Boolean, true)

	local key = { Graphics.ShapeKind.Line, p0.x, p0.y, p1.x, p1.y }
	local hash = hashlib.getHashcode(key)
	local points = Graphics.ShapeCache[hash]
	if not points then
		points = {}
		Graphics.ShapeCache[hash] = points
		Rasterizer.line(p0, p1, function(p) points[#points + 1] = p end)
	end

	self:drawPoints(points, doubleRes)
end

--- Draws an ellipse inside a rectangle
---@param rect Rect # Rectangle containing Ellipse
---@param doubleRes? boolean # Double Vertical Resolution Mode
---@see Graphics.setPixel
function Graphics:drawEllipse(rect, doubleRes)
	Args.isClass(1, rect, Rect)
	Args.isValue(2, doubleRes, Args.ValueType.Boolean, true)

	local key = { Graphics.ShapeKind.Ellipse, rect.left, rect.right, rect.top, rect.bottom }
	local hash = hashlib.getHashcode(key)
	local cached = Graphics.ShapeCache[hash]
	if not cached then
		cached = {}
		Graphics.ShapeCache[hash] = cached
		Rasterizer.ellipse(rect, function(p) cached[#cached + 1] = p end)
	end

	self:drawPoints(cached, doubleRes)
end

--- Draws an quadratic bezier
---@param p0 Point # Start Point
---@param p1 Point # Control Point
---@param p2 Point # End Point
---@param w? number # Weight
---@param doubleRes? boolean # Double Vertical Resolution Mode
---@see Graphics.setPixel
function Graphics:drawCurveQBez(p0, p1, p2, w, doubleRes)
	Args.isClass(1, p0, Point)
	Args.isClass(2, p1, Point)
	Args.isClass(3, p2, Point)
	Args.isValue(4, w, Args.ValueType.Number, true)
	Args.isValue(5, w, Args.ValueType.Boolean, true)

	if w == nil then w = 1 end

	local key = { Graphics.ShapeKind.QBez, p0, p1, p2, w }
	local hash = hashlib.getHashcode(key)
	local cached = Graphics.ShapeCache[hash]
	if not cached then
		cached = {}
		Graphics.ShapeCache[hash] = cached
		Rasterizer.quadraticBezier(p0, p1, p2, w, function(p) cached[#cached + 1] = p end)
	end

	self:drawPoints(cached, doubleRes)
end

--- Draws a B-Spline consitesd of quadratic beziers
---@param points Point[] # Array of Points (minimum 3)
---@param w? number # Weight
---@param doubleRes? boolean # Double Vertical Resolution
---@see Graphics.drawCurveQ
function Graphics:drawBSplineQBez(points, w, doubleRes)
	Args.isValue(1, points, Args.ValueType.Table)
	Args.isValue(2, w, Args.ValueType.Number, true)
	Args.isValue(3, doubleRes, Args.ValueType.Boolean, true)

	if w == nil then w = 1 end

	local key = { Graphics.ShapeKind.QBSpline, points, w }
	local hash = hashlib.getHashcode(key)
	local cached = Graphics.ShapeCache[hash]

	if not cached then
		cached = {}
		Graphics.ShapeCache[hash] = cached
		Rasterizer.quadraticBSpline(points, w, function(p) cached[#cached + 1] = p end)
	end

	self:drawPoints(cached, doubleRes)
end

--- Draws a set of points
---@param points table<integer, Point>
---@param doubleRes? boolean
function Graphics:drawPoints(points, doubleRes)
	Args.isValue(1, points, Args.ValueType.Table)
	Args.isValue(2, doubleRes, Args.ValueType.Boolean, true)

	local fg, bg = self:colors()

	local plot
	if doubleRes then
		plot = function(p) self:_setPixel_Sub(p, fg) end
	else
		plot = function(p) self:_setPixel_Full(p, fg) end
	end

	for _, p in pairs(points) do
		plot(p)
	end

	self:setColors(fg, bg)
end

-- Static Utilities

local isEmu = pcall(component.getPrimary, 'ocemu')

function Graphics.debugPrint(...)
	if isEmu then
		component.ocemu.log(...)
	else
		local gpu = component.gpu
		local x = gpu.getActiveBuffer()
		gpu.setActiveBuffer(0)
		term.clear()

		print(...)
		print(debug.traceback())
		print("Press any key to continue...")

		require("computer").beep(1000, 0.1)
		os.sleep(0.5)
		require("event").pull('key')
		gpu.setActiveBuffer(x)
	end
end

return Graphics
