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
				listener.client = nil
				return
			end
			reader(data)
		end)
	end)
	return listener
end

local function connect_sender_handle(handle, ip, port, callback)
  local handle = loop.new_tcp()
	handle:connect(ip, port, function(err)
		if err then
			print("Sender connection failed with error " .. err)
      return
		end
    callback(handle)
    handle:shutdown()
    handle:close()
	end)
end

local function sender_write(sender, data)
  sender:connect(function(handle)
	  handle:write(data, function(err)
		  if err then
			  print("Sender write failed with error " .. err)
		  else
			  print("Sender write successful")
		  end
	  end)
  end)
end

function public.start_sender(ip, port)
	return {
		write = sender_write,
		connect = function(self, callback)
			connect_sender_handle(self.handle, ip, port, callback)
		end,
	}
end

return public
