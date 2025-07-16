extends Node
class_name Models

var http_request: HTTPRequest
@onready var parent = get_parent()

signal models_received(models: Array[String])

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)

func get_available_models(url: String = "https://api.openai.com/v1/models"):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
		
	var headers = [
		"Authorization: Bearer " + openai_api_key
	]
	
	var error = http_request.request(url, headers)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		return
	
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		return
	
	var response = json.get_data()
	var model_ids: Array[String] = []
	
	if response.has("data"):
		for model in response["data"]:
			if model.has("id"):
				model_ids.append(model["id"])
	
	parent.emit_signal("models_received", model_ids)
