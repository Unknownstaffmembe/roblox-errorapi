if db_handler_module then return db_handler_module end
local module = {}
local methods = {}
local environment = require("luasql.sqlite3").sqlite3()
methods.__index = methods

function module.new(db_name)
	local object = setmetatable({}, methods)
	local connection = environment:connect("db/" .. db_name)
	object.connection = connection

	return object
end

-- values: key: string = type: string
function methods:add_table(name, values, overwrite)
	local connection = self.connection

	local exec_string = "CREATE TABLE \"" .. name .. "\" ("
	for key, value_type in pairs(values) do
		exec_string = exec_string .. key .. " " .. value_type .. ", "
	end
	exec_string = string.sub(exec_string, 1, -3) .. ")"
	if overwrite then connection:execute("DROP TABLE \"" .. name .. "\"") end
	return connection:execute(exec_string)
end

function methods:remove_table(name)
	return self.connection:execute("DROP TABLE \"" .. name .. "\"")
end

-- values: key: string = value
function methods:write_to_table(name, values)
	local connection = self.connection	

	local exec_string = "INSERT INTO \"" .. name .. "\" ("
	local values_string = "VALUES ("
	for key, value in pairs(values) do
		exec_string = exec_string .. key .. ", "
		values_string = values_string .. "\"" ..tostring(value) .. "\", "
	end
	exec_string = string.sub(exec_string, 1, -3) .. ") "
	values_string = string.sub(values_string, 1, -3) .. ")"
	return connection:execute(exec_string .. values_string)
end

function methods:remove_value_from_table(name, condition)
	return self.connection:execute("DELETE FROM \"" .. name .. "\" " .. condition .. ";")
end

function methods:get_value(name, condition)
	return self.connection:execute("SELECT * FROM \"" .. name .. "\" " .. condition .. ";"):fetch()
end

function methods:increment_value(name, value, condition)
	return self.connection:execute("UPDATE \"" .. name .. "\" SET " .. value .. " " .. condition .. ";")
end

function methods:get_cursor(name, order, condition)
	return self.connection:execute("SELECT " .. order .. " FROM \"" .. name .. "\" " .. condition .. ";")
end

function methods:get_number_of_rows(name, condition)
	return self.connection:execute("SELECT COUNT(*) FROM \"" .. name .. "\" " .. condition .. ";"):fetch()
end

function methods:execute(command)
	return self.connection:execute(command)
end

db_handler_module = module
return module
