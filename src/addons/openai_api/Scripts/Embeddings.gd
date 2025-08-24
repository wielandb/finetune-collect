extends Node
class_name Embeddings

var http_request: HTTPRequest
@onready var parent = get_parent()

func _ready():
	# Create HTTPRequest node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)

func get_embedding(input_text:String, model:String = "text-embedding-3-small", url:String = "https://api.openai.com/v1/embeddings"):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	var body = {
		"model": model,
		"input": input_text
	}
	var json = JSON.new()
	var body_json = json.stringify(body)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		return
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		push_error("Error parsing response.")
		return
	var response = json.get_data()
	if response.has("data") and response["data"].size() > 0 and response["data"][0].has("embedding"):
		var embedding = response["data"][0]["embedding"]
		parent.emit_signal("embedding_received", embedding, response)
