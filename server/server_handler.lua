local module = {}
local http_server = require("http.server")
local http_headers = require("http.headers")
local api_methods = require("api_methods")

local endpoint_not_found_headers = http_headers.new()
endpoint_not_found_headers:append(":status", "401")

local function endpoint_not_found(server, stream)
	stream:write_headers(enpoint_not_found_headers, true)
	stream:shutdown()
end

function print_table(table)
	for i, v in pairs(table) do
		print(i, v)
		if type(v) == "table" then
			print_table(v)
		end
	end
end

function module.new(options)
	local object = setmetatable({}, api_methods)
	local endpoints = {}
	object.endpoints = endpoints

	options.onstream = function(server, stream)
		local headers = stream:get_headers()
		local endpoint = endpoints[headers:get("endpoint")] or endpoint_not_found
		local success, error_message = pcall(endpoint, server, stream)
		if not success then
			print(error_message)
		end
	end

	object.server = http_server.listen(options)
	return object
end

return module
