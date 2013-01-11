local tArgs = { ... }

local connections = {}

local packetConversion = {
	query = "SQ",
	response = "SR",
	data = "SP",
	close = "SC",
	textWrite = "TW",
	textCursorPos = "TC",
	textGetCursorPos = "TG",
	textGetSize = "TD",
	textInfo = "TI",
	textClear = "TE",
	textClearLine = "TL",
	textScroll = "TS",
	textBlink = "TB",
	textColor = "TF",
	textBackground = "TK",
	textIsColor = "TA",
	event = "EV",
	SQ = "query",
	SR = "response",
	SP = "data",
	SC = "close",
	TW = "textWrite",
	TC = "textCursorPos",
	TG = "textGetCursorPos",
	TD = "textGetSize",
	TI = "textInfo",
	TE = "textClear",
	TL = "textClearLine",
	TS = "textScroll",
	TB = "textBlink",
	TF = "textColor",
	TK = "textBackground",
	TA = "textIsColor",
	EV = "event",
}

local function openModem()
	local modemFound = false
	for _, side in ipairs(rs.getSides()) do
		if peripheral.getType(side) == "modem" then
			if not rednet.isOpen(side) then rednet.open(side) end
			modemFound = true
			break
		end
	end
	return modemFound
end

local function send(id, type, message)
	return rednet.send(id, packetConversion[type]..":;"..message)
end

local function awaitResponse(id, time)
	id = tonumber(id)
	local listenTimeOut = nil
	local messRecv = false
	if time then listenTimeOut = os.startTimer(time) end
	while not messRecv do
		local event, p1, p2 = os.pullEvent()
		if event == "timer" and p1 == listenTimeOut then
			return false
		elseif event == "rednet_message" then
			sender, message = p1, p2
			if id == sender and message then
				if packetConversion[string.sub(message, 1, 2)] then packetType = packetConversion[string.sub(message, 1, 2)] end
				message = string.match(message, ";(.*)")
				messRecv = true
			end
		end
	end
	return packetType, message
end

local function processText(conn, pType, value)
	if not pType then return false end
	if pType == "textWrite" and value then
		term.write(value)
	elseif pType == "textClear" then
		term.clear()
	elseif pType == "textClearLine" then
		term.clearLine()
	elseif pType == "textGetCursorPos" then
		local x, y = term.getCursorPos()
		send(conn, "textInfo", math.floor(x)..","..math.floor(y))
	elseif pType == "textCursorPos" then
		local x, y = string.match(value, "(%d+),(%d+)")
		term.setCursorPos(tonumber(x), tonumber(y))
	elseif pType == "textBlink" then
		if value == "true" then
			term.setCursorBlink(true)
		else
			term.setCursorBlink(false)
		end
	elseif pType == "textGetSize" then
		x, y = term.getSize()
		send(conn, "textInfo", x..","..y)
	elseif pType == "textScroll" and value then
		term.scroll(tonumber(value))
	elseif pType == "textIsColor" then
		send(conn, "textInfo", tostring(term.isColor()))
	elseif pType == "textColor" and value then
		value = tonumber(value)
		if (value == 1 or value == 32768) or term.isColor() then
			term.setTextColor(value)
		end
	elseif pType == "textBackground" and value then
		value = tonumber(value)
		if (value == 1 or value == 32768) or term.isColor() then
			term.setBackgroundColor(value)
		end
	end
	return
end

local function textRedirect (id)
	local textTable = {}
	textTable.id = id
	textTable.write = function(text)
		return send(textTable.id, "textWrite", text)
	end
	textTable.clear = function()
		return send(textTable.id, "textClear", "nil")
	end
	textTable.clearLine = function()
		return send(textTable.id, "textClearLine", "nil")
	end
	textTable.getCursorPos = function()
		if send(textTable.id, "textGetCursorPos", "nil") then
			local pType, message = awaitResponse(textTable.id, 2)
			if pType and pType == "textInfo" then
				local x, y = string.match(message, "(%d+),(%d+)")
				return tonumber(x), tonumber(y)
			end
		else return false end
	end
	textTable.setCursorPos = function(x, y)
		return send(textTable.id, "textCursorPos", math.floor(x)..","..math.floor(y))
	end
	textTable.setCursorBlink = function(b)
		if b then
			return send(textTable.id, "textBlink", "true")
		else
			return send(textTable.id, "textBlink", "false")
		end
	end
	textTable.getSize = function()
		if send(textTable.id, "textGetSize", "nil") then
			local pType, message = awaitResponse(textTable.id, 2)
			if pType and pType == "textInfo" then
				local x, y = string.match(message, "(%d+),(%d+)")
				return tonumber(x), tonumber(y)
			end
		else return false end
	end
	textTable.scroll = function(lines)
		return send(textTable.id, "textScroll", lines)
	end
	textTable.isColor = function()
		if send(textTable.id, "textIsColor", "nil") then
			local pType, message = awaitResponse(textTable.id, 2)
			if pType and pType == "textInfo" then
				if message == "true" then
					return true
				end
			end
		end
		return false
	end
	textTable.isColour = textTable.isColor
	textTable.setTextColor = function(color)
		return send(textTable.id, "textColor", tostring(color))
	end
	textTable.setTextColour = textTable.setTextColor
	textTable.setBackgroundColor = function(color)
		return send(textTable.id, "textBackground", tostring(color))
	end
	textTable.setBackgroundColour = textTable.setBackgroundColor
	return textTable
end

local function newSession()
	local path = "/rom/programs/shell"
	if #tArgs >= 2 and shell.resolveProgram(tArgs[2]) then path = shell.resolveProgram(tArgs[2]) end
	local sessionThread = coroutine.create(function() shell.run(path) end)
	return sessionThread
end

if #tArgs >= 1 and tArgs[1] == "host" then
	if not openModem() then return end
	local connInfo = {}
	connInfo.target = term.native
	local path = "/rom/programs/shell"
	if #tArgs >= 3 and shell.resolveProgram(tArgs[3]) then path = shell.resolveProgram(tArgs[3]) end
	connInfo.thread = coroutine.create(function() shell.run(path) end)
	connections.localShell = connInfo
	term.clear()
	term.setCursorPos(1,1)
	coroutine.resume(connections.localShell.thread)

	while true do
		event = {os.pullEvent()}
		if event[1] == "rednet_message" then
			if packetConversion[string.sub(event[3], 1, 2)] then
				--this is a packet meant for us.
				conn = event[2]
				packetType = packetConversion[string.sub(event[3], 1, 2)]
				message = string.match(event[3], ";(.*)")
				if connections[conn] and connections[conn].status == "open" then
					if packetType == "event" or string.sub(packetType, 1, 4) == "text" then
						local eventTable = {}
						if packetType == "event" then
							eventTable = textutils.unserialize(message)
						else
							--we can pass the packet in raw, since this is not an event packet.
							eventTable = event
						end
						if not connections[conn].filter or eventTable[1] == connections[conn].filter then
							connections[conn].filter = nil
							term.redirect(connections[conn].target)
							passback = {coroutine.resume(connections[conn].thread, unpack(eventTable))}
							if coroutine.status(connections[conn].thread) == "dead" then
								send(conn, "close", "disconnect")
								table.remove(connections, conn)
							end
							if passback[2] then
								connections[conn].filter = passback[2]
							end
							term.restore()
						end
					elseif packetType == "query" then
						--reset connection
						connections[conn].status = "open"
						connections[conn].target = textRedirect(conn)
						connections[conn].thread = newSession()
						send(conn, "response", "OK")
						term.redirect(connections[conn].target)
						coroutine.resume(connections[conn].thread)
						term.restore()
					elseif packetType == "close" then
						table.remove(connections, conn)
						send(conn, "close", "disconnect")
						--close connection
					else
						--error
					end
				elseif packetType ~= "query" then
					--usually, we would send a disconnect here, but this prevents one from hosting nsh and connecting to other computers.  Pass these to all shells as well.
					for cNum, cInfo in pairs(connections) do
						if not cInfo.filter or event[1] == cInfo.filter then
							cInfo.filter = nil
							term.redirect(cInfo.target)
							passback = {coroutine.resume(cInfo.thread, unpack(event))}
							if passback[2] then
								cInfo.filter = passback[2]
							end
							term.restore()
						end
					end
				else
					--open new connection
					local connInfo = {}
					connInfo.status = "open"
					connInfo.target = textRedirect(conn)
					connInfo.thread = newSession()
					send(conn, "response", "OK")
					connections[conn] = connInfo
					term.redirect(connInfo.target)
					coroutine.resume(connInfo.thread)
					term.restore()
				end
			else
				--rednet message, but not in the correct format, so pass to all shells.
				for cNum, cInfo in pairs(connections) do
					if not cInfo.filter or event[1] == cInfo.filter then
						cInfo.filter = nil
						term.redirect(cInfo.target)
						passback = {coroutine.resume(cInfo.thread, unpack(event))}
						if passback[2] then
							cInfo.filter = passback[2]
						end
						term.restore()
					end
				end
			end
		elseif event[1] == "mouse_click" or event[1] == "mouse_drag" or event[1] == "mouse_scroll" or event[1] == "key" or event[1] == "char" then
			--user interaction.
			coroutine.resume(connections.localShell.thread, unpack(event))
			if coroutine.status(connections.localShell.thread) == "dead" then
				for cNum, cInfo in pairs(connections) do
					if cNum ~= "localShell" then
						send(cNum, "close", "disconnect")
					end
				end
				return
			end
		else
			--dispatch all other events to all shells
			for cNum, cInfo in pairs(connections) do
				if not cInfo.filter or event[1] == cInfo.filter then
					cInfo.filter = nil
					term.redirect(cInfo.target)
					passback = {coroutine.resume(cInfo.thread, unpack(event))}
					if passback[2] then
						cInfo.filter = passback[2]
					end
					term.restore()
				end
			end
		end
	end

elseif #tArgs == 1 then
	if not openModem() then return end
	local serverNum = tonumber(tArgs[1])
	send(serverNum, "query", "connect")
	local pType, message = awaitResponse(serverNum, 2)
	if pType ~= "response" then
		print("Connection Failed")
		return
	else
		term.clear()
		term.setCursorPos(1,1)
	end

	while true do
		event = {os.pullEvent()}
		if event[1] == "rednet_message" then
			if packetConversion[string.sub(event[3], 1, 2)] then
				packetType = packetConversion[string.sub(event[3], 1, 2)]
				message = string.match(event[3], ";(.*)")
				if string.sub(packetType, 1, 4) == "text" then
					processText(serverNum, packetType, message)
				elseif packetType == "close" then
					if term.isColor() then
						term.setBackgroundColor(colors.black)
						term.setTextColor(colors.white)
					end
					term.clear()
					term.setCursorPos(1, 1)
					print("Connection closed by server.")
					return
				end
			end
		elseif event[1] == "mouse_click" or event[1] == "mouse_drag" or event[1] == "mouse_scroll" or event[1] == "key" or event[1] == "char" then
			--pack up event
			send(serverNum, "event", textutils.serialize(event))
		end
	end
else
	print("Usage: nsh <serverID>")
	print("       nsh host [remote [local]]")
end