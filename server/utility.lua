if utility_module then return utility_module end
local module = {}

function module.new_uuid()
	local Output = io.popen("uuidgen")
	local String = Output:read()
	Output:close()
	return String
end

utility_module = module
return module
