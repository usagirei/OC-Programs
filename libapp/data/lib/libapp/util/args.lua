local Class = require("libapp.class")
local Enum = require("libapp.enum")

local Args = {}

---@enum ValueType
Args.ValueType = {
	Number = "number",
	String = "string",
	Boolean = "boolean",
	Table = "table",
	Function = "function"
}
Enum.NewEnum("ValueType", Args.ValueType)

local function argName(argIndex)
	local name = debug.getlocal(4, argIndex)
	if name == "self" then
		name = debug.getlocal(4, argIndex + 1)
	end
	return name
end

---@param argIndex integer
---@param argVal any
---@param enum Enum
---@param allowNil? boolean
function Args.isEnum(argIndex, argVal, enum, allowNil)
	allowNil = allowNil or false
	if argVal == nil and not allowNil then
		local msg = { "argument error: ", argName(argIndex), " - expected '", enum.name, "', got 'nil' instead" }
		error(table.concat(msg), 3)
	elseif not enum.hasValue(argVal) then
		local msg = { "argument error: ", argName(argIndex), " - invalid value for enum '", enum.name, "'" }
		error(table.concat(msg), 3)
	end
end

---@param argIndex integer
---@param argVal any
---@param allowNil? boolean
function Args.isArray(argIndex, argVal, allowNil)

end

---@param argIndex integer
---@param argVal any
---@param allowNil? boolean
function Args.isInteger(argIndex, argVal, allowNil)
	allowNil = allowNil or false
	if argVal == nil then
		if not allowNil then
			local msg = { "argument error: ", argName(argIndex), " - expected an integer, got 'nil' instead" }
			error(table.concat(msg), 3)
		end
	elseif type(argVal) == "number" then
		if math.floor(argVal) ~= argVal then
			local msg = { "argument error: ", argName(argIndex), " - expected an integer but got a real number instead" }
			error(table.concat(msg), 3)
		end
	else
		local msg = { "argument error: ", argName(argIndex), " - expected an integer, got '", type(argVal), "' instead" }
		error(table.concat(msg), 3)
	end
end

---@param argIndex integer # Name
---@param argVal any # Value
---@param expected ValueType # Value Type
---@param allowNil? boolean # Defaults to false
function Args.isValue(argIndex, argVal, expected, allowNil)
	allowNil = allowNil or false
	if argVal == nil then
		if not allowNil then
			local msg = {
				"argument error: ", argName(argIndex), " - expected '", expected,
				"', got 'nil' instead"
			}
			error(table.concat(msg), 3)
		end
	elseif type(argVal) ~= expected then
		local msg = {
			"argument error: ", argName(argIndex), " - expected '", expected,
			"', got '", type(argVal), "' instead"
		}
		error(table.concat(msg), 3)
	end
end

---@param argIndex integer # Name
---@param argVal any # Value
---@param expected table|string # Class, or require path for class
---@param allowNil? boolean # Defaults to false
function Args.isClass(argIndex, argVal, expected, allowNil)
	if type(expected) == "string" then
		expected = require(expected)
	end
	allowNil = allowNil or false
	local argType = type(argVal)
	if argVal == nil then
		if not allowNil then
			local msg = { "argument error: ", argName(argIndex), " - expected '", expected.name, "', got 'nil' instead" }
			error(table.concat(msg), 3)
		end
	elseif argType == "table" then
		local ok = Class.IsInstance(argVal, expected)
		if ok then return end
		local msg = {
			"argument error: ", argName(argIndex), " - expected '", expected.name,
			"', got '", argVal.class and argVal.class.name or argType, "' instead"
		}
		error(table.concat(msg), 3)
	else
		local msg = {
			"argument error: ", argName(argIndex), " - expected '", expected.name,
			"', got '", argType, "' instead"
		}
		error(table.concat(msg), 3)
	end
end

---@param argIndex integer # Name
---@param argVal any # Value
---@param allowNil boolean
---@param ... ValueType # Value Type
function Args.isAnyValue(argIndex, argVal, allowNil, ...)
	local args = table.pack(...)
	assert(args.n ~= 0, "bad value list")
	local valType = type(argVal)

	local ok = false
	if argVal == nil then
		ok = allowNil
	else
		for i = 1, args.n do
			ok = ok or (valType == args[i])
		end
	end

	if not ok then
		local okTypesStr = table.concat(args, ", ")
		local msg = {
			"argument error: ", argName(argIndex), " - expected one of '", okTypesStr,
			"', got '", valType, "' instead"
		}
		error(table.concat(msg), 3)
	end
end

---@param argIndex integer # Name
---@param argVal any # Value
---@param allowNil boolean
---@param ... table|string # Class or require path for class
function Args.isAnyClass(argIndex, argVal, allowNil, ...)
	local args = table.pack(...)
	assert(args.n ~= 0, "bad class list")

	local ok = false
	if argVal == nil then
		ok = allowNil
	else
		for i = 1, args.n do
			if type(args[i]) == "string" then
				args[i] = require(args[i])
			end
			ok = ok or Class.IsInstance(argVal, args[i])
		end
	end

	if not ok then
		local msg

		local okTypes = {}
		for i = 1, args.n do
			okTypes[#okTypes + 1] = args[i].name
		end
		local okTypesStr = table.concat(okTypes, ", ")

		msg = {
			"argument error: ", argName(argIndex), " - expected one of '", okTypesStr,
			"', got '", argVal.class and argVal.class.name or type(argVal), "' instead"
		}
		error(table.concat(msg), 3)
	end
end

--

local SavedFuncs = {}
for k, v in pairs(Args) do
	if type(v) == Args.ValueType.Function then
		SavedFuncs[k] = v
	end
end

Args.m_Enabled = true
---@param enable boolean
function Args.setActive(enable)
	if enable then
		for k, v in pairs(SavedFuncs) do
			if type(v) == Args.ValueType.Function then
				Args[k] = SavedFuncs[k]
			end
		end
	else
		for k, v in pairs(SavedFuncs) do
			if type(v) == Args.ValueType.Function then
				Args[k] = function(...) end
			end
		end
	end
end
Args.setActive(false)

return Args
