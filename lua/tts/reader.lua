local json = vim.json

local config = require("tts.config").reader
local project = require("tts.project")

local public = {}

local function handle_script_states(script_states)
	for object in script_states do
		project.write_object(object.name, object.guid, object.script, object.ui)
	end
end

local function read_new_script(msg)
	handle_script_states(msg.script_states)
end

local function read_load_game(msg)
	handle_script_states(msg.script_states)
end

local function read_print(msg)
	print(msg.message)
end

local function read_error(msg)
	print(msg.guid .. ";" .. msg.errorMessagePrefix .. msg.error)
end

local function read_custom(msg)
	config.handle_custom_message(msg.customMessage)
end

local function read_return(msg)
	print(tostring(msg.returnValue))
end

local function read_save_game(msg)
	--Empty message?
end

local function read_created_object(msg)
	project.write_object(nil, msg.guid, nil, nil)
end

local readers = {
	[0] = read_new_script,
	[1] = read_load_game,
	[2] = read_print,
	[3] = read_error,
	[4] = read_custom,
	[5] = read_return,
	[6] = read_save_game,
	[7] = read_created_object,
}

function public.read_message(str)
	local msg = json.decode(str)
	readers[msg.messageID](msg)
end

return public
