extends SceneTree

class OpenAiStub:
	extends Node

	signal gpt_response_completed(message, response)
	signal models_received(models)

	func get_models() -> void:
		var models: Array[String] = ["gpt-4o"]
		emit_signal("models_received", models)

	func set_api(_key: String) -> void:
		pass

	func get_api() -> String:
		return ""

class FineTuneStub:
	extends Node

	signal compact_layout_changed(enabled: bool)

	var SETTINGS = {
		"finetuneType": 0,
		"tokenCounterPath": "",
		"useUserNames": false,
		"schemaEditorURL": "",
		"schemaValidatorURL": "",
		"imageUploadSetting": 0,
		"imageUploadServerURL": "",
		"imageUploadServerKey": "",
		"availableModels": ["gpt-4o"]
	}
	var FUNCTIONS = []
	var SCHEMAS = []
	var _compact_layout_enabled = false

	func is_compact_layout_enabled() -> bool:
		return _compact_layout_enabled

	func set_compact_layout_enabled(enabled: bool) -> void:
		_compact_layout_enabled = enabled
		compact_layout_changed.emit(enabled)

	func get_available_function_names() -> Array:
		return []

	func update_available_schemas_in_UI_global() -> void:
		for node in get_tree().get_nodes_in_group("UI_needs_schema_list"):
			if node is OptionButton:
				node.clear()
				node.add_item("Only JSON")
				node.select(0)

	func update_functions_internal() -> void:
		pass

	func update_settings_internal() -> void:
		pass

	func update_graders_internal() -> void:
		pass

	func update_schemas_internal() -> void:
		pass

	func get_parameter_def(_function_name, _parameter_name):
		return {
			"hasLimits": false,
			"minimum": 0,
			"maximum": 0
		}

	func is_function_parameter_required(_function_name, _parameter_name):
		return false

	func is_function_parameter_enum(_function_name, _parameter_name):
		return false

	func get_function_parameter_enums(_function_name, _parameter_name):
		return []

	func get_function_parameter_type(_function_name, _parameter_name):
		return "String"

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
	get_root().add_child(fine_tune)
	await process_frame

	var message = load("res://scenes/message.tscn").instantiate()
	get_root().add_child(message)
	await process_frame
	message.set_compact_layout(true)
	_check(message.vertical, "message root should be vertical in compact layout")
	_check(not message.get_node("MessageSettingsContainer").vertical, "message actions should be horizontal in compact layout")
	_check(message.get_node("TextMessageContainer/TextnachrichtLabel").get_theme_font_size("font_size") == 24, "message title should use compact font size")
	message.set_compact_layout(false)
	_check(not message.vertical, "message root should return to desktop horizontal layout")
	_check(message.get_node("MessageSettingsContainer").vertical, "message actions should return to vertical in desktop layout")
	_check(message.get_node("TextMessageContainer/TextnachrichtLabel").get_theme_font_size("font_size") == 36, "message title should return to desktop font size")

	var conversation_settings = load("res://scenes/conversation_settings.tscn").instantiate()
	get_root().add_child(conversation_settings)
	await process_frame
	conversation_settings.set_compact_layout(true)
	_check(conversation_settings.get_node("VBoxContainer/HBoxContainer").vertical, "global settings row should stack vertically in compact layout")
	_check(conversation_settings.get_node("VBoxContainer/APIKeySettingContainer").vertical, "api key row should stack vertically in compact layout")
	_check(conversation_settings.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "conversation settings should disable horizontal scrolling")

	var schema_container = load("res://scenes/schemas/json_schema_container.tscn").instantiate()
	get_root().add_child(schema_container)
	await process_frame
	schema_container.set_compact_layout(true)
	_check(schema_container.vertical, "json schema container should stack controls over editor in compact layout")
	_check(schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer").vertical, "schema name row should stack in compact layout")
	_check(schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/TitleLabel").get_theme_font_size("font_size") == 18, "schema title should use compact font size")
	schema_container.set_compact_layout(false)
	_check(not schema_container.vertical, "json schema container should return to desktop row layout")
	_check(schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/TitleLabel").get_theme_font_size("font_size") == 20, "schema title should return to desktop font size")

	var graders_list = load("res://scenes/graders/graders_list.tscn").instantiate()
	get_root().add_child(graders_list)
	await process_frame
	graders_list.set_compact_layout(true)
	_check(graders_list.get_node("GradersListContainer/SampleItemsContainer").columns == 1, "graders sample grid should use one column in compact layout")
	graders_list.set_compact_layout(false)
	_check(graders_list.get_node("GradersListContainer/SampleItemsContainer").columns == 2, "graders sample grid should return to two columns in desktop layout")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
