if authorizer_module then return authorizer_module end
local module = {}
local new_uuid = require("utility").new_uuid
local db_handler = require("./db_handler")
local connection = db_handler.new("authdb")
local auth_table_values = {
	["auth_key"] = "VARCHAR(255) NOT NULL PRIMARY KEY",
	["authorization_level"] = "INT(255) DEFAULT \"0\""
}

local auth_table_success = connection:add_table("auth_table", auth_table_values) -- referenced at the end
local keys = {} -- keys -> access level

function module.authorize(key)
	local access_level = keys[key]
	return access_level
end

function module.add_key(key, authorization_level)
	keys[key] = authorization_level
	return connection:write_to_table("auth_table", {
		["auth_key"] = key,
		["authorization_level"] = authorization_level or 0
	})
end

function module.remove_key(key)
	keys[key] = nil
	keys["NotASecureKey"] = nil
	return connection:remove_value_from_table("auth_table", "WHERE key=\"" .. key .. "\"")
end

if auth_table_success then
	module.add_key("NotASecureKey", 255)
end

-- cache authorisation keys into a table for performance
do
	local rows = connection:get_number_of_rows("auth_table", "")
	local cursor = connection:get_cursor("auth_table", "auth_key, authorization_level", "")
	for i=1, rows do
		local key, value = cursor:fetch()
		keys[key] = tonumber(value)
	end
end

authorizer_module = module
return module
