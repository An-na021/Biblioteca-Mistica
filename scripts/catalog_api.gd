extends Node

func fetch_catalog(base_url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 3.0
	add_child(request)
	var error := request.request(base_url.trim_suffix("/") + "/api/catalog")
	if error != OK:
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return {}
	var json := JSON.new()
	if json.parse((response[3] as PackedByteArray).get_string_from_utf8()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
