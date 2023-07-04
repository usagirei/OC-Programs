local Parser = require("libpack.parser")
local Class = require("libpack.class")
local lz4 = require("libpack.lz4")
local Analyzer = require("libpack.analyzer")
local Token = require("libpack.tokenizer.token")
local z85 = require("libpack.z85")

local cfg = io.open("./.luapack", "r")
if not cfg then
	error("missing .luapack file")
end

local function readConfig()
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

local function print(...)
	local v = table.pack(...)
	local l = table.concat(v, '\t')
	io.stderr:write(l, '\n')
end

local ok, config = pcall(readConfig)
if not ok then
	error("invalid configuration file")
end

---@param chunk string
---@param noCompress? boolean
---@return string data
---@return integer checksum
---@return boolean compressed
local function processChunk(chunk, noCompress)
	local compact, compress
	compact  = config.options.minify
	compress = config.options.compress and not noCompress

	---------------------------------------

	if compact then
		local tmp = "/tmp/luapack.min.lua"
		local cmd = string.format("luamin > '%s'", tmp)

		local p = io.popen(cmd, "w")
		if not p then error("failed to open luamin") end
		print("\tminifying...")
		p:write(chunk)
		p:close()

		local f = io.open(tmp, "r")
		if not f then error("failed to open minified output") end
		local m = f:read("a")
		f:close()

		chunk = m
	end

	---------------------------------------

	local chk, cok = 0, false
	if compress then
		print("\t compressing...")
		local lzStr
		lzStr, chk = lz4.lz4_encode(chunk)
		if lzStr then
			assert(lz4.lz4_decode(lzStr) == chunk)

			local aStr = z85.z85_encode(lzStr)
			assert(z85.z85_decode(aStr) == lzStr)

			chunk = aStr
			cok = true
		end
	else
		local p = 0x01000193
		local h = 0x811C9DC5
		for i = 1, #chunk do
			h = ((chunk:byte(i) ~ h) * p) & 0xFFFFFFFF
		end
		chk = h
	end

	return chunk, chk, cok
end

---@param out? file*
---@param templ string
---@param repFn? table|function
---@return string?
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
			out:write(t, '\n')
		end
	else
		local tbl = {}
		for line in templ:gmatch("[^\r\n]+") do
			local t = string.gsub(line, "{{(.-)}}", repl)
			tbl[#tbl + 1] = t
		end
		return table.concat(tbl, '\n')
	end
end

local PackagePath = {}
for path in package.path:gmatch("[^;]+") do
	PackagePath[#PackagePath + 1] = path
end

local function file_exists(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

---@return string|nil
local function findPackage(modName)
	for _, path in pairs(PackagePath) do
		local modPath = path:gsub("%.", ","):gsub("%?", modName):gsub("%.", "/"):gsub(",", ".")
		if file_exists(modPath) then
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

local packages = {}

---@param out file*
---@param name string
---@param content string
---@param cache boolean
---@param noCompress boolean
local function embedChunk(out, name, content, cache, noCompress)
	if packages[name] then
		print("package already embedded: " .. name)
		return
	end
	print("\x1b[0membedding package:\x1b[33m " .. name)
	packages[name] = true

	local data, check, comp = processChunk(content, noCompress)
	local open, close

	local eq1 = data:match("%[=*%[")
	local eq2 = data:match("%]=*%]")
	local eq = ''
	if eq1 or eq2 then
		local n = math.max(eq1 and #eq1 or 0, eq2 and #eq2 or 0) - 2
		eq = string.rep('=', n + 1)
	end
	open = '[' .. eq .. '['
	close = ']' .. eq .. ']'


	template(out, Templates.Package, {
		name = name,
		checksum = string.format("0x%08X", check),
		loader = comp and "lz4load" or "rawload",
		data = data,
		open = open,
		close = close,
		save = cache and "true" or "false"
	})

	if os.sleep then os.sleep(0) end
end

---@param out file*
---@param name string
---@param stream file*
---@param cache boolean
---@param noCompress boolean
local function embedStream(out, name, stream, cache, noCompress)
	local content = stream:read("a")
	embedChunk(out, name, content, cache, noCompress)
end

---@param out file*
---@param name string
---@param path string
---@param noCompress boolean
local function embedFile(out, name, path, cache, noCompress)
	local f = io.open(path)
	if not f then
		error("failed to open file: " .. path)
	end
	embedStream(out, name, f, cache, noCompress)
	f:close()
end

local inFile = assert(io.open(config.input, "r"), "failed to open input file")
local outFile = assert(io.open(config.output, "w"), "failed to open output file")

template(outFile, Templates.Head, nil)
template(outFile, Templates.RawLoad, nil)
if config.options.compress then
	local lz4Path = findPackage("libpack.lz4.decode")
	local z85Path = findPackage("libpack.z85.decode")

	assert(lz4Path, "failed to find lz4 package")
	assert(z85Path, "failed to find z85 package")

	template(outFile, Templates.LZ4Load, nil)
	embedFile(outFile, "libpack.lz4.decode", lz4Path, true, true)
	embedFile(outFile, "libpack.z85.decode", z85Path, true, true)
end


embedStream(outFile, "=main", inFile, false, false)

for mod, path in pairs(config.bundle) do
	embedFile(outFile, mod, path, true, false)
end

template(outFile, Templates.Tail, nil)
