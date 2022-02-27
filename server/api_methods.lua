local methods = {}
methods.__index = methods

function methods:add_endpoint(endpoint, access_level, handler_function)
	access_level = access_level or 255
	self.endpoints[endpoint] = {
		["endpoint_function"] = handler_function,
		["access_level"] = access_level
	}
end

function methods:remove_endpoint(endpoint)
	self.endpoints[endpoint] = nil
end

function methods:listen()
	self.server:loop()
end

return methods
