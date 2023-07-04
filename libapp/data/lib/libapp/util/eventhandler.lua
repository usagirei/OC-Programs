local event = require("event")

local Class = require("libapp.class")

---@class EventHandler : Object
local EventHandler = Class.NewClass(nil, "EventHandler")

---@return EventHandler
function EventHandler.new()
	return Class.NewObj(EventHandler)
end

function EventHandler:pumpMessages(timeout)
	local args = { event.pull(timeout) }
	local msg = args[1]

	local handler = self[msg]
	local handled
	if handler == nil then
		handled = self.default(table.unpack(args))
	else
		handled = handler(select(2, table.unpack(args)))
	end
	return msg, handled
end

function EventHandler.default(msg, ...)
	return false
end

return EventHandler
