local uv = vim.uv
local server
local client

local localhost = "127.0.0.1"
local port = 39998

local backlog = 5

local function start_client()
	client = uv.new_tcp()
	server:accept(client)
	client:read_start(function(err, data)
		assert(not err, err)
	end)
	print("TTS server started")
end

local function stop_client()
	if client == nil then
		return
	end
	client:shutdown()
	client:close()
	client = nil
end

local function start_server()
	server = uv.new_tcp()
	server:bind(localhost, port)
	server:listen(backlog, function(err)
		assert(not err, err)
		start_client()
	end)
end

local function stop_server()
	if server == nil then
		print("No active TTS server")
		return
	end
	stop_client()
	server:shutdown()
	server:close()
	server = nil
	print("TTS server stopped")
end

return { start_server = start_server, stop_server = stop_server }
