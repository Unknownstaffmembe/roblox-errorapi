local module = {}
local http_server = require("http.server")
local http_headers = require("http.headers")
local api_methods = require("api_methods")
local authorizer = require("authorizer")
local uuid = require("utility").new_uuid

local endpoint_not_found_headers = http_headers.new()
endpoint_not_found_headers:append(":status", "401")

local function endpoint_not_found(server, stream)
	stream:write_headers(endpoint_not_found_headers, true)
	stream:shutdown()
end

local endpoint_not_found_table = {
	["endpoint_function"] = endpoint_not_found,
	["access_level"] = 0
}

function module.new(options)
	local object = setmetatable({}, api_methods)
	local endpoints = {}
	object.endpoints = endpoints

	options.onstream = function(server, stream)
		local headers = stream:get_headers()
		local authorization = headers:get("authorization")
		local endpoint  = endpoints[headers:get("endpoint")] or endpoint_not_found_table
		local endpoint_function = endpoint.endpoint_function
		local access_level = authorizer.authorize(tostring(authorization)) or 0
		if access_level < endpoint.access_level then endpoint_function = endpoint_not_found end
		local success, error_message = pcall(endpoint_function, server, stream)
		if not success then
			print(error_message)
		end
	end

	object.server = http_server.listen(options)
	return object
end

return module
