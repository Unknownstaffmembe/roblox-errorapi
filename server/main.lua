local http_headers = require("http.headers")
local server_handler = require("server_handler")
local db_handler = require("db_handler")
local json = require("cjson")
local new_uuid = require("utility").new_uuid

local main_table_values = {
	["entry_id"] = "INTEGER PRIMARY KEY AUTOINCREMENT",
	["error_hash"] = "varchar(255) NOT NULL UNIQUE",
	["error_message"] = "varchar(8000)",
	["frequency"] = "int"
}

local error_table_values = {
	["entry_id"] = "INTEGER PRIMARY KEY AUTOINCREMENT",
	["server_id"] = "varchar(255) NOT NULL UNIQUE",
	["frequency"] = "bigint"
}

local timestamp_table_values = {
	["entry_id"] = "INTEGER PRIMARY KEY AUTOINCREMENT",
	["time"] = "bigint"
}

-- error_table
-- entry_id, error_hash, error_message, frequency
--    1    , 1234567890, error_line_10, 123456789

-- [error_hash] Some error hash ^^
-- 1234567890
-- entry_id, server_id, frequency
--    1    , 987654321, 100000000

-- [error_hash + server_id] ^^
-- 1234567890 + 987654321
-- entry_id, time
--    1    , 1234567
--    2    , 1234568



local hashes = {}

local connection = db_handler.new("errors.db")
connection:add_table("error_table", main_table_values)

do
	local cursor = connection:get_cursor("error_table", "error_hash", "")
	if not cursor then return end
	local rows = connection:get_number_of_rows("error_table", "", "")
	for i=1, rows do
		local hash = cursor:fetch()
		hashes[hash] = true -- we could index the database directly but, this allows for quicker lookups/checks and, as long as you don't have 10 million + records, you should be fine
	end
end

-- configs
local server_options = require("options.server")
local success_post_return_headers = http_headers.new()
success_post_return_headers:append(":status", "200")
local success_get_return_headers = http_headers.new()
success_get_return_headers:append(":status", "200")
success_get_return_headers:append("Content-Type", "json/application")
local invalid_json_return_headers = http_headers.new()
invalid_json_return_headers:append(":status", "400")
invalid_json_return_headers:append("Content-Type", "text/plain")
local error_headers = http_headers.new()
error_headers:append(":status", "500")
error_headers:append("Content-Type", "text/plain")
local reached_end_of_db_headers = http_headers.new()
reached_end_of_db_headers:append(":status", "404") 
reached_end_of_db_headers:append("Content-Type", "text/plain")

local server = server_handler.new(server_options)

local function decode(encoded_table)
	return json.decode(encoded_table)
end

-- enpoint, required access level, handler function
server:add_endpoint("errors", 250, function(server, stream, headers)
	local body = stream:get_body_as_string()
	local success, data = pcall(decode, body)
	if success then
		local server_id = data.server_id
		local errors_table = data.errors
		local hashes_table = data.hashes
		local return_hashes = 0
		local return_hashes_table = {}

		for error_hash, error_message in pairs(errors_table) do
			connection:write_to_table("error_table", {
				["error_hash"] = error_hash,
				["error_message"] = error_message,
				["frequency"] = 0
			})
			connection:add_table(error_hash, error_table_values)
			connection:write_to_table(error_hash, {["server_id"] = server_id, ["frequency"] = 0})
			connection:add_table(error_hash .. server_id, timestamp_table_values)
			hashes[error_hash] = true
		end

		for error_hash, time_table in pairs(hashes_table) do
			if hashes[error_hash] then
				connection:write_to_table(error_hash, {["server_id"] = server_id, ["frequency"] = 0})
				local timestamp_table_string = error_hash .. server_id
				local timestamps = time_table.timestamps
				local frequency = tostring(time_table.frequency)
				local timestamp_template = {["time"] = 0}
				connection:increment_value(error_hash, "frequency = frequency + " .. frequency, "WHERE server_id=\"" .. server_id .. "\"")
				connection:increment_value("error_table", "frequency = frequency + " .. frequency, "WHERE error_hash=\"" .. error_hash .. "\"")
				for _, timestamp in pairs(timestamps) do
					timestamp_template["time"] = timestamp
					connection:write_to_table(timestamp_table_string, timestamp_template)
				end
			else
				return_hashes = return_hashes + 1
				table.insert(return_hashes_table, error_hash)
			end
		end
		
		stream:write_headers(success_get_return_headers, false)	
		stream:write_body_from_string(json.encode({
			["return_hashes"] = return_hashes,
			["return_hashes_table"] = return_hashes_table
		}))
	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
	stream:shutdown()
end)

server:add_endpoint("remove", 255, function(server, stream, headers)
	local body = stream:get_body_as_string()	
	local success, data = pcall(decode, body)
	if success then
		for _, entry_id in pairs(data) do
			connection:remove_value_from_table("error_table", "WHERE entry_id=" .. tostring(entry_id));
		end
	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
end)

server:add_endpoint("pull", 255, function(server, stream, headers)
	local datapoints = headers:get("datapoints") or 100
	local entry_id = headers:get("entryid") or 0
	local rows = connection:get_number_of_rows("error_table", "WHERE entry_id>" .. tostring(entry_id))
	datapoints = (rows - datapoints) < 0 and rows or datapoints
	if rows ~= 0 then
		local cursor = connection:get_cursor("error_table", "entry_id, server_id, unix_time, error_message", "WHERE entry_id>" .. tostring(entry_id) .. " ORDER BY entry_id LIMIT " .. tostring(datapoints))
		local data_table = {}
		for i=1, datapoints - 1 do
			local entry_id, server_id, unix_time, error_message = cursor:fetch()
			table.insert(data_table, {
				["server_id"] = server_id,
				["error_message"] = error_message,
				["unix_time"] = unix_time,
				["entry_id"] = entry_id
			})
		end
		local entry_id, server_id, unix_time, error_message = cursor:fetch() -- records can be removed and, we may end up sending back the next entry_id to use so, this is a little horribly designed/implmemented hacky method to get the next smallest entry_id
		table.insert(data_table, {
			["server_id"] = server_id,
			["error_message"] = error_message,
			["unix_time"] = unix_time,
			["entry_id"] = entry_id
		})
		data_table.next_entry_id = tostring(entry_id + 1)
		stream:write_headers(success_get_return_headers, false)
		stream:write_body_from_string(json.encode(data_table))
	else
		stream:write_headers(reached_end_of_db_headers, false)
		stream:write_body_from_string("reached end of database")
	end
	stream:shutdown()
end)

server:add_endpoint("addkey", 255, function(server, stream, headers)
	local body = stream:get_body_as_string()	
	local success, data = pcall(decode, body)
	if successs then
		for key, authorization_level in pairs(data) do
			authorization.new_key(key, authorization_level)
		end
		stream:write_headers(success_post_return_headers, true)
	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
	stream:shutdown()

end)

server:add_endpoint("removekey", 255, function(server, stream, headers)
	local body = stream:get_body_as_string()
	local success, data = pcall(decode, body)
	if success then
		for _, key in pairs(data) do
			authorizer.remove_key(key)	
		end
		stream:write_headers(success_post_return_headers, true)
	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
	stream:shutdown()
end)

server:add_endpoint("changekey", 255, function(server, stream, headers)
	local body = stream:get_body_as_string()
	local success, data = pcall(decode, body)
	if success then
		for key, new_key_table in pairs(data) do
			local new_key = new_key_table.key
			local authorization_level = new_key_table.level or 0
			authorizer.remove_key(key)
			authorizer.add_key(new_key, authorization_level)
		end
		stream:write_headers(success_post_return_headers, true)

	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
	stream:shutdown()
end)

server:listen()
