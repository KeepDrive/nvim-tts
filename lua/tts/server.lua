local loop = vim.loop
local config = require("tts.config").server

local public = {}

local function stop_listener(listener)
	local client = listener.client
	if client then
		client:read_stop()
		client:close()
	end
	listener.handle:close()
end

function public.start_listener(ip, port, reader)
	local handle = loop.new_tcp()
	local listener = { handle = handle, client = nil, close = stop_listener }
	handle:bind(ip, port)
	handle:listen(config.tcp_backlog, function(err)
		assert(not err, err)
		local client = loop.new_tcp()
		handle:accept(client)
		listener.client = client
		client:read_start(function(err, data)
			assert(not err, err)
			if not data then
				client:read_stop()
				client:close()
				return
			end
			reader(data)
		end)
	end)
	return listener
end

local function connect_sender_handle(handle, ip, port)
	handle:connect(ip, port, function(err)
		if err then
			print("Sender connection failed with error " .. err .. ", retrying")
			connect_sender_handle(handle, ip, port)
		end
	end)
end

local function stop_sender(sender)
	local handle = sender.handle
	handle:shutdown()
	handle:close()
end

local function sender_write(sender, data)
	sender.handle:write(data)
end

function public.start_sender(ip, port)
	local handle = loop.new_tcp()
	connect_sender_handle(handle, ip, port)
	return { handle = handle, write = sender_write, close = stop_sender }
end

return public
