local loop = vim.loop
local config = require("tts.config").server

local public = {}

local function start_client(server)
	assert(server, "No server provided for client")
	local client = loop.new_tcp()
	server:accept(client)
	return client
end

local function stop_client(client)
	if not client then
		return
	end
	client:read_stop()
	client:shutdown()
	client:close()
end

local function get_server_client(server)
	return getmetatable(server).client
end

function public.start_listener(ip, port, reader)
	local server = loop.new_tcp()
	server:bind(ip, port)
	server:listen(config.tcp_backlog, function(err)
		assert(not err, err)
		local client = start_client(server)
		local server_metatable = { client = client }
		setmetatable(server, server_metatable)
		client:read_start(function(err, data)
			assert(not err, err)
			if not data then
				client:read_stop()
				return
			end
			reader(data)
		end)
	end)
	return server
end

function connect_sender(sender, ip, port)
	sender:connect(ip, port, function(err)
		if err then
			print("Sender connection failed with error " .. err .. ", retrying")
			connect_sender(sender, ip, port)
		end
	end)
end

function public.start_sender(ip, port)
	local sender = loop.new_tcp()
	connect_sender(sender, ip, port)
	return sender
end

function public.stop_handle(handle)
	if not handle then
		return
	end
	stop_client(get_server_client(handle))
	handle:shutdown()
	handle:close()
end

return public
