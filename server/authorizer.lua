local module = {}
local db_handler = require("db_handler")
local connection = db_handler.new("auth.db")
local values = {
	["key"] = "varchar(255) NOT NULL PRIMARY KEY",
	["authorization_level"] = "int DEFAULT \"0\""
}
connection:add_table("auth_table", values)

function module.authorize(key)
	local success, authorization_level = connection:get_value("auth_table", "WHERE Key=\"" .. key .. "\";")
	return success and authorization_level or nil
end

function module.add_key(key, authorization_level)
	return connection:write_to_table("auth_table", {
		["key"] = key,
		["authorization_level"] = authorization_level or 0
	})
end

function module.remove_key(key)
	return connection:remove_value_from_table("auth_table", "WHERE key=\"" .. key .. "\"")
end

module.add_key("Noice", 255)

return module
