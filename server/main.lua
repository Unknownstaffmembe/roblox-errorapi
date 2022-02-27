-- modules
local server_handler = require("server_handler")
local db_handler = require("db_handler")
local http_headers = require("http.headers")
local json = require("cjson")

local values = {
	["entry_id"] = "int IDENTITY(1,1) PRIMARY KEY",
	["server_id"] = "varchar(255)",
	["error_message"] = "varchar(8000)"
}
local connection = db_handler.new("errors.db")
connection:add_table("error_table", values)

-- configs
local server_options = require("options.server")
local success_return_headers = http_headers.new()
success_return_headers:append(":status", "200")
local invalid_json_return_headers = http_headers.new()
invalid_json_return_headers:append(":status", "400")
invalid_json_return_headers:append("Content-Type", "text/plain")
local error_headers = http_headers.new()
error_headers:append(":status", "500")
error_headers:append("Content-Type", "text/plain")

local server = server_handler.new(server_options)

local function decode(encoded_table)
	return json.decode(encoded_table)
end

server:add_endpoint("errors", 250, function(server, stream)
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
				stream:write_headers(success_return_headers, true)	
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

server:add_endpoint("pull", 255, function(server, stream)

end)

server:add_endpoint("execute", 255, function(server, stream)

end)

server:listen()
