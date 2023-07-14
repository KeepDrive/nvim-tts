return {
	---Server related settings
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
}
