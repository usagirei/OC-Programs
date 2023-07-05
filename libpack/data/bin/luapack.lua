local function readConfig()
	local cfg = io.open("./.luapack", "r")
	if not cfg then
		error("missing .luapack file")
	end

	local config = {
		input = nil,
		output = nil,
		bundle = {},
		options = {}
	}
	while true do
		---@type string
		local l = cfg:read("l")
		if not l then break end

		if l:find("^%s*#") or l:find("^%s*$") then
			goto continue
		end

		local fields = {}
		for w in l:gmatch("[^,]+") do
			fields[#fields + 1] = w:gsub("^%s+", ""):gsub("%s$", "")
		end
		if fields[1] == "output" then
			assert(config.output == nil)
			local file = assert(fields[2])
			config.output = file
		elseif fields[1] == "input" then
			assert(config.input == nil)
			local file = assert(fields[2])
			config.input = file
		elseif fields[1] == "option" then
			local opt = assert(fields[2])
			config.options[opt] = true
		elseif fields[1] == "bundle" then
			local name = assert(fields[2])
			local file = assert(fields[3])
			config.bundle[name] = file
		end

		::continue::
	end
	return config
end

local configOK, config = pcall(readConfig)
if not configOK then
	error("invalid configuration file")
end

local function fileExists(path)
	local f = io.open(path, "r")
	if not f then return false end
	f:close()
	return true
end

---@param path string
local function readFile(path)
	local f = io.open(path, "r")
	if not f then error("failed to open file for reading: " .. path) end
	local d = f:read("a")
	f:close()
	return d
end

---@param path string
---@param data string
local function writeFile(path, data)
	local f = io.open(path, "w")
	if not f then error("failed to open file for writing: " .. path) end
	local d = f:write(data)
	f:close()
end

---@param out? file*
---@param templ string
---@param repFn? table|function
local function template(out, templ, repFn)
	repFn = repFn or {}
	local function repl(k)
		local r = type(repFn) == "function" and repFn(k) or repFn[k]
		if r == nil then
			error('missing template key: ' .. k)
		end
		if type(r) == "function" then
			return r(k)
		else
			return r
		end
	end

	if out then
		for line in templ:gmatch("[^\r\n]+") do
			local t = string.gsub(line, "{{(.-)}}", repl)
			assert(out:write(t, '\n'))
		end
		return nil
	else
		local tbl = {}
		for line in templ:gmatch("[^\r\n]+") do
			local t = string.gsub(line, "{{(.-)}}", repl)
			tbl[#tbl + 1] = t
		end
		return table.concat(tbl, '\n')
	end
end

---@return string|nil
local function findPackage(modName)
	for path in package.path:gmatch("[^;]+") do
		local modPath = path:gsub("%.", ","):gsub("%?", modName):gsub("%.", "/"):gsub(",", ".")
		if fileExists(modPath) then
			return modPath
		end
	end
	return nil
end

local Templates = {}
Templates.Head = [[----------
local P = {}
]]

Templates.Package = [[----------
P["{{name}}"] = {
	m={{open}}{{data}}{{close}},
	c={{checksum}},
	f={{loader}},
	s={{save}}
}]]

Templates.Tail = [[----------
local R = require
require = function(m, ...)
	if P[m] then
		if not P[m].l then
			local r = P[m].f(m, P[m].m, P[m].c)(...)
			if not P[m].s then return r end
			P[m].l = r
		end
		return P[m].l
	end
	return R(m, ...)
end
local o, r = pcall(require, "=main", ...)
require = R
if not o then
	print(r)
else
	return r
end
]]

Templates.LZ4Load = [[----------
local function lz4load(x, y, z)
	local a,b,c,d
	a = require("libpack.z85.decode")
	b = require("libpack.lz4.decode")
	c = a(y)
	d = b(c, z)
	if not d then error("checksum error on " .. x) end
	return assert(load(d, "=" .. x, "t", _ENV))
end]]

Templates.RawLoad = [[----------
local function rawload(x, y, z)
	local p = 0x01000193
	local h = 0x811C9DC5
	for i = 1, #y do
		h = ((y:byte(i) ~ h) * p) & 0xFFFFFFFF
	end
	if h ~= z then
		error("checksum error on " .. x)
	end
	return assert(load(y, "=" .. x, "t", _ENV))
end]]

local Embedded = {}

---@param out file*
---@param name string
---@param content string
---@param isCached boolean
---@param isCompressed boolean
---@param checksum integer
local function embedChunk(out, name, content, isCached, isCompressed, checksum)
	if Embedded[name] then
		print("package already embedded: " .. name)
		return
	end
	print("\x1b[32m\tembedding...\x1b[0m")
	Embedded[name] = true

	if checksum == 0 then
		local p = 0x01000193
		local h = 0x811C9DC5
		for i = 1, #content do
			h = ((content:byte(i) ~ h) * p) & 0xFFFFFFFF
		end
		checksum = h
	end

	local open, close
	local eq1 = content:match("%[=*%[")
	local eq2 = content:match("%]=*%]")
	local eq = ''
	if eq1 or eq2 then
		local n = math.max(eq1 and #eq1 or 0, eq2 and #eq2 or 0) - 2
		eq = string.rep('=', n + 1)
	end
	open = '[' .. eq .. '['
	close = ']' .. eq .. ']'


	return template(out, Templates.Package, {
		name = name,
		checksum = string.format("0x%08X", checksum),
		loader = isCompressed and "lz4load" or "rawload",
		data = content,
		open = open,
		close = close,
		save = isCached and "true" or "false"
	})
end

---@param out file*
---@param name string
---@param path string
---@param isCached boolean
---@param isCompressed boolean
---@param checksum integer
local function embedFile(out, name, path, isCached, isCompressed, checksum)
	local content = readFile(path)
	return embedChunk(out, name, content, isCached, isCompressed, checksum)
end

---@return boolean ok
local function minify(src, dst)
	local cmd = string.format("luamin --o='%s' '%s'", dst, src)
	local p = io.popen(cmd, "r")
	if not p then error("failed to open luamin") end
	print("\x1b[32m\tminifying...\x1b[0m")
	local res = p:read("a")
	if res ~= "OK" then return false end
	p:close()
	return true
end

---@param src string
---@param validate boolean
---@return boolean ok
---@return integer checksum
local function compress(src, dst, validate)
	local chk, cok = 0, false

	local lz4 = require("libpack.lz4")
	local z85 = require("libpack.z85")

	local chunk = readFile(src)

	print("\x1b[32m\tcompressing...\x1b[0m")
	local lzStr
	lzStr, chk = lz4.lz4_encode(chunk)
	if lzStr then
		if validate then assert(lz4.lz4_decode(lzStr) == chunk, "lz4 decode error") end
		local aStr = z85.z85_encode(lzStr)
		if validate then assert(z85.z85_decode(aStr) == lzStr, "lz85 decode error") end
		cok = true
		writeFile(dst, aStr)
	end

	if cok then
		return true, chk
	else
		return false, chk
	end
end

---@param out file*
---@param name string
---@param path string
---@param cached boolean
---@param doMinify boolean
---@param doCompress boolean
local function processEmbed(out, name, path, cached, doMinify, doCompress)
	print("\x1b[0mpackage: \x1b[33m" .. name .. "\x1b[0m")
	local tmp = {}
	local minOK, lz4OK, check = true, true, 0
	if doMinify and config.options.minify then
		if os.sleep then os.sleep(0) end

		local x = '/tmp/~luapack.min'
		tmp[#tmp + 1] = x
		minOK = minify(path, x)
		path = x
	end
	if doCompress and config.options.compress then
		if os.sleep then os.sleep(0) end

		local x = '/tmp/~luapack.lz4'
		tmp[#tmp + 1] = x
		lz4OK, check = compress(path, x, false)
		path = x
	end
	if (minOK and lz4OK) then
		if os.sleep then os.sleep(0) end
		
		local rv, msg = embedFile(out, name, path, cached, lz4OK, check)
		local fs = require('filesystem')
		for i = 1, #tmp do fs.remove(tmp[i]) end
		return rv, msg
	end
	return nil, "failed to compress or minify"
end

local outFile = assert(io.open(config.output, "w"), "failed to open output file")
template(outFile, Templates.Head, nil)
template(outFile, Templates.RawLoad, nil)
if config.options.compress then
	local lz4Path = findPackage("libpack.lz4.decode")
	local z85Path = findPackage("libpack.z85.decode")

	assert(lz4Path, "failed to find lz4 package")
	assert(z85Path, "failed to find z85 package")

	template(outFile, Templates.LZ4Load, nil)
	processEmbed(outFile, "libpack.lz4.decode", lz4Path, true, true, false)
	processEmbed(outFile, "libpack.z85.decode", z85Path, true, true, false)
end

processEmbed(outFile, "=main", config.input, false, true, true)
for mod, path in pairs(config.bundle) do
	processEmbed(outFile, mod, path, true, true, true)
end

template(outFile, Templates.Tail, nil)
print("OK")
