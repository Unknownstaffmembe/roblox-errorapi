local module = {}

function module.new_uuid()
	local Output = io.popen("uuidgen")
	local String = Output:read()
	Output:close()
	return String
end

return module
