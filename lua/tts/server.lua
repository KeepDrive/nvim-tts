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

function public.start_server(ip, port)
	local server = uv.new_tcp()
	server:bind(ip, port)
	server:listen(config.tcp_backlog, function(err)
		assert(not err, err)
		local client = start_client(server)
		local server_metatable = { client = client }
		setmetatable(server, server_metatable)
	end)
	return server
end

function public.stop_server(server)
	if server == nil then
		return
	end
	stop_client(get_server_client(server))
	server:shutdown()
	server:close()
end

function public.server_listen(server, reader)
	get_server_client(server):read_start(function(err, data)
		assert(not err, err)
		reader(data)
	end)
end

function public.server_send(server, data)
	get_server_client(server):write(data)
end

return public
