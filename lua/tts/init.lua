local config = require("tts.config")
local server = require("tts.server")
local project = require("tts.project")
local reader = require("tts.msg_reader")
local writer = require("tts.msg_writer")

local public = {}

local listener
local sender
local started = false

local stop_autocmd

function public.start()
	if started then
		print("TTS session is already started")
		return
	end
	listener = server.start_listener(config.server.ip, config.server.listener_port, reader.read_message)
	sender = server.start_sender(config.server.ip, config.server.sender_port)
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
	listener:close()
	sender:close()
	project.write_config()
	started = false
	print("TTS session stopped")
end

public.create_project = project.create_project

public.scan_project = project.scan_project

function public.add()
	project.add_file_to_push(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
end

function public.push()
	if not started then
		print("No TTS session")
		return
	end
	sender:write(writer.write_save_and_play(not config.general.use_file_write_autocmd))
end

function public.pull()
	if not started then
		print("No TTS session")
		return
	end
	sender:write(writer.write_get_scripts())
end

function public.exec_lua_code(guid, code)
	if not started then
		print("No TTS session")
		return
	end
	sender:write(writer.write_lua_code(guid, code))
end

function public.send_custom_message(msg)
	if not started then
		print("No TTS session")
		return
	end
	sender:write(writer.write_custom_message(msg))
end

return public
