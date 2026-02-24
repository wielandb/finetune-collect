extends Node
class_name ChatGpt
var http_request: HTTPRequest
const Message = preload("res://addons/openai_api/Scripts/Message.gd")
## Automaticly gets the api from the global script `OpenAi`

@onready var parent = get_parent()

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	
##Sends an api request to chat gpt, will return a signal with a `Message` class.
func prompt_gpt(ListOfMessages:Array[Message], model: String = "gpt-4-vision-preview", url:String="https://api.openai.com/v1/chat/completions", tools: Array = [], response_format: Dictionary = {}):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
	##req
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	#Makes it a Array of dics insterad of Array of nodes
	var messages:Array[Dictionary] = []
	for i in ListOfMessages:
		messages.append(i.get_as_dict())
	
	var body = {
	"model": model,
	"messages": messages
	}
	
	if !tools.is_empty():
		body["tools"] = tools
	if response_format.size() > 0:
		body["response_format"] = response_format
		
	var json = JSON.new()
	
	var body_json = json.stringify(body)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _emit_failed_response(response: Dictionary, fallback_message: String = "") -> void:
	var output = response.duplicate(true)
	if fallback_message != "":
		var error_data = output.get("error", {})
		if not (error_data is Dictionary):
			error_data = {}
		if str(error_data.get("message", "")).strip_edges() == "":
			error_data["message"] = fallback_message
		output["error"] = error_data
	if parent != null and parent.has_signal("gpt_response_failed"):
		parent.emit_signal("gpt_response_failed", output)

func _http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		_emit_failed_response({
			"http_result": result,
			"response_code": response_code
		}, "Error with the request.")
		return
	
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		_emit_failed_response({
			"http_result": result,
			"response_code": response_code,
			"raw_body": body.get_string_from_utf8()
		}, "Error parsing response.")
		return
	
	var response = json.get_data()
	if not (response is Dictionary):
		push_error("Unexpected response type.")
		_emit_failed_response({
			"http_result": result,
			"response_code": response_code
		}, "Unexpected response type.")
		return
	var message = Message.new()
	print(response)
	if response_code < 200 or response_code >= 300:
		var error_object = response.get("error", {})
		if not (error_object is Dictionary):
			error_object = {}
		var error_message = str(error_object.get("message", "HTTP error " + str(response_code)))
		push_error(error_message)
		_emit_failed_response(response, error_message)
		return
	if response.has("error"):
		var explicit_error_object = response.get("error", {})
		if not (explicit_error_object is Dictionary):
			explicit_error_object = {}
		var explicit_error_message = str(explicit_error_object.get("message", "OpenAI API request failed"))
		push_error(explicit_error_message)
		_emit_failed_response(response, explicit_error_message)
		return
	var choices = response.get("choices", [])
	if not (choices is Array) or choices.size() == 0:
		push_error("OpenAI response is missing choices.")
		_emit_failed_response(response, "OpenAI response is missing choices.")
		return
	var first_choice = choices[0]
	if not (first_choice is Dictionary) or not first_choice.has("message"):
		push_error("OpenAI response is missing message payload.")
		_emit_failed_response(response, "OpenAI response is missing message payload.")
		return
	var response_message = first_choice["message"]
	if not (response_message is Dictionary):
		push_error("OpenAI response message payload has invalid format.")
		_emit_failed_response(response, "OpenAI response message payload has invalid format.")
		return
	if not response_message.has("role"):
		response_message["role"] = "assistant"
	message.set_role(response_message["role"])
	
	if response_message.has("content"):
		message.set_content(response_message["content"])
	if response_message.has("tool_calls"):
		message.set_tool_calls(response_message["tool_calls"])
	if response_message.has("tool_call_id"):
		message.tool_call_id = response_message["tool_call_id"]
		
	parent.emit_signal("gpt_response_completed", message, response)
