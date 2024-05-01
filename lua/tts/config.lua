return {
	server = {
		---Backlog value for the tcp servers, 5 by default to be safe
		---Traditionally a value of 128 is used
		---But there shouldn't be that many connections
		---You could probably even get away with using just 1
		tcp_backlog = 5,
		---The ip that the tcp servers will bind to, localhost by default
		---You shouldn't need to change this unless you're rerouting stuff
		ip = "127.0.0.1",
		---The port that the listener will bind to, 39998 by default
		---You shouldn't need to change this unless TTS changes something with its api
		---Or you're rerouting stuff somehow
		listener_port = 39998,
		---The port that the sender will bind to, 39999 by default
		---You shouldn't need to change this unless TTS changes something with its api
		---Or you're rerouting stuff somehow
		sender_port = 39999,
	},
	reader = {
		---TTS custom message handler
		---msg contains the "customMessage" field of the api message
		handle_custom_message = function(msg) end,
	},
	project = {
		---Change this if you want the config to be called something else
		config_filename = ".tts.json",
		---How deep the project should be scanned for lua/xml files
		scan_depth = 5,
		---Change this if you want new pulled files to be called something else
    ---$1 is the name, $2 is the guid, $3 is the format
		object_filename_pattern = "$1-$2.$3",
	},
	general = {
		---Use an autocmd to track file updates so only updated files get sent to TTS
		use_file_write_autocmd = true,
		---Use an autocmd to properly stop the server and write to config before nvim closes
		use_vim_leave_autocmd = true,
	},
}
