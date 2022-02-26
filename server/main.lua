-- modules
local server_handler = require("server_handler")
local http_headers = require("http.headers")
local json = require("cjson")

-- configs
local server_options = require("options.server")
local success_return_headers = http_headers.new()
success_return_headers:append(":status", "200")

local server = server_handler.new(server_options)

server:add_endpoint("errors", function(server, stream)
	local body = stream:get_body_as_string()
	stream:write_headers(success_return_headers, true)
end)

server:add_endpoint("test", function(server, stream)
	local body = stream:get_body_as_string()	
	stream:write_headers(success_return_headers, true)
end)

server:listen()
