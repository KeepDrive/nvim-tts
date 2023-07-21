local uv = vim.loop

local config = require("tts.config").server

local public = {}

local function start_client(server)
	assert(server, "No server provided for client")
	local client = uv.new_tcp()
	server:accept(client)
	return client
end

local function stop_client(client)
	if not client then
		return
	end
	client:shutdown()
	client:close()
end

local function get_server_client(server)
	return getmetatable(server).client
end

function public.start_server(ip, port, on_connect)
	local server = uv.new_tcp()
	server:bind(ip, port)
	server:listen(config.tcp_backlog, function(err)
		assert(not err, err)
		local client = start_client(server)
		local server_metatable = { client = client }
		setmetatable(server, server_metatable)
		if on_connect then
			on_connect(client)
		end
	end)
	return server
end

function public.stop_server(server)
	if not server then
		return
	end
	stop_client(get_server_client(server))
	server:shutdown()
	server:close()
end

function public.client_listen(client, reader)
	client:read_start(function(err, data)
		assert(not err, err)
		reader(data)
	end)
end

function public.server_send(server, data)
	local client = get_server_client(server)
	if not client then
		print("Sender server not connected")
		return
	end
	client:write(data)
end

return public
