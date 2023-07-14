local fs = vim.fs
local json = vim.json
local get_homedir = vim.uv.os_homedir

local config = require("tts.config").project

local project_path = nil
local project_config = {}
local project_config_path = nil

local public = {}

local function get_buffer_dir()
	return fs.dirname(vim.api.nvim_buf_get_name(0))
end

local function locate_project()
	local locations =
		fs.find(config.config_filename, { upward = true, type = "file", stop = get_homedir(), path = get_buffer_dir() })
	return locations and locations[1]
end

local function write_file(path, data)
	local file, err = io.open(path, "w")
	assert(file, err)
	assert(file:write(data))
	file:close()
end

local function set_project_path(path)
	path = fs.normalize(path)
	project_path = path
	project_config_path = project_path .. "/" .. config.config_filename
end

function public.write_config()
	write_file(project_config_path, json.encode(project_config))
end

function public.read_config()
	local config_file, err = io.open(project_config_path, "r")
	assert(config_file, err)
	local config_data = config_file:read("*a")
	assert(config_data, "Config read failed")
	config_file:close()
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
	set_project_path(path)
	public.read_config()
end

function public.scan_project()
	local filename_regex = vim.regex("[^\\/]+(?=\\.(lua|xml)$)")
	for name, type in fs.dir(project_path, { depth = config.scan_depth }) do
		if type == "file" then
			local filename = filename_regex:match_str(name)
			local object_config = project_config[filename]
			if object_config then
				if vim.endswith(name, ".lua") then
					object_config.script = name
				elseif vim.endswith(name, ".xml") then
					object_config.ui = name
				end
			end
		end
	end
	public.write_config()
end

function public.write_object(name, guid, script, ui)
	local object_config = project_config[guid]
	if not object_config then
		object_config = {}
		project_config[guid] = object_config
	end
	object_config.name = name
	if script then
		object_config.script = object_config.script or project_path .. "/" .. guid .. ".lua"
		write_file(object_config.script, script)
	end
	if ui then
		object_config.ui = object_config.ui or project_path .. "/" .. guid .. ".xml"
		write_file(object_config.ui, ui)
	end
end

return public
