extends SceneTree

class OpenAiStub:
	extends Node

	signal gpt_response_completed(message, response)
	signal models_received(models)

	var last_request = {}

	func get_models() -> void:
		var models: Array[String] = ["gpt-4o-mini"]
		emit_signal("models_received", models)

	func prompt_gpt(messages: Array[Message], model: String, url: String, tools: Array = [], response_format: Dictionary = {}) -> void:
		last_request = {
			"messages": messages,
			"model": model,
			"url": url,
			"tools": tools,
			"response_format": response_format
		}

class FunctionsListStub:
	extends Node

	func functions_list_to_gpt_available_tools_list() -> Array:
		return []

class FineTuneStub:
	extends Node

	var SETTINGS = {
		"apikey": "test-key",
		"useGlobalSystemMessage": true,
		"globalSystemMessage": "Diese globale Systemnachricht darf nicht verwendet werden.",
		"modelChoice": "gpt-4o-mini",
		"useUserNames": false,
		"finetuneType": 0,
		"tokenCounterPath": "",
		"schemaEditorURL": "",
		"schemaValidatorURL": "",
		"imageUploadSetting": 0,
		"imageUploadServerURL": "",
		"imageUploadServerKey": ""
	}
	var SCHEMAS = [
		{
			"name": "OrderSchema",
			"schema": {
				"type": "object",
				"required": ["id"],
				"additionalProperties": false,
				"properties": {
					"id": {"type": "string"},
					"count": {"type": "integer"}
				}
			}
		}
	]

	func is_compact_layout_enabled() -> bool:
		return false

	func exists_function_without_name() -> bool:
		return false

	func exists_function_without_description() -> bool:
		return false

	func exists_parameter_without_name() -> bool:
		return false

	func exists_parameter_without_description() -> bool:
		return false

	func get_available_function_names() -> Array:
		return []

	func get_available_parameter_names_for_function(_fname: String) -> Array:
		return []

	func get_parameter_def(_function_name, _parameter_name) -> Dictionary:
		return {}

	func is_function_parameter_required(_function_name, _parameter_name) -> bool:
		return false

	func is_function_parameter_enum(_function_name, _parameter_name) -> bool:
		return false

	func get_function_parameter_enums(_function_name, _parameter_name) -> Array:
		return []

	func get_function_parameter_type(_function_name, _parameter_name) -> String:
		return "String"

	func save_current_conversation() -> void:
		pass

	func update_available_schemas_in_UI_global() -> void:
		for node in get_tree().get_nodes_in_group("UI_needs_schema_list"):
			if not (node is OptionButton):
				continue
			var selected_text = ""
			if node.selected != -1 and node.selected < node.item_count:
				selected_text = node.get_item_text(node.selected)
			node.clear()
			node.add_item("Only JSON")
			for schema_entry in SCHEMAS:
				var schema_name = str(schema_entry.get("name", "")).strip_edges()
				if schema_name != "":
					node.add_item(schema_name)
			var selected_index = 0
			if selected_text != "":
				for i in range(node.item_count):
					if node.get_item_text(i) == selected_text:
						selected_index = i
						break
			node.select(selected_index)

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _first_message_node(messages_list):
	var container = messages_list.get_node("MessagesListContainer")
	for child in container.get_children():
		if child.is_in_group("message"):
			return child
	return null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fine_tune = FineTuneStub.new()
	fine_tune.name = "FineTune"

	var openai = OpenAiStub.new()
	openai.name = "OpenAi"
	fine_tune.add_child(openai)

	var conversation = Node.new()
	conversation.name = "Conversation"
	var functions = Node.new()
	functions.name = "Functions"
	var functions_list = FunctionsListStub.new()
	functions_list.name = "FunctionsList"
	functions.add_child(functions_list)
	conversation.add_child(functions)
	fine_tune.add_child(conversation)

	get_root().add_child(fine_tune)

	var messages_list = load("res://scenes/messages_list.tscn").instantiate()
	get_root().add_child(messages_list)
	await process_frame
	await process_frame

	var raw_json = "{\"legacy_id\":\"A-42\"}"
	messages_list.add_message({
		"role": "assistant",
		"type": "JSON",
		"jsonSchemaName": "",
		"jsonSchemaValue": raw_json
	})
	await process_frame
	await process_frame

	var message_node = _first_message_node(messages_list)
	_check(message_node != null, "message node should exist")
	if message_node == null:
		quit(1)
		return
	var transform_area = message_node.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaRawEditorRow/SchemaTransformArea")
	var transform_option = message_node.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaRawEditorRow/SchemaTransformArea/SchemaTransformOptionButton")
	var transform_spinner = message_node.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaRawEditorRow/SchemaTransformArea/SchemaTransformSpinner")
	var schema_edit = message_node.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaRawEditorRow/SchemaEdit")
	var schema_tabs = message_node.get_node("SchemaMessageContainer/SchemaEditTabs")
	schema_tabs.current_tab = 1
	_check(transform_area.get_parent() == schema_edit.get_parent(), "transform dropdown area should sit beside raw JSON editor")
	_check(transform_area.size_flags_vertical == Control.SIZE_EXPAND_FILL, "transform dropdown area should fill raw editor row height")
	transform_option.emit_signal("pressed")
	await process_frame
	_check(transform_option.item_count == 1, "transform dropdown should list OpenAI-valid schema")
	if transform_option.item_count > 0:
		_check(transform_option.get_item_text(0).find("OrderSchema") != -1, "transform option should include schema name")
		transform_option.select(0)
		transform_option.emit_signal("item_selected", 0)
	await process_frame
	_check(transform_option.disabled, "transform dropdown should be disabled while schema transform runs")
	_check(transform_spinner.visible, "transform spinner should be visible while schema transform runs")

	var request_messages = openai.last_request.get("messages", [])
	_check(request_messages is Array and request_messages.size() == 2, "schema transform should send system and user messages only")
	if request_messages is Array and request_messages.size() == 2:
		var system_message = request_messages[0].get_as_dict()
		var user_message = request_messages[1].get_as_dict()
		_check(str(system_message.get("role", "")) == "system", "first transform message should be system")
		_check(str(system_message.get("content", "")) == "Überführe die folgenden Daten in das Schema.", "system prompt should match transform prompt")
		_check(str(user_message.get("role", "")) == "user", "second transform message should be user")
		_check(str(user_message.get("content", "")) == raw_json, "user prompt should be raw JSON")
	_check(openai.last_request.get("tools", []).is_empty(), "schema transform should not send tools")
	var response_format = openai.last_request.get("response_format", {})
	_check(response_format is Dictionary and str(response_format.get("type", "")) == "json_schema", "schema transform should use json_schema response_format")

	var before_response = messages_list.to_var()
	_check(before_response.size() == 1, "schema transform should start with one message")
	var invalid_response_message = load("res://addons/openai_api/Scripts/Message.gd").new()
	invalid_response_message.set_role("assistant")
	invalid_response_message.set_content("not json")
	openai.emit_signal("gpt_response_completed", invalid_response_message, {})
	await process_frame
	await process_frame
	_check(not transform_spinner.visible, "transform spinner should hide after invalid schema transform response")
	_check(not transform_option.disabled, "transform dropdown should re-enable after invalid schema transform response")
	var after_invalid_response = messages_list.to_var()
	_check(after_invalid_response.size() == 1, "invalid schema transform response should not add messages")
	if after_invalid_response.size() == 1:
		var unchanged = after_invalid_response[0]
		_check(str(unchanged.get("jsonSchemaName", "")) == "", "invalid schema transform response should not select target schema")
		_check(str(unchanged.get("jsonSchemaValue", "")) == raw_json, "invalid schema transform response should keep raw JSON unchanged")
	_check(schema_tabs.current_tab == 1, "invalid schema transform response should keep raw tab selected")
	if is_instance_valid(invalid_response_message):
		invalid_response_message.free()
	for request_message in request_messages:
		if request_message is Node and is_instance_valid(request_message):
			request_message.free()

	transform_option.emit_signal("pressed")
	await process_frame
	if transform_option.item_count > 0:
		transform_option.select(0)
		transform_option.emit_signal("item_selected", 0)
	await process_frame
	_check(transform_option.disabled, "transform dropdown should be disabled while retry schema transform runs")
	_check(transform_spinner.visible, "transform spinner should be visible while retry schema transform runs")
	request_messages = openai.last_request.get("messages", [])
	var response_message = load("res://addons/openai_api/Scripts/Message.gd").new()
	response_message.set_role("assistant")
	var transformed_json = "{\"id\":\"A-42\",\"count\":7}"
	response_message.set_content(transformed_json)
	openai.emit_signal("gpt_response_completed", response_message, {})
	await process_frame
	await process_frame
	await process_frame

	var after_response = messages_list.to_var()
	_check(after_response.size() == 1, "schema transform should update existing message instead of adding one")
	if after_response.size() == 1:
		var updated = after_response[0]
		_check(str(updated.get("type", "")) == "JSON", "updated message should remain JSON")
		_check(str(updated.get("jsonSchemaName", "")) == "OrderSchema", "updated message should select target schema")
		_check(str(updated.get("jsonSchemaValue", "")) == transformed_json, "updated message should contain transformed JSON")

	var schema_option = message_node.get_node("SchemaMessageContainer/HBoxContainer/OptionButton")
	_check(schema_option.selected >= 0 and schema_option.get_item_text(schema_option.selected) == "OrderSchema", "message UI should select target schema")
	_check(schema_tabs.current_tab == 0, "message UI should switch to form tab")
	_check(not transform_spinner.visible, "transform spinner should hide after successful schema transform response")
	_check(not transform_option.disabled, "transform dropdown should re-enable after successful schema transform response")

	for request_message in request_messages:
		if request_message is Node and is_instance_valid(request_message):
			request_message.free()
	if is_instance_valid(response_message):
		response_message.free()
	openai.last_request = {}
	messages_list.queue_free()
	fine_tune.queue_free()
	await process_frame
	await process_frame

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
