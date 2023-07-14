local json = vim.json

local project = require("tts.project")

local public = {}

function public.write_get_scripts()
	return json.encode({ messageID = 0 })
end

function public.write_save_and_play(get_all_objects)
	return json.encode({ messageID = 1, scriptStates = project.get_script_states(get_all_objects) })
end

function public.write_custom_message(msg)
	return json.encode({ messageID = 2, customMessage = msg })
end

function public.write_lua_code(guid, code)
	return json.encode({ messageID = 3, guid = guid, script = code })
end

return public
