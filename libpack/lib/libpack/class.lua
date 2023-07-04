local lib = {}

---@class Prototype
---@field name string
---@field class table
---@field super? table

---@class Object
---@field prototype Prototype
---@field init fun(self,...)

local function array_reverse(x)
    local n, m = #x, #x / 2
    for i = 1, m do
        x[i], x[n - i + 1] = x[n - i + 1], x[i]
    end
    return x
end

---@param o? table
---@param cls table
---@param exact? boolean
function lib.IsInstance(o, cls, exact)
    if type(o) ~= "table" then return false end
    local oType = lib.TypeOf(o)
    if oType == nil then return false end
    local flag = false

    local cur = oType
    while (cur ~= nil) do
        if (cur == cls) then
            flag = true
            break
        elseif exact then
            break
        else
            cur = cur.prototype.super
        end
    end
    return flag
end

---@generic T
---@param node table
---@param class T
---@return T
function lib.Cast(node, class)
    if not lib.IsInstance(node, class) then error("invalid cast") end
    return node
end

---@param super? table
---@param name? string
function lib.NewClass(super, name)
    if name == nil then
        local file = debug.getinfo(2, "S").source
        ---@type string,string,string?
        local _
        _, name = file:match("(.-)([^\\/]+)$")
        if name:find(".", 1, true) then
            name, _ = name:match("(.+)(%.[^%.\\/]*)")
        end
    end

    local cls = setmetatable({}, { __index = super })
    local cls_mt = { __index = cls }
    cls.prototype = cls_mt
    cls.prototype.name = name
    cls.prototype.super = super
    cls.prototype.class = cls

    function cls.IsInstance(o) return lib.IsInstance(cls, o) end

    if super then
        function cls:init(...) super.init(self, ...) end
    else
        function cls:init(...) end
    end

    function cls.new(...)
        return lib.NewObj(cls, ...)
    end

    return cls
end

---@param obj Object
---@return table?
function lib.TypeOf(obj)
    if type(obj) ~= "table" then return nil end
    ---@diagnostic disable: undefined-field
    local mt = obj.prototype
    if not mt or not mt.class then return nil end
    return mt.class
    ---@diagnostic enable: undefined-field
end

---@param objOrCls table
---@return string
function lib.TypeName(objOrCls)
    if objOrCls.prototype then
        return objOrCls.prototype.name
    elseif objOrCls.class then
        return objOrCls.class.prototype.name
    else
        error('invalid class/object')
    end
end

---@param cls Object
function lib.WrapCtor(cls)
    if not cls then return end
    ---@diagnostic disable: undefined-field
    if cls.prototype.ctor then return end
    cls = cls.prototype.class

    cls.prototype.ctor = cls.init
    local initOrder = {}
    local cur = cls
    while cur ~= nil do
        initOrder[#initOrder + 1] = cur
        cur = cur.prototype.super
        if not cur then break end
        lib.WrapCtor(cur)
    end
    array_reverse(initOrder)
    local nCalls = #initOrder

    function cls:init(...)
        if rawequal(self, cls) then error("bad constructor call", 2) end
        assert(self.__ctor_calls__, "object instantiated from outside Class.NewObj")
        cls.prototype.ctor(self, ...)
        self.__ctor_calls__[#self.__ctor_calls__ + 1] = cls
        if #initOrder ~= #self.__ctor_calls__ then
            error(lib.TypeName(cls) .. ": missing super constructor call", 3)
        end
        if self.__ctor_calls__[nCalls] ~= initOrder[nCalls] then
            error(lib.TypeName(cls) .. ": wrong super constructor call order", 3)
        end
    end

    ---@diagnostic enable: undefined-field
end

---@generic T
---@param cls T
---@return T
function lib.NewObj(cls, ...)
    ---@diagnostic disable: undefined-field
    if not cls.prototype then error("invalid class", 2) end
    lib.WrapCtor(cls.prototype.class)

    local obj = {}
    setmetatable(obj, cls.prototype)

    obj.__ctor_calls__ = {}
    obj:init(...)
    obj.__ctor_calls__ = nil

    return obj
    ---@diagnostic enable: undefined-field
end

return lib
