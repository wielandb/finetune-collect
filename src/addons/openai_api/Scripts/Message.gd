class_name Message extends Node

## The Message class is used to represent a message in the conversation system.
## This class includes properties for the role, content, and tool calls of a message.

## The role of the sender in the conversation (e.g., "user" or "system").
var role: String = "user"

## The content can be either a string or an array of content items
var content = "say 'template text'"

## Tool calls made by the assistant (for function calling)
var tool_calls: Array = []

## The tool_call_id for tool responses
var tool_call_id: String = ""

## Sets the role of the message sender.
func set_role(new_role: String) -> void:
	role = new_role

## Sets the content of the message. Can be either a string or an array of content items.
func set_content(new_content) -> void:
	content = new_content

## Sets a text content
func set_text_content(text: String) -> void:
	content = text

## Adds an image to the content
func add_image_content(image_base64: String) -> void:
	if typeof(content) != TYPE_ARRAY:
		content = []
	content.append({
		"type": "image_url",
		"image_url": {
			"url": "data:image/jpeg;base64," + image_base64
		}
	})

## Adds a text part to the content
func add_text_content(text: String) -> void:
	if typeof(content) != TYPE_ARRAY:
		content = []
	content.append({
		"type": "text",
		"text": text
	})

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

## Creates a tool response message
func create_tool_response(call_id: String, response_content: String) -> void:
	role = "tool"
	tool_call_id = call_id
	content = response_content
