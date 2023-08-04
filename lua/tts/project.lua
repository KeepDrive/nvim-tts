local fs = vim.fs
local json = vim.json
local get_homedir = vim.loop.os_homedir

local config = require("tts.config").project
local script = require("tts.script")

local project_path = nil
local project_config = {}
local project_config_path = nil

local public = {}

local write_autocmd

local function get_buffer_dir()
	return fs.dirname(vim.api.nvim_buf_get_name(0))
end

local function locate_project()
	local locations =
		fs.find(config.config_filename, { upward = true, type = "file", stop = get_homedir(), path = get_buffer_dir() })
	return locations and locations[1]
end

local function isDictEmpty(dict)
	return not next(dict)
end

local function file_exists(path)
	local file, err = io.open(path)
	if err then
		return false
	end
	file:close()
	return true
end

local function read_file(path)
	local file, err = io.open(path)
	assert(file, err)
	local data = file:read("*a")
	file:close()
	return data
end

local function write_file(path, data)
	local file, err = io.open(path, "w")
	assert(file, err)
	assert(file:write(data))
	file:close()
end

local FIND_SCRIPT = 1
local FIND_UI = 2
local FIND_SCRIPT_UI = 3
local function find_and_process_moved_files(guid_type_table, process_match)
	fs.find(function(name, path)
		local _, _, guid, type = script.process_file(path, false)
		local object_status = guid_type_table[guid]
		if
			not object_status
			or (type == "script" and object_status % 2 ~= 1)
			or (type == "ui" and object_status < 2)
		then
			return false
		end
		object_status = object_status - (type == "script" and FIND_SCRIPT or FIND_UI)
		guid_type_table[guid] = object_status
		process_match(guid, type, path)
		if object_status == 0 then
			table.remove(guid_type_table, guid)
		end
		return isDictEmpty(guid_type_table)
	end, { path = project_path })
end

local function set_project_path(path)
	if path == "." then
		path = vim.loop.cwd()
	end
	path = fs.normalize(path)
	project_path = path
	project_config_path = project_path .. "/" .. config.config_filename
end

function public.write_config()
	write_file(project_config_path, json.encode(project_config))
end

function public.read_config()
	local config_data = read_file(project_config_path)
	assert(config_data, "Config read failed")
	project_config = json.decode(config_data)
end

function public.create_project()
	if locate_project() then
		print("Project config already exists, stopping")
		return
	end
	set_project_path(".")
	public.write_config()
end

function public.load_project()
	local path = locate_project()
	if not path then
		print("TTS project not found")
		return
	end
	set_project_path(fs.dirname(path))
	public.read_config()
end

function public.write_object(object)
	local write_status = 0
	local object_config = project_config[object.guid]
	if not object_config then
		object_config = {}
		project_config[object.guid] = object_config
	end
	object_config.name = object.name
	if object.script then
		if object_config.script and not file_exists(object_config.script) then
			write_status = write_status + FIND_SCRIPT
		else
			object_config.script = object_config.script or project_path .. "/" .. object.guid .. ".lua"
			script.write_file(object_config.script, object.script, object.name, object.guid, "script")
		end
	end
	if object.ui then
		if object_config.ui and not file_exists(object_config.ui) then
			write_status = write_status + FIND_UI
		else
			object_config.ui = object_config.ui or project_path .. "/" .. object.guid .. ".xml"
			script.write_file(object_config.ui, object.ui, object.name, object.guid, "ui")
		end
	end
	object_config.updated = write_status ~= 0
	return write_status
end

function public.get_object(guid)
	local object = project_config[guid]
	local state = { guid = guid, name = object.name }
	local file_status = 0
	local script_path = object.script
	local ui_path = object.ui
	if script_path and not file_exists(script_path) then
		file_status = file_status + FIND_SCRIPT
	end
	if ui_path and not file_exists(ui_path) then
		file_status = file_status + FIND_UI
	end
	if file_status ~= 0 then
		return nil, file_status
	end
	if script_path then
		state.script = script.process_file(script_path)
	end
	if ui_path then
		state.ui = script.process_file(ui_path)
	end
	return state
end

function public.add_file_to_push(path)
	local _, _, guid, type = script.process_file(path, false)
	if not guid then
		return
	end
	local object = project_config[guid]
	if object then
		object.updated = true
		object[type] = path
	end
end

function public.create_autocmd()
	if write_autocmd then
		return
	end
	write_autocmd = vim.api.nvim_create_autocmd("FileWritePost", {
		callback = function(args)
			public.add_file_to_push(args.file)
		end,
	})
end

function public.get_script_states(get_all)
	local script_states = {}
	local files_to_find = {}
	for guid, object in pairs(project_config) do
		if get_all or object.updated then
			local object_state, status = public.get_object(guid)
			if status then
				files_to_find[guid] = status
			else
				script_states[#script_states + 1] = object_state
			end
		end
	end
	if isDictEmpty(files_to_find) then
		return script_states
	end
	find_and_process_moved_files(files_to_find, function(guid, type, path)
		project_config[guid][type] = path
		if files_to_find[guid] == 0 then
			script_states[#script_states + 1] = public.get_object(guid)
		end
	end)
	return script_states
end

function public.set_script_states(script_states)
	local file_status_queue = {}
	local guid_to_object = {}
	for i = 1, #script_states do
		local object = script_states[i]
		local write_status = public.write_object(object)
		if write_status ~= 0 then
			file_status_queue[object.guid] = write_status
			guid_to_object[object.guid] = object
		end
	end
	if isDictEmpty(file_status_queue) then
		return
	end
	find_and_process_moved_files(file_status_queue, function(guid, type, path)
		project_config[guid][type] = path
		if file_status_queue[guid] == 0 then
			public.write_object(guid_to_object[guid])
		end
	end)
end

return public
