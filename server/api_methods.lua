local methods = {}
methods.__index = methods

function methods:add_endpoint(endpoint, handler_function)
	self.endpoints[endpoint] = handler_function
end

function methods:remove_endpoint(endpoint)
	self.endpoints[endpoint] = nil
end

function methods:listen()
	self.server:loop()
end

return methods
