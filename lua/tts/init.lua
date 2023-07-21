local config = require("tts.config")
local server = require("tts.server")
local project = require("tts.project")
local reader = require("tts.msg_reader")
local writer = require("tts.msg_writer")

local public = {}

local listener_server
local sender_server
local started = false

local stop_autocmd

function public.start()
	if started then
		print("TTS session is already started")
		return
	end
	listener_server = server.start_server(config.server.ip, config.server.listener_port, function(client)
		server.client_listen(client, reader.read_message)
	end)
	sender_server = server.start_server(config.server.ip, config.server.sender_port)
	project.load_project()
	started = true
	print("TTS session started")
	if config.general.use_vim_leave_autocmd and not stop_autocmd then
		stop_autocmd = vim.api.nvim_create_autocmd("VimLeavePre", { callback = public.stop })
	end
	if config.general.use_file_write_autocmd then
		project.create_autocmd()
	end
end

function public.stop()
	if not started then
		print("No TTS session to stop")
		return
	end
	listener_server = server.stop_server(listener_server)
	sender_server = server.stop_server(sender_server)
	project.write_config()
	started = false
	print("TTS session stopped")
end

public.create_project = project.create_project

public.scan_project = project.scan_project

function public.push()
	if not started then
		print("No TTS session")
		return
	end
	server.server_send(sender_server, writer.write_save_and_play(not config.general.use_file_write_autocmd))
end

function public.pull()
	if not started then
		print("No TTS session")
		return
	end
	server.server_send(sender_server, writer.write_get_scripts())
end

function public.exec_lua_code(guid, code)
	if not started then
		print("No TTS session")
		return
	end
	server.server_send(sender_server, writer.write_lua_code(guid, code))
end

function public.send_custom_message(msg)
	if not started then
		print("No TTS session")
		return
	end
	server.server_send(sender_server, writer.write_custom_message(msg))
end

return public
