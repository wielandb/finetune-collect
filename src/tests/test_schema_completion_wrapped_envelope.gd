extends SceneTree

class OpenAiStub:
	extends Node

	signal gpt_response_completed(message, response)
	signal models_received(models: Array[String])

	var last_request = {}

	func get_models() -> void:
		var models: Array[String] = ["gpt-4o-mini"]
		emit_signal("models_received", models)

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

	var CURRENT_EDITED_CONVO_IX = "FtC1"
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
			"name": "HikingSignpostImage",
			"sanitizedSchema": {
				"name": "HikingSignpostImage",
				"strict": true,
				"schema": {
					"type": "object",
					"additionalProperties": false,
					"properties": {
						"goals": {
							"type": "array",
							"items": {"$ref": "#/$defs/goal"}
						}
					},
					"required": ["goals"],
					"$defs": {
						"goal": {
							"type": "object",
							"additionalProperties": false,
							"properties": {
								"name": {"type": "string"}
							},
							"required": ["name"]
						}
					}
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
	_check(schema_mode_button.item_count == 1, "schema dropdown should include wrapped sanitized schema")

	messages_list._on_add_message_completion_mode_btn_item_selected(0)
	var response_format = openai.last_request.get("response_format", {})
	_check(response_format is Dictionary, "schema completion should send response_format")
	var json_schema_payload = response_format.get("json_schema", {})
	_check(json_schema_payload is Dictionary, "response_format json_schema payload should exist")
	if json_schema_payload is Dictionary:
		var schema_dict = json_schema_payload.get("schema", {})
		_check(schema_dict is Dictionary, "response_format schema should be a dictionary")
		if schema_dict is Dictionary:
			_check(schema_dict.has("$defs"), "response_format schema should keep $defs at root")
			var defs = schema_dict.get("$defs", {})
			_check(defs is Dictionary and defs.has("goal"), "response_format schema should contain goal definition")
			var goals_node = schema_dict.get("properties", {}).get("goals", {})
			var goals_items = goals_node.get("items", {})
			_check(str(goals_items.get("$ref", "")) == "#/$defs/goal", "response_format should keep local $ref target")

	messages_list.queue_free()
	fine_tune.queue_free()
	await process_frame

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
