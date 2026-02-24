extends SceneTree

class OpenAiStub:
	extends Node

	signal gpt_response_completed(message, response)
	signal models_received(models)

	var last_request = {}

	func get_models() -> void:
		emit_signal("models_received", ["gpt-4o-mini"])

	func prompt_gpt(messages, model: String, url: String, tools: Array = [], response_format: Dictionary = {}) -> void:
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
		"useGlobalSystemMessage": false,
		"globalSystemMessage": "",
		"modelChoice": "gpt-4o-mini",
		"useUserNames": false,
		"finetuneType": 0
	}

	var SCHEMAS = [
		{
			"name": "OrderSchema",
			"schema": {
				"type": "object",
				"required": ["id"],
				"additionalProperties": false,
				"properties": {
					"id": {"type": "string"}
				}
			}
		},
		{
			"name": "BrokenSchema",
			"schema": "this-is-not-a-schema-object"
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
			node.clear()
			node.add_item("Only JSON")
			for schema_entry in SCHEMAS:
				var schema_name = str(schema_entry.get("name", "")).strip_edges()
				if schema_name != "":
					node.add_item(schema_name)
			node.select(0)

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

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

	messages_list.add_message({
		"role": "user",
		"type": "Text",
		"textContent": "Bitte antworte als JSON"
	})
	await process_frame
	await process_frame

	messages_list._on_something_happened_to_check_enabled_status()
	var schema_mode_button = messages_list.get_node("MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn")
	_check(schema_mode_button.item_count == 1, "schema dropdown should include only OpenAI-valid schemas")
	if schema_mode_button.item_count > 0:
		var item_text = schema_mode_button.get_item_text(0)
		_check(item_text.find("OrderSchema") != -1, "schema dropdown option should include schema name")

	messages_list._on_add_message_completion_mode_btn_item_selected(0)
	var response_format = openai.last_request.get("response_format", {})
	_check(response_format is Dictionary, "schema completion should send response_format")
	_check(str(response_format.get("type", "")) == "json_schema", "response_format type should be json_schema")
	var json_schema_payload = response_format.get("json_schema", {})
	_check(json_schema_payload is Dictionary, "response_format json_schema payload should exist")
	if json_schema_payload is Dictionary:
		_check(str(json_schema_payload.get("name", "")) == "OrderSchema", "response_format should use selected schema name")
		var schema_dict = json_schema_payload.get("schema", {})
		_check(schema_dict is Dictionary and schema_dict.has("properties"), "response_format schema should contain properties")

	var message = load("res://addons/openai_api/Scripts/Message.gd").new()
	message.set_role("assistant")
	message.set_content("{\"id\":\"A-42\"}")
	openai.emit_signal("gpt_response_completed", message, {})
	await process_frame
	await process_frame

	var messages_data = messages_list.to_var()
	_check(messages_data.size() >= 2, "completion response should add a message")
	if messages_data.size() >= 2:
		var last_message = messages_data[messages_data.size() - 1]
		_check(str(last_message.get("type", "")) == "JSON", "schema completion response should render as JSON message")
		_check(str(last_message.get("jsonSchemaName", "")) == "OrderSchema", "JSON message should keep selected schema")
		_check(str(last_message.get("jsonSchemaValue", "")) == "{\"id\":\"A-42\"}", "JSON message should contain response payload")

		var message_node = messages_list.get_node("MessagesListContainer").get_child(messages_list.get_node("MessagesListContainer").get_child_count() - 2)
		var selected_schema_option = message_node.get_node("SchemaMessageContainer/HBoxContainer/OptionButton")
		_check(selected_schema_option.selected >= 0, "selected schema should be visible in message UI")
		if selected_schema_option.selected >= 0:
			_check(selected_schema_option.get_item_text(selected_schema_option.selected) == "OrderSchema", "UI should select the schema used for completion")

	messages_list.queue_free()
	fine_tune.queue_free()
	await process_frame

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
