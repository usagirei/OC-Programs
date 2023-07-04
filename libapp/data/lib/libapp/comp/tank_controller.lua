local component = require('component')
local Args = require("libapp.util.args")

local Class = require("libapp.class")
local Super = require("libapp.comp")
---@class TankController : OcComp
local TankController = Class.NewClass(Super, "TankController")

---@param addr string
---@param side integer
---@param number integer
function TankController.new(addr, side, number)
    return Class.NewObj(TankController, addr, side, number)
end

---@param addr string
---@param side integer
---@param number integer
function TankController:init(addr, side, number)
    Args.isValue(1, addr, Args.ValueType.String)
    Args.isInteger(2, side)
    Args.isInteger(3, number)

    Super.init(self, addr)
    self.m_Side = side
    self.m_Number = number
end

---@return string
function TankController:fluidName()
    return self:invoke("getFluidInTank", self.m_Side, self.m_Number).label
end

---@return string
function TankController:fluidId()
    return self:invoke("getFluidInTank", self.m_Side, self.m_Number).name
end

---@return number
function TankController:level()
    return self:invoke("getTankLevel", self.m_Side, self.m_Number)
end

---@return number
function TankController:capacity()
    return self:invoke("getTankCapacity", self.m_Side, self.m_Number)
end

---@return TankController[]
function TankController.list()
    local comps = component.list("tank_controller")
    local arr = {}
    for fullAddr, _ in pairs(comps) do
        for tankSide = 0, 5 do
            local nTanks = component.invoke(fullAddr, 'getTankCount', tankSide)
            for tankNumber = 1, nTanks do
                arr[#arr + 1] = TankController.new(fullAddr, tankSide, tankNumber)
            end
        end
    end
    return arr
end

---@param ... string # Addresses
---@return TankController[]
function TankController.get(...)
    local args = table.pack(...)
    local arr = {}
    for i = 1, args.n do
        local addr = args[i]
        local fullAddr = component.get(addr)
        for tankSide = 0, 5 do
            local nTanks = component.invoke(fullAddr, 'getTankCount', tankSide)
            for tankNumber = 1, nTanks do
                arr[#arr + 1] = TankController.new(fullAddr, tankSide, tankNumber)
            end
        end
    end
    return arr
end

return TankController
