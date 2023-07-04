local fs = require('filesystem')
local shell = require('shell')

local Parser = require("libpack.parser")
local Analyzer = require("libpack.analyzer")
local Token = require("libpack.tokenizer.token")

local Args, Opts = shell.parse(...)

local function print(...)
    io.stderr:write(table.concat({ ... }, '\t'))
end

if Opts.h or Opts.help then
    local script = os.getenv("_")
    local name = fs.name(script)

    local msg = [[Usage: %s [<script>] [--o=<output>|-o]
    Minifies the target lua script, if no input is passed, chunk data is read from stdin
        --help|-h\tprints this message
        --o|-o\toutput file, defaults to '<input>.min.lua' if no value is passed
]]
    msg = msg:format(name)
    print(msg)
    return
end

local Locals = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

---@param an Analyzer
---@param chunk Chunk
local function renameLocals(an, chunk)
    local locals = an:getLocals(chunk:innerScope(), false)
    local h = an:getScopes(chunk)
    local cnt = {
        [chunk:innerScope()] = 0
    }

    local function getLocalIndex(scope)
        local n = cnt[scope] or getLocalIndex(h[scope])
        cnt[scope] = n + 1
        return n
    end

    local function getShortName(scope)
        local idx = getLocalIndex(scope)
        local n = idx
        assert(idx ~= nil)
        local buf = {}
        if idx >= #Locals then
            while true do
                if idx >= #Locals then
                    local mod = idx % #Locals
                    idx = idx // #Locals
                    table.insert(buf, 1, mod)
                else
                    table.insert(buf, 1, idx)
                    break
                end
            end
            for i = 2, #buf do buf[i] = buf[i] + 1 end
        else
            buf[1] = idx + 1
        end
        for i = 1, #buf do buf[i] = Locals:byte(buf[i]) end

        local q = string.char(table.unpack(buf))
        return q
    end

    local map = {}
    for _, j in pairs(locals) do
        if j.name ~= '_' then
            local declScope = an:getScope(j.decl)
            local newName = getShortName(declScope)
            if not map[newName] then
                map[newName] = {}
            end
            local t = map[newName]
            t[#t + 1] = j.name
            local tok = Token.CreateIdentifier(newName)
            for _, l in pairs(j.refs) do
                l:setName(tok)
            end
        end
    end

    return map
end

local Script, ScriptName, ScriptPath

local chunkData
if Args[1] then
    Script = shell.resolve(Args[1])
    ScriptName = fs.name(Script):gsub("%.lua$", "")
    ScriptPath = fs.path(Script)
    local f = io.open(Script)
    if not f then error("error opening file for reading: " .. Script) end
    chunkData = f:read("a")
else
    chunkData = io.stdin:read("a")
end

local p = Parser.new()
local c = p:parseChunk(chunkData)
local a = Analyzer.new()

renameLocals(a, c)
local m = a:dump(c, false, nil)

local of
if Script and Opts.o then
    local fName
    if type(Opts.o) ~= "string" then
        fs.concat(ScriptPath, ScriptName .. ".min.lua")
    else
        fName = Opts.o
    end
    local oFile = shell.resolve(fName)
    of = io.open(oFile, "w")
    if not of then error("error opening file for writing: " .. oFile) end
    of:write(m)
    of:close()
else
    io.stdout:write(m)
end
