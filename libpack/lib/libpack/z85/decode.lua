local SET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#'
assert(((#SET) ^ 5) >= (256 ^ 4))

local LEN = #SET
local DEC = {}
for i = 1, #SET do
	local j = string.byte(SET, i)
	assert(j >= 32 and j <= 126)
	DEC[j] = i - 1
end

---@param s string
---@param i integer
---@return integer,integer,integer,integer
local function z85_unframe(s, i)
	if not string.byte(s, i) then return 0, 0, 0, 0 end
	local sum
	sum = --[[~~~~~~~]] DEC[s:byte(i + 0)]
	sum = (sum * LEN) + DEC[s:byte(i + 1)]
	sum = (sum * LEN) + DEC[s:byte(i + 2)]
	sum = (sum * LEN) + DEC[s:byte(i + 3)]
	sum = (sum * LEN) + DEC[s:byte(i + 4)]

	local b4, b3, b2, b1
	b4 = (sum >> 24) & 0xFF
	b3 = (sum >> 16) & 0xFF
	b2 = (sum >> 8) & 0xFF
	b1 = (sum >> 0) & 0xFF
	return b4, b3, b2, b1
end

---@param str string
local function z85_decode(str)
	local n = #str
	local N = (n // 5) * 5
	local p = n - N
	assert(p == 0 or p == 1)
	if p == 1 then N = N - 5 end
	local tbl = {}
	for i = 1, N, 5 do
		local frame = string.char(z85_unframe(str, i))
		tbl[#tbl + 1] = frame
	end
	if p ~= 0 then
		local P = assert(tonumber(str:sub(-1)))
		local b4, b3, b2, b1 = z85_unframe(str, N + 1)
		local frame
		if P == 1 then
			assert(b1 == 49)
			frame = string.char(b4, b3, b2)
		elseif P == 2 then
			assert(b2 == 49 and b1 == 50)
			frame = string.char(b4, b3)
		elseif P == 3 then
			assert(b3 == 49 and b2 == 50, b1 == 51)
			frame = string.char(b4)
		end
		tbl[#tbl + 1] = frame
	end
	return table.concat(tbl)
end

return z85_decode
