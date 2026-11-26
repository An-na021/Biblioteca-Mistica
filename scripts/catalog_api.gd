extends Node

func fetch_catalog(base_url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	# Scene construction can produce a long first-frame delta. Start the deadline
	# after it settles and use monotonic time instead of HTTPRequest's frame timer.
	await get_tree().process_frame
	await get_tree().process_frame
	var response: Array = []
	request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		response.assign([result, code, headers, body])
	)
	var error := request.request(base_url.trim_suffix("/") + "/api/catalog")
	if error != OK:
		request.queue_free()
		return {}
	var deadline := Time.get_ticks_msec() + 3000
	while response.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if response.is_empty():
		request.cancel_request()
		request.queue_free()
		return {}
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return {}
	var json := JSON.new()
	if json.parse((response[3] as PackedByteArray).get_string_from_utf8()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
