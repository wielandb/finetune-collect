extends Node
class_name Grader

signal run_completed(response)
signal validation_completed(response)

var http_request_run: HTTPRequest
var http_request_validate: HTTPRequest

@onready var parent = get_parent()

func _ready():
	http_request_run = HTTPRequest.new()
	add_child(http_request_run)
	http_request_run.request_completed.connect(self._run_request_completed)

	http_request_validate = HTTPRequest.new()
	add_child(http_request_validate)
	http_request_validate.request_completed.connect(self._validate_request_completed)

func run_grader(grader: Dictionary, model_sample: String, item: Dictionary = {}, url: String = "https://api.openai.com/v1/fine_tuning/alpha/graders/run"):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	var body = {
		"grader": grader,
		"model_sample": model_sample
	}
	if !item.is_empty():
		body["item"] = item
	var json = JSON.new()
	var body_json = json.stringify(body)
	var error = http_request_run.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func validate_grader(grader: Dictionary, url: String = "https://api.openai.com/v1/fine_tuning/alpha/graders/validate"):
	var openai_api_key = parent.get_api()
	if !openai_api_key:
		return
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]
	var body = {"grader": grader}
	var json = JSON.new()
	var body_json = json.stringify(body)
	var error = http_request_validate.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _run_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		return
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		return
	var response = json.get_data()
	run_completed.emit(response)
	parent.emit_signal("grader_run_completed", response)

func _validate_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error with the request.")
		return
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		return
	var response = json.get_data()
	validation_completed.emit(response)
	parent.emit_signal("grader_validation_completed", response)
