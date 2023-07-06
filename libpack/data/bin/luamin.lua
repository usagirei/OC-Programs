local fsOk, fs = pcall(require, 'filesystem')
if not fsOk then
    local lfs = require("lfs")
    fs = {}
    function fs.name(path)
        local dir, name = path:match("^(.-)([^\\/]*)$")
        return name
    end

    function fs.path(path)
        local dir, name = path:match("^(.-)([^\\/]*)$")
        return dir:gsub("/$", "")
    end

    function fs.exists(path)
        return lfs.attributes(path, "mode") ~= nil
    end

    function fs.makeDirectory(path)
        if fs.exists(path) then return true end
        local dir = fs.path(path)
        if dir == path then
            return nil, "cannot create the root directory"
        end
        local ok, msg = fs.makeDirectory(dir)
        if not ok then return nil, msg .. " (" .. path .. ")" end
        return lfs.mkdir(path)
    end
end

local shellOk, shell = pcall(require, 'shell')
if not shellOk then
    shell = {}
    function shell.parse(...)
        return { ... }, {}
    end
end

local Parser = require("libpack.parser")
local Analyzer = require("libpack.analyzer")
local Token = require("libpack.tokenizer.token")

local Args, Opts = shell.parse(...)

if Opts.h or Opts.help or #Args == 0 then
    local script = os.getenv("_")
    local name = fs.name(script)

    local msg = [[Usage: %s [<script>] [<output>]
    Minifies the target lua script, if no input is passed, chunk data is read from stdin
    Outputs to stdout unless the second argument is passed
        --help|-h\tprints this message
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

local chunkData
if Args[1] then
    local f = io.open(Args[1])
    if not f then error("error opening file for reading: " .. Args[1]) end
    chunkData = f:read("a")
    f:close()
else
    chunkData = io.stdin:read("a")
end

local p = Parser.new()
local c = p:parseChunk(chunkData)
local a = Analyzer.new()

renameLocals(a, c)
local m = a:dump(c, false, nil)

if Args[2] then
    assert(fs.makeDirectory(fs.path(Args[2])))
    local f = io.open(Args[2], "w")
    if not f then error("error opening file for writing: " .. Args[2]) end
    f:write(m)
    f:close()
    io.stdout:write("OK\n")
else
    io.stdout:write(m)
    io.stderr:write("OK\n")
end
