local public = {}

local config = require("tts.config").project

local xml_prefix = "<!"
local header_start = "--[[tts.nvim\n"
local header_name_key = "name="
local header_guid_key = "guid="
local header_type_key = "type="
local header_end = "tts.nvim]]"
local xml_postfix = "-->"
local header_pattern = "<?!?%-%-%[%[tts%.nvim\n.-\ntts%.nvim%]%]%-?%-?>?"

local function take_header_out(code, remove_header)
	local i, j = code:find(header_pattern)
	if not i then
		return code
	end
	local header = code:sub(i, j)
	if not remove_header then
		return code, header
	end
	code = code:sub(1, i - 1) .. code:sub(j + 1)
	return code, header
end

local function get_val(header, key)
	local i, j = header:find(key)
	if not i then
		return
	end
	return header:sub(j + 1, header:find("\n", j + 1) - 1)
end

local function process_header(header)
	return get_val(header, "name="), get_val(header, "guid="), get_val(header, "type=")
end

function public.process_file(path, remove_header_from_code)
	remove_header_from_code = remove_header_from_code == nil or remove_header_from_code
	local file, err = io.open(path)
	assert(not err, err)
	local code = file:read("*a")
	file:close()
	local header
	code, header = take_header_out(code, remove_header_from_code)
	if not header then
		return
	end
	return code, process_header(header)
end

function public.write_file(path, code, name, guid, file_type)
	local header = header_start
	if name then
		header = header .. header_name_key .. name .. "\n"
	end
	if guid then
		header = header .. header_guid_key .. guid .. "\n"
	end
	if file_type then
		header = header .. header_type_key .. file_type .. "\n"
	end
	header = header .. header_end
	if file_type == "ui" then
		header = xml_prefix .. header .. xml_postfix
	end
	if config.header_at_top_of_file then
		code = header .. "\n" .. code
	else
		code = code .. "\n" .. header
	end
	local file, err = io.open(path, "w")
	assert(not err, err)
	assert(file:write(code))
	file:close()
end

return public
