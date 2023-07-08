local lfs = require("lfs")

local function escape(c)
    local m = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }
    return m[c] or string.format("\\u%04x", c:byte())
end

local encoders

local function is_array(tbl)
    local i = 0
    for _ in pairs(tbl) do
        i = i + 1
        if tbl[i] == nil then return false end
    end
    return true
end

---@param val table
---@param set table?
local function enc_tbl(val, set)
    set = set or {}
    assert(not set[val], "recursion")
    set[val] = true

    if is_array(val) then
        local r = {}
        for k, v in ipairs(val) do
            local vf = assert(encoders[type(v)], "unsupported value")
            r[#r + 1] = vf(v, set)
        end
        return "[" .. table.concat(r, ",") .. "]"
    else
        local r = {}
        for k, v in pairs(val) do
            if type(k) ~= string then k = tostring(k) end
            local kf = encoders["string"]
            local vf = assert(encoders[type(v)], "unsupported value")
            r[#r + 1] = kf(k, set) .. ":" .. vf(v, set)
        end
        return "{" .. table.concat(r, ",") .. "}"
    end
end

encoders = {
    ["nil"] = function(v, s) return "null" end,
    ["number"] = function(v, s) return string.format("%.14g", v) end,
    ["boolean"] = function(v, s) return tostring(v) end,
    ["string"] = function(v, s) return '"' .. v:gsub('[%z\1-\31\\"]', escape) .. '"' end,
    ["table"] = enc_tbl
}

local function fread(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local s = f:read("l")
    f:close()
    return s
end

local function pread(cmd)
    local f = io.popen(cmd, 'r')
    if not f then return nil end
    local s = f:read("l")
    f:close()
    return s
end

local function eprint(...)
    local str = table.concat({ ... }, '\t')
    io.stderr:write(str, '\n')
end

local m = {
    include = {}
}
local prepareSetup = false
eprint("Gathering Targets")
for v in lfs.dir('.') do
    if not v:match("^%.") and lfs.attributes(v, "mode") == "directory" then
        local dist = lfs.attributes('./' .. v .. '/.dist', "mode") == "file"
        local minDist = lfs.attributes('./' .. v .. '/.min', "mode") == "file"
        local setup = lfs.attributes('./' .. v .. '/setup.cfg', "mode") == "file"

        if minDist or dist then
            prepareSetup = prepareSetup or setup
            local skip   = false
            local ref    = fread("./dist/." .. v .. ".rev")

            if ref then
                local cmd = "git diff --quiet master " .. ref .. " -- " .. v .. " && echo 'skip' || echo 'build'"
                skip = pread(cmd) == "skip"
            end

            if not skip then
                if dist then m.include[#m.include + 1] = { program = v, minified = false, writerev = true, setup = setup } end
                if minDist then
                    m.include[#m.include + 1] = {
                        program = v,
                        minified = true,
                        writerev = not dist,
                        setup = setup
                    }
                end
            end
            eprint(
                v,
                skip and 'skip' or 'build',
                dist and "regular" or '',
                minDist and "minified" or '',
                setup and "setup" or ''
            )
        end
    end
end

local doBuild = #m.include > 0

io.stdout:write('matrix=', enc_tbl(m), '\n')
io.stdout:write('build=', tostring(doBuild), '\n')
io.stdout:write('setup=', tostring(doBuild and prepareSetup), '\n')
