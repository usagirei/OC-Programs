local unicode = require('unicode')

local Text = {}

---@class TextRun : { ['size']: integer, [integer]: TextBlock }

---@class TextBlock
---@field str string
---@field offset integer
---@field size integer
---@field fg? integer
---@field bg? integer

local WW_Status = {
	OK = 0,
	EOF = 1
}
local WW_Code = {
	LINEBREAK = 0,
	IGNORE = 1,
	EOF = 2,
}
local WW_Control = {
	['\n'] = WW_Code.LINEBREAK,
	['\0'] = WW_Code.EOF,
	['\r'] = WW_Code.IGNORE,
	['\t'] = false,
	[' '] = false
}

---@enum TextColor
Text.Color = {
	Black = 0,
	DarkBlue = 1,
	DarkGreen = 2,
	DarkAqua = 3,
	DarkRed = 4,
	DarkPurple = 5,
	Gold = 6,
	Gray = 7,
	DarkGray = 8,
	Blue = 9,
	Green = 10,
	Aqua = 11,
	Red = 12,
	Purple = 13,
	Yellow = 14,
	White = 15
}

---@param txt string
---@param fg? integer
---@param bg? integer
function Text.colorize(txt, fg, bg)
	if fg and bg then
		return string.format("§%x§l§%x%s§r", bg, fg, txt)
	elseif fg then
		return string.format("§r§%x%s§r", fg, txt)
	elseif bg then
		return string.format("§r§%x§l%s§r", bg, txt)
	else
		return txt
	end
end

local WW_Control_Pattern = "[\n\t\0\r ]"
local WW_Color_Pattern_MC = "§([0-9a-fklmnor])"
local WW_Colors = {
	0x000000, 0x0000AA, 0x00AA00, 0x00AAAA, 0xAA0000, 0xAA00AA, 0xFFAA00, 0xAAAAAA,
	0x555555, 0x5555FF, 0x55FF55, 0x55FFFF, 0xFF5555, 0xFF55FF, 0xFFFF55, 0xFFFFFF,
}

local function updateColors(token, curFg, curBg)
	local command = token:match(WW_Color_Pattern_MC)
	if command == nil then
		return false, curFg, curBg
	end

	if command == 'l' then
		curBg, curFg = curFg, curBg
		--elseif command == 'k' then
		--elseif command == 'm' then
		--elseif command == 'n' then
		--elseif command == 'o' then
	elseif command == 'r' then
		curBg = nil
		curFg = nil
	else
		local num = tonumber(command, 16)
		curFg = WW_Colors[num + 1]
	end

	return true, curFg, curBg
end

---@return string  # string without color tokens
---@return integer # string lenght
function Text.stripColorTokens(text)
	local nc = string.gsub(text, WW_Color_Pattern_MC, '')
	return nc, unicode.len(nc)
end

---@return boolean
function Text.hasColorTokens(text)
	return string.match(text, WW_Color_Pattern_MC) ~= nil
end

--- Parses text into an array of TextRuns, with word wrapping and color token parsing
---@param text string|string[]
---@param lineSize any
---@param numLines any
---@return TextRun[] Lines
---@return integer MaxLine
---@return boolean IsFit
function Text.preprocessWordWrap(text, lineSize, numLines)
	---@type TextRun[]
	local result = {}
	local curOffset = 0
	---@type TextRun
	local curLine = { size = 0 }

	local curFg = nil
	local curBg = nil
	local prevType = "br"

	---@param token string
	local function process(token)
		if token == nil then
			return WW_Status.EOF
		elseif WW_Control[token] ~= nil then
			local code = WW_Control[token]
			if code == WW_Code.IGNORE then
				-- Skip
				return WW_Status.OK
			elseif code == WW_Code.LINEBREAK then
				-- Add LineBreak
				if prevType == "ws" then
					curLine[#curLine] = nil
					curLine.size = curLine[#curLine].offset + curLine[#curLine].size
				end
				result[#result + 1] = curLine
				curLine = { size = 0 }
				curOffset = 0
				prevType = "br"
				return WW_Status.OK
			elseif code == WW_Code.EOF then
				-- Stop
				if #curLine ~= 0 then result[#result + 1] = curLine end
				return WW_Status.EOF
			end
		end

		local wasColor
		wasColor, curFg, curBg = updateColors(token, curFg, curBg)
		if wasColor then
			return WW_Status.OK
		end

		local cType = "word"
		if token == ' ' then
			if prevType == "ws" or prevType == "br" then return WW_Status.OK end
			token = ' '
			cType = "ws"
		elseif token == '\t' then
			token = "   "
			cType = "ws"
		end

		local wSize = unicode.len(token)
		local left = lineSize - curLine.size

		local isEmpty = token:match("^%s+$") ~= nil
		local isFirst = #curLine == 0
		local isFit = isFirst and (wSize <= left) or (wSize + (isEmpty and 0 or 1)) <= left

		if isFit then
			-- Add to List
			---@type TextBlock
			local word = { str = token, offset = curOffset, size = wSize, fg = curFg, bg = curBg }
			curLine[#curLine + 1] = word
			curOffset = curOffset + wSize
			curLine.size = curOffset
			prevType = cType
			return WW_Status.OK
		elseif isFirst then
			-- Break into chunks, then reprocess
			for i = 1, wSize, lineSize do
				local substr = string.sub(token, i, i + lineSize - 1)
				local status = process(substr)
				if status ~= WW_Status.OK then return status end
			end
			return WW_Status.OK
		else
			-- Add LineBreak and reprocess
			if prevType == "ws" then
				curLine[#curLine] = nil
				curLine.size = curLine[#curLine].offset + curLine[#curLine].size
			end
			result[#result + 1] = curLine
			curLine = { size = 0 }
			curOffset = 0
			prevType = "br"
			return process(token)
		end
	end

	if type(text) == "string" then
		text = { text }
	else
		text = { table.unpack(text) }
	end
	text[#text + 1] = '\0'

	local maxSize = 0
	for i, tt in pairs(text) do
		local tokens = tt:gsub(WW_Control_Pattern, "\0%0\0"):gsub(WW_Color_Pattern_MC, "\0%0\0")
		local iter = tokens:gmatch("[^%z]+")
		local err
		while true do
			local token = iter()
			err = process(token)
			if err == WW_Status.EOF then
				break
			end
			for j = 1, #result do maxSize = math.max(maxSize, result[j].size) end
		end
		if i ~= #text then
			process('\n')
		end
	end
	return result, maxSize, (maxSize <= lineSize) and (numLines <= #result)
end

--- Parses text into an array of TextRuns, with word wrapping and color token parsing
---@param text string|string[]
---@return TextRun[] Lines
---@return integer MaxLine
---@return boolean IsFit
function Text.preprocessColorOnly(text, lineSize, numLines)
	local result = {}
	local curOffset = 0
	---@type TextRun
	local curLine = {}

	local curFg = nil
	local curBg = nil

	---@param token string
	local function process(token)
		if token == nil then
			return WW_Status.EOF
		elseif WW_Control[token] ~= nil then
			local code = WW_Control[token]
			if code == WW_Code.IGNORE then
				-- Skip
				return WW_Status.OK
			elseif code == WW_Code.LINEBREAK then
				-- Add LineBreak
				result[#result + 1] = curLine
				curLine = { size = 0 }
				curOffset = 0
				return WW_Status.OK
			elseif code == WW_Code.EOF then
				-- Stop
				if #curLine ~= 0 then result[#result + 1] = curLine end
				return WW_Status.EOF
			end
		end

		local wasColor
		wasColor, curFg, curBg = updateColors(token, curFg, curBg)
		if wasColor then
			return WW_Status.OK
		end

		if token == '\t' then
			token = "   "
		end

		local wSize = unicode.len(token)

		---@type TextBlock
		local word = { str = token, offset = curOffset, size = wSize, fg = curFg, bg = curBg }
		curLine[#curLine + 1] = word
		curOffset = curOffset + wSize
		curLine.size = curOffset
		return WW_Status.OK
	end

	if type(text) == "string" then
		text = { text }
	else
		text = { table.unpack(text) }
	end

	text[#text + 1] = '\0'

	local maxSize = 0
	for i, tt in pairs(text) do
		local tokens = tt:gsub(WW_Control_Pattern, "\0%0\0"):gsub(WW_Color_Pattern_MC, "\0%0\0")
		local iter = tokens:gmatch("[^%z]+")
		local err
		while true do
			local token = iter()
			err = process(token)
			if err == WW_Status.EOF then
				break
			end
			for j = 1, #result do maxSize = math.max(maxSize, result[j].size) end
		end
		if i ~= #text then
			process('\n')
		end
	end
	return result, maxSize, (maxSize <= lineSize) and (numLines <= #result)
end

local GFX_StrArrayCache = {}
setmetatable(GFX_StrArrayCache, { __mode = 'v' })
--- Converts a string into an array composed of its characters
---@param str string
---@return table
function Text.toArray(str)
	if GFX_StrArrayCache[str] then
		return GFX_StrArrayCache[str]
	else
		local tbl = {}
		local len = unicode.len(str)
		for i = 1, len do
			tbl[i] = unicode.sub(str, i, i)
		end
		GFX_StrArrayCache[str] = tbl
		return tbl
	end
end

return Text
