local fs = require('filesystem')
local shell = require('shell')

local Args, Opts = shell.parse(...)

if Opts.p == nil then
    local script = os.getenv("_")
    local name = fs.name(script)

    local msg =
    [[Usage: %s --p=<package_1,...,package_n> [-z] [-m] [--o=<output>] <script> [<arg1> <arg2> ... <argn>]
    Executes a script intercepting require calls, creates a .luapack definition
        --p packages to bundle - use ? as a wildcard, e.g packagea,packageb?,packagec.sub?
        --o output file, defaults to '<input>.bundle.lua'
        -z apply lz4 compression to bundled files, defaults to false
        -m minify bundled files, defaults to false
]]
    msg = msg:format(name)
    print(msg)
    return
end

local Script = shell.resolve(Args[1])
local ScriptName = fs.name(Script):gsub("%.lua$", "")
local ScriptPath = fs.path(Script)

local OutFile = shell.resolve("./.luapack")

local BundlePackages = {}
for name in string.gmatch(Opts.p, "[^,]+") do
    local pat = "^" .. name:gsub("%.", "%%."):gsub("?", ".-") .. "$"
    BundlePackages[#BundlePackages + 1] = pat
end

local PackagePaths = {}
for p in string.gmatch(package.path, "[^;]+") do
    PackagePaths[#PackagePaths + 1] = p
end

local function isBundlePackage(package)
    for i = 1, #BundlePackages do
        local pattern = BundlePackages[i]
        return string.match(package, pattern)
    end
end

---@return string|nil
local function findPackage(modName)
    for _, path in pairs(PackagePaths) do
        path = path:gsub("%.", "!"):gsub("%?", modName):gsub("%.", "/"):gsub("!", ".")
        path = shell.resolve(path)
        if fs.exists(path) then return path end
    end
    return nil
end

local function unloadPackages()
    for k, _ in pairs(package.loaded) do
        if isBundlePackage(k) then package.loaded[k] = nil end
    end
end

---@return function # Require Wrapper
---@return function # Original Require
---@return table # Require Table
local function createScanner()
    local r = {}
    local v = {}
    local _require = _G.require
    local function require(modname)
        if not v[modname] then
            v[modname] = true
            if isBundlePackage(modname) then r[#r + 1] = modname end
        end
        return _require(modname)
    end
    return require, _require, r
end

local function scan(script, ...)
    local ok, msg
    local newReq, oldReq, reqs = createScanner()
    local scriptFunc = loadfile(script, "bt")
    if scriptFunc then
        _G.require = newReq
        unloadPackages()
        local x = os.getenv('_')
        os.setenv('_', script)
        ok, msg = pcall(scriptFunc, ...)
        os.setenv('_', x)
        unloadPackages()
        _G.require = oldReq
    end
    if ok then
        return true, reqs
    else
        return false, msg
    end
end

local ok, Packages = scan(Script, select(2, Args))
if not ok then
    error("error executing target script: " .. Script .. '\n' .. Packages)
elseif #Packages == 0 then
    error("script did not include any of the target package")
end

for i = #Packages, 1, -1 do
    local name = Packages[i]
    local file = findPackage(name)

    if not file then error("could not locate package: " .. name) end
    Packages[i] = { name, file }
end

local of = io.open(OutFile, "w")
if not of then error("failed to open .luapack file for writing") end

if Opts.m then of:write("option, minify", '\n') end
if Opts.z then of:write("option, compress", '\n') end

if not Opts.o then
    Opts.o = fs.concat(ScriptPath, ScriptName .. ".bundle.lua")
end

of:write("input, ", Script, '\n')
of:write("output, ", shell.resolve(Opts.o), '\n')

for _, j in pairs(Packages) do
    local name, path = table.unpack(j)
    of:write("bundle, ", name, ", ", path, '\n')
end
