local component = require('component')
local Class = require("libapp.class")
local Args = require("libapp.util.args")

---@class OcComp : Object
local OcComp = Class.NewClass(nil, "OcComp")

---@param addr string
function OcComp:init(addr)
    Args.isValue(1, addr, Args.ValueType.String)
    local fullAddr = component.get(addr)
    assert(fullAddr ~= nil, "no such component")
    self.m_Proxy = component.proxy(fullAddr)
    self.m_Fields = component.fields(fullAddr)
    self.m_Methods = component.methods(fullAddr)
end

function OcComp:type()
    return self.m_Proxy.type
end

function OcComp:proxy()
    return self.m_Proxy
end

---@param method string
---@param ... any
---@return any
function OcComp:invoke(method, ...)
    if self.m_Methods[method] == nil then
        error('invalid method: ' .. method)
    end
    return self.m_Proxy[method](...)
end

return OcComp