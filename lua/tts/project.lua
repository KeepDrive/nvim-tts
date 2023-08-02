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

local OBJECT_WRITE_SUCCESS = 0
local OBJECT_WRITE_SCRIPT_FAILED = 1
local OBJECT_WRITE_UI_FAILED = 2
local OBJECT_WRITE_SCRIPT_UI_FAILED = 3
function public.write_object(object)
	local write_status = OBJECT_WRITE_SUCCESS
	local object_config = project_config[object.guid]
	if not object_config then
		object_config = {}
		project_config[object.guid] = object_config
	end
	object_config.name = object.name
	if object.script then
		if object_config.script and not file_exists(object_config.script) then
			write_status = write_status + OBJECT_WRITE_SCRIPT_FAILED
		else
			object_config.script = object_config.script or project_path .. "/" .. object.guid .. ".lua"
			script.write_file(object_config.script, object.script, object.name, object.guid, "script")
		end
	end
	if object.ui then
		if object_config.ui and not file_exists(object_config.ui) then
			write_status = write_status + OBJECT_WRITE_UI_FAILED
		else
			object_config.ui = object_config.ui or project_path .. "/" .. object.guid .. ".xml"
			script.write_file(object_config.ui, object.ui, object.name, object.guid, "ui")
		end
	end
	object_config.updated = write_status ~= 0
	return write_status
end

function public.create_autocmd()
	if write_autocmd then
		return
	end
	write_autocmd = vim.api.nvim_create_autocmd("FileWritePost", {
		callback = function(args)
			local path = args.file
			local object = vim.iter(project_config):find(function(object)
				return object.script == path or object.xml == path
			end)
			if object then
				object.updated = true
			end
		end,
	})
end

function public.get_script_states(get_all)
	local script_states = {}
	for guid, object in pairs(project_config) do
		if get_all or object.updated then
			local scriptCode
			if object.script then
				local script_file, err = io.open(object.script)
				assert(script_file, err)
				scriptCode = script_file:read("*a")
				script_file:close()
				assert(scriptCode, "Script read error")
			end
			local ui
			if object.ui then
				local ui_file, err = io.open(object.ui)
				assert(ui_file, err)
				ui = ui_file:read("*a")
				assert(ui, "Script read error")
			end
			local state = { guid = guid, name = object.name }
			if scriptCode then
				state.script = scriptCode
			end
			if ui then
				state.ui = ui
			end
			script_states[#script_states + 1] = state
		end
	end
	return script_states
end

local function isDictEmpty(dict)
	return not next(dict)
end

function public.set_script_states(script_states)
	local searchFileQueue = {}
	for i = 1, #script_states do
		local object = script_states[i]
		local write_status = public.write_object(object)
		if write_status ~= 0 then
			searchFileQueue[object.guid] = { write_status, object }
		end
	end
	if isDictEmpty(searchFileQueue) then
		return
	end
	vim.fs.find(function(name, path)
		local _, _, guid, type = script.process_file(path, false)
		local object = searchFileQueue[guid]
		if object then
			if object[1] == OBJECT_WRITE_SCRIPT_UI_FAILED then
				object_config[guid][type] = path
				object[1] = object[1] - (type == "script" and OBJECT_WRITE_SCRIPT_FAILED or OBJECT_WRITE_UI_FAILED)
			elseif type == "script" and object[1] == OBJECT_WRITE_SCRIPT_FAILED then
				object_config[guid][type] = path
				object[1] = object[1] - OBJECT_WRITE_SCRIPT_FAILED
			elseif type == "ui" and object[1] == OBJECT_WRITE_UI_FAILED then
				object_config[guid][type] = path
				object[1] = object[1] - OBJECT_WRITE_UI_FAILED
			end
			if object[1] == OBJECT_WRITE_SUCCESS then
				public.write_object(object[2])
				table.remove(searchFileQueue, guid)
			end
		end
		return isDictEmpty(searchFileQueue)
	end, { path = project_path })
end

return public
