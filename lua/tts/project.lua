local fs = vim.fs
local get_workdir = vim.fn.getcwd
local get_homedir = vim.loop.os_homedir
local json = vim.json

local global_config = require("tts.config").project
local local_config = {}

local write_autocmd
local workspace_path

local public = {}

local function join_path(...)
  return table.concat({...}, '/')
end

local function check_file_exists(path, filename)
  return fs.find(filename or path, {upward = true, type = 'file', path = path, stop = path})[1] and true or false
end

local function write_file(path, contents)
	local file, err = io.open(path, "w")
	assert(file, err)
	assert(file:write(contents))
	file:close()
end

local function read_file(path)
	local file, err = io.open(path, "r")
	assert(file, err)
	local contents = file:read("*a")
	file:close()
  return contents
end

local function remove_required_code_block(script)
  return script:gsub(".*%-%-EMULATEDREQUIRESBLOCKEND\n", "")
end

local function get_all_requires(script, requires, order)
  local isHead = requires == nil
  requires = requires or {}
  order = order or {}
  for filename in script:gmatch("require%([\"\'](.-)[\"\']%)") do
    if not requires[filename] then
      local require_contents = read_file(join_path(workspace_path, filename .. ".lua"))
      requires, order = get_all_requires(require_contents, requires, order)
      requires[filename] = require_contents
      order[#order+1] = filename
    end
  end
  if not isHead then
    return requires, order
  end
  local processedRequires = order
  for i = 1, #order do
    processedRequires[i] = ("_modules[\"%s\"]=(function()%s\nend)()"):format(order[i], requires[order[i]])
  end
  return table.concat(processedRequires, '\n')
end

function public.insert_emulated_requires_block(script_contents)
  local requires = get_all_requires(script_contents)
  if requires == "" then
    return script_contents
  end
  return table.concat({"_G._modules = {}\nfunction _G.require(n) return _modules[n] end\n", requires, "\n--EMULATEDREQUIRESBLOCKEND\n", script_contents})
end

local function get_local_config_path()
  return workspace_path and join_path(workspace_path, global_config.config_filename)
end

local function write_local_config(path)
	write_file(path or get_local_config_path(), json.encode(local_config))
end

local function read_local_config(path)
	local_config = json.decode(read_file(path or get_local_config_path()))
end

local function get_from_config(key)
  return local_config[key] or global_config[key]
end

local function fancy_format(str, ...)
  local args = {...}
  local format = str:gsub("%$%d+", "%%s")
  local format_args = {}
  for num in str:gmatch("%$(%d+)") do
    format_args[#format_args+1] = args[tonumber(num)] or ""
  end
  return format:format(unpack(format_args))
end

function public.create_project()
  local cur_workspace_path = get_workdir()
  if check_file_exists(cur_workspace_path, global_config.config_filename) then
    print("A project config already exists in the working directory. Stopping.")
    return
  end
  workspace_path = cur_workspace_path
  for k, v in pairs(global_config) do
    local_config[k] = v
  end
  write_local_config()
  print("Created project config in the working directory.")
end

function public.load_project()
  local config_path = fs.find(global_config.config_filename, {upward = true, type = 'file', stop = get_homedir()})[1]
  if not config_path then
    print("Failed to find project config.")
    return
  end
  workspace_path = fs.dirname(config_path)
  read_local_config(config_path)
end

function public.write_object(object)
  local filename_pattern = get_from_config("object_filename_pattern")
  local json_object, json_path = public.get_object(object.guid, false)
  if not json_path then
    local json_file = fancy_format(filename_pattern, object.name, object.guid, "json")
    json_path = join_path(workspace_path, json_file)
  end
  local json_dir = fs.dirname(json_path)
  if object.script then
    local script_file = json_object and json_object.script
    if not script_file then
      script_file = fancy_format(filename_pattern, object.name, object.guid, "lua")
    end
    local script_path = join_path(json_dir, script_file)
    write_file(script_path, remove_required_code_block(object.script))
    object.script = script_file
  end
  if object.ui then
    local ui_file = json_object and json_object.ui
    if not ui_file then
      ui_file = fancy_format(filename_pattern, object.name, object.guid, "xml")
    end
    local ui_path = join_path(json_dir, ui_file)
    write_file(ui_path, object.ui)
    object.ui = ui_file
  end
  write_file(json_path, json.encode(object))
end

local json_cache = {}
local function build_json_cache()
  local jsons = fs.find(function(name, path)
    return name:find("%.json$") and true or false
  end, {type = 'file', path = workspace_path, limit = math.huge})
  for i = 1, #jsons do
    local json_text = read_file(jsons[i])
    local success, json_table = pcall(json.decode, json_text)
    if success then
      local guid = json_table.guid
      if guid then
        json_cache[guid] = jsons[i]
      end
    end
  end
end

local function read_object_by_path(path, paths_to_contents)
  paths_to_contents = paths_to_contents == nil and true or paths_to_contents
  local object = json.decode(read_file(path))
  local dir = fs.dirname(path)
  if paths_to_contents then
    object.script = object.script and public.insert_emulated_requires_block(read_file(join_path(dir, object.script)))
    object.ui = object.ui and read_file(join_path(dir, object.ui))
  end
  return object
end

function public.get_object(guid, paths_to_contents)
  paths_to_contents = paths_to_contents == nil and true or paths_to_contents
  local json_path = json_cache[guid]
  if json_path and check_file_exists(json_path) then
    local object = read_object_by_path(json_path, paths_to_contents)
    if object.guid == guid then
      return object, json_path
    end
    json_cache[guid] = nil
  end
  build_json_cache()
  json_path = json_cache[guid]
  return json_path and read_object_by_path(json_path, paths_to_contents), json_path
end

local changed_file_cache = {}
function public.add_file_to_push(path)
  changed_file_cache[path] = true
end

function public.create_autocmd()
	if write_autocmd then
		return
	end
  local	callback = function(args)
		public.add_file_to_push(join_path(get_workdir(), args.file))
  end
	write_autocmd = vim.api.nvim_create_autocmd({"FileWritePost", "FileAppendPost", "BufWritePost"}, { callback = callback})
end

function public.get_script_states(get_all)
  build_json_cache()
  local objects = {}
  if get_all then
    for _, path in pairs(json_cache) do
      objects[#objects+1] = read_object_by_path(path)
    end
  else
    for _, path in pairs(json_cache) do
      local object = read_object_by_path(path, false)
      local dir = fs.dirname(path)
      local script_path = object.script and join_path(dir, object.script)
      local ui_path = object.ui and join_path(dir, object.ui)
      if (script_path and changed_file_cache[script_path]) or (ui_path and changed_file_cache[ui_path]) then
        object.script = object.script and public.insert_emulated_requires_block(read_file(script_path))
        object.ui = object.ui and read_file(ui_path)
        objects[#objects+1] = object
      end
    end
  end
  changed_file_cache = {}
  return objects
end

function public.set_script_states(script_states)
  for i = 1, #script_states do
    public.write_object(script_states[i])
  end
end

return public
