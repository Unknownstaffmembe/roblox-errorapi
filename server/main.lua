-- modules
local server_handler = require("server_handler")
local db_handler = require("db_handler")
local http_headers = require("http.headers")
local json = require("cjson")

local values = {
	["entry_id"] = "INTEGER PRIMARY KEY AUTOINCREMENT",
	["server_id"] = "varchar(255)",
	["error_message"] = "varchar(8000)"
}
local connection = db_handler.new("errors.db")
print(connection:add_table("error_table", values))

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
		local error_message = data.error_message
		if server_id and error_message then
			local success, sql_error = connection:write_to_table("error_table", {
				["server_id"] = server_id,
				["error_message"] = error_message
			})
			if success then
				stream:write_headers(success_post_return_headers, true)	
			else
				stream:write_headers(error_headers, false)
				stream:write_body_from_string("server failed to save error to database\n" .. tostring(sql_error))
			end
		else
			stream:write_headers(invalid_json_return_headers, false)	
			stream:write_body_from_string("server_id/error_message not found")
		end
	else
		stream:write_headers(invalid_json_return_headers, false)
		stream:write_body_from_string("invalid json\n" .. tostring(data))
	end
	stream:shutdown()
end)

server:add_endpoint("pull", 250, function(server, stream, headers)
	local datapoints = headers:get("datapoints") or 100
	local entry_id = headers:get("entryid") or 0
	local rows = connection:get_number_of_rows("error_table", "WHERE entry_id>" .. tostring(entry_id))
	datapoints = (rows - datapoints) < 0 and rows or datapoints
	if rows ~= 0 then
		local cursor = connection:get_cursor("error_table", "WHERE entry_id>" .. tostring(entry_id) .. " ORDER BY entry_id LIMIT " .. tostring(datapoints))
		local data_table = {}
		for i=1, datapoints do
			local server_id, error_message, entry_id = cursor:fetch()
			table.insert(data_table, {
				["server_id"] = server_id,
				["error_message"] = error_message,
				["entry_id"] = entry_id
			})
		end
		data_table.next_entry_id = tostring(datapoints + entry_id)
		stream:write_headers(success_get_return_headers, false)
		stream:write_body_from_string(json.encode(data_table))
	else
		stream:write_headers(reached_end_of_db_headers, false)
		stream:write_body_from_string("reached end of database")
	end
	stream:shutdown()
end)

server:add_endpoint("execute", 255, function(server, stream)

end)

server:listen()
