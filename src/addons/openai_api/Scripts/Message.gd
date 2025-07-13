class_name Message extends Node

## The Message class is used to represent a message in the conversation system.
## This class includes properties for the role, content, and tool calls of a message.

## The role of the sender in the conversation (e.g., "user" or "system").
var role: String = "user"

## The content can be either a string or an array of content items
var content = ""

## Tool calls made by the assistant (for function calling)
var tool_calls: Array = []

## The tool_call_id for tool responses
var tool_call_id: String = ""

## The user name that is potentially there
var user_name = null

## Sets the role of the message sender.
func set_role(new_role: String) -> void:
	role = new_role

func set_user_name(new_name: String) -> void:
	user_name = new_name

## Sets the content of the message. Can be either a string or an array of content items.
func set_content(new_content) -> void:
	content = new_content

## Sets a text content
func set_text_content(text: String) -> void:
	content = text

## Adds an image to the content
func add_image_content(image_base64: String, detail: String) -> void:
	# TODO: Theese variables should be renamed now that image_base64 could be a base64 string or a url
	if typeof(content) != TYPE_ARRAY:
		content = []
	var image_url_data = ""
	if isImageURL(image_base64):
		image_url_data = image_base64
	else:
		# TODO: Check if it is really jpeg or a png
		image_url_data = "data:image/jpeg;base64," + image_base64
	content.append({
		"type": "image_url",
		"image_url": {
			"url": image_url_data,
			"detail": detail
		}
	})
	
func add_audio_content(audio_base64: String, filetype: String) -> void:
	content.append(
		{
			'type': 'input_audio',
			'input_audio': {
				'format': filetype,
				'data': audio_base64
			}
		}
	)

func add_pdf_content(pdf_base64: String, filename: String) -> void:
	content.append(
		{
			'type': 'file',
			'file': {
				'filename': filename,
				'file_data': 'data:application/pdf;base64,' + pdf_base64
			}
		}
	)

## Adds a text part to the content
func add_text_content(text: String) -> void:
	if typeof(content) != TYPE_ARRAY:
		content = []
	var toAddContent = {
		"type": "text",
		"text": text
	}
	content.append(toAddContent)

## Sets tool calls for the message (used by assistant)
func set_tool_calls(calls: Array) -> void:
	tool_calls = calls

## Adds a function call
func add_function_call(id: String, function_name: String, arguments: Dictionary) -> void:
	tool_calls.append({
		"id": id,
		"type": "function",
		"function": {
			"name": function_name,
			"arguments": JSON.stringify(arguments)
		}
	})

## Gets the message as a dictionary for API calls
func get_as_dict() -> Dictionary:
	var dict = {"role": role}
	
	if content:
		dict["content"] = content
		
	if !tool_calls.is_empty():
		dict["tool_calls"] = tool_calls
		
	if role == "tool" && !tool_call_id.is_empty():
		dict["tool_call_id"] = tool_call_id
	
	if user_name:
		dict["name"] = user_name
	return dict

## Sets the message from a dictionary
func set_as_dict(dictionary: Dictionary) -> void:
	if !dictionary.has("role"):
		push_error("Dictionary for \"set_as_dict\" does not contain 'role' key!")
		return
		
	set_role(dictionary["role"])
	
	if dictionary.has("content"):
		set_content(dictionary["content"])
		
	if dictionary.has("tool_calls"):
		set_tool_calls(dictionary["tool_calls"])
		
	if dictionary.has("tool_call_id"):
		tool_call_id = dictionary["tool_call_id"]
	
	if dictionary.has("name"):
		user_name = dictionary["name"]

## Creates a tool response message
func create_tool_response(call_id: String, response_content: String) -> void:
	role = "tool"
	tool_call_id = call_id
	content = [{"type":"text", "text":response_content}]

func isImageURL(url: String) -> bool:
	# Return false if the URL is empty or only whitespace.
	if url.strip_edges() == "":
		return false

	var lower_url = url.to_lower()
	# Any http or https link is treated as an image URL
	return lower_url.begins_with("http://") or lower_url.begins_with("https://")
func getImageType(url: String) -> String:
	# Use our helper function to ensure the URL is valid.
	if not isImageURL(url):
		return ""

	var lower_url = url.to_lower()
	var no_fragment = lower_url.split("#")[0]
	var path_part = no_fragment.split("?")[0]
	if path_part.ends_with(".png"):
		return "png"
	elif path_part.ends_with(".jpg"):
		return "jpg"
	elif path_part.ends_with(".jpeg"):
		return "jpeg"
	var query_index := no_fragment.find("?")
	if query_index != -1:
		var query = no_fragment.substr(query_index + 1)
		var params = query.split("&")
		for param in params:
			var kv = param.split("=")
			if kv.size() == 2:
				var value = kv[1]
				if value.ends_with(".png"):
					return "png"
				elif value.ends_with(".jpg"):
					return "jpg"
				elif value.ends_with(".jpeg"):
					return "jpeg"
	return ""
