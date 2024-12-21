extends Node
class_name ChatGpt
var http_request: HTTPRequest
## Automaticly gets the api from the global script `OpenAi`

@onready var parent = get_parent()

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	
##Sends an api request to chat gpt, will return a signal with a `Message` class.
func prompt_gpt(ListOfMessages:Array[Message], model: String = "gpt-4-vision-preview", url:String="https://api.openai.com/v1/chat/completions", tools: Array = []):
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
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing response.")
		return
	
	var response = json.get_data()
	var message = Message.new()
	print(response)
	##TODO: Add error handeling in case of bad response
	var response_message = response["choices"][0]["message"]
	message.set_role(response_message["role"])
	
	if response_message.has("content"):
		message.set_content(response_message["content"])
	if response_message.has("tool_calls"):
		message.set_tool_calls(response_message["tool_calls"])
	if response_message.has("tool_call_id"):
		message.tool_call_id = response_message["tool_call_id"]
		
	parent.emit_signal("gpt_response_completed", message, response)
