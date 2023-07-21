local tts = require("tts")
local create_command = vim.api.nvim_create_user_command
create_command("TTSStart", tts.start, {})
create_command("TTSStop", tts.stop, {})
create_command("TTSPush", tts.push, {})
create_command("TTSPull", tts.pull, {})
create_command("TTSCreateProject", tts.create_project, {})
create_command("TTSScan", tts.scan_project, {})
create_command("TTSExec", function(args)
  if #args.args != 2 then
    print("Incorrect argument amount")
    return
  end
	tts.exec_lua_code(unpack(args.args))
end, { nargs = '+' })
