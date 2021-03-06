if not nsh then print("No nsh session!") return end

local args = {...}

if #args < 2 then
	print("Usage: binput <local> <remote>")
	print("<local>: any file on the client")
	print("<remote>: any file on the server")
	return
end

local fileData = ""

nsh.send("FQ:;b="..args[1])
local message = nsh.receive()
if message ~= "fileNotFound" then
	while true do
		message = nsh.receive()
		pType = string.sub(message, 1, 2)
		if pType == "FD" then
			fileData = fileData..string.match(message, "^FD:;b=(.*)")
		elseif pType == "FE" then
			break
		end
	end
	if #fileData > 0 then
		nsh.unpackAndSaveFile(args[2], fileData)
	else
		print("Empty file not written!")
	end
end