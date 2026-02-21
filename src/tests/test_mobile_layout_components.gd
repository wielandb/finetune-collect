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
	var SCHEMAS = [
		{
			"name": "ExtremelyLongSchemaNameThatMustNeverForceTheMessageListToOverflowOnMobileOrDesktop",
			"schema": {
				"type": "object",
				"required": ["publish_date"],
				"properties": {
					"publish_date": {
						"type": "string",
						"format": "date",
						"title": "Publish date"
					},
					"notes": {
						"type": "string"
					}
				}
			}
		}
	]
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
				for schema_entry in SCHEMAS:
					node.add_item(str(schema_entry.get("name", "")))
				node.select(0)

	func update_functions_internal() -> void:
		pass

	func update_settings_internal() -> void:
		pass

	func update_graders_internal() -> void:
		pass

	func update_schemas_internal() -> void:
		pass

	func save_current_conversation() -> void:
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

func _assert_row_children_within_bounds(row, message: String) -> void:
	if not (row is Control):
		_check(false, message + ": row missing")
		return
	for child in row.get_children():
		if child is Control and child.visible:
			var child_right = child.position.x + child.size.x
			_check(child_right <= row.size.x + 1.0, message + ": child '" + child.name + "' should stay within bounds")

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

	var message_host = Control.new()
	message_host.position = Vector2.ZERO
	message_host.size = Vector2(360, 900)
	get_root().add_child(message_host)
	var message = load("res://scenes/message.tscn").instantiate()
	message_host.add_child(message)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	message.set_compact_layout(true)
	await process_frame
	_check(message.vertical, "message root should be vertical in compact layout")
	_check(not message.get_node("MessageSettingsContainer").vertical, "message actions should be horizontal in compact layout")
	_check(message.get_node("TextMessageContainer/TextnachrichtLabel").get_theme_font_size("font_size") == 24, "message title should use compact font size")
	_check(message.get_node("ImageMessageContainer/HBoxContainer").vertical, "image detail row should stack in compact layout")
	_check(not message.get_node("ImageMessageContainer/HBoxContainer/ImageDetailOptionButton").fit_to_longest_item, "image detail selector should not expand to longest item in compact layout")
	_check(message.get_node("ImageMessageContainer/LoadButtonsContainer/LoadImageButton").size_flags_horizontal == Control.SIZE_EXPAND_FILL, "image load button should expand within compact width")
	var settings_container = message.get_node("MessageSettingsContainer")
	var role_button = message.get_node("MessageSettingsContainer/Role")
	var message_type_button = message.get_node("MessageSettingsContainer/MessageType")
	var delete_button = message.get_node("MessageSettingsContainer/DeleteButton")
	_check(absf(message_type_button.size.y - role_button.size.y) <= 0.5, "message type selector should have same compact height as role button")
	_check(absf(message_type_button.size.y - delete_button.size.y) <= 0.5, "message type selector should have same compact height as delete button")
	var delete_button_right = delete_button.position.x + delete_button.size.x
	_check(delete_button_right <= settings_container.size.x + 0.5, "delete button should stay inside compact settings row")
	message_type_button.select(3)
	message._on_message_type_item_selected(3)
	await process_frame
	var schema_option = message.get_node("SchemaMessageContainer/HBoxContainer/OptionButton")
	_check(schema_option.item_count == 2, "schema selector should contain only-json plus configured schema")
	_check(not schema_option.fit_to_longest_item, "schema selector should not expand to longest schema name")
	_check(schema_option.clip_text, "schema selector should clip long schema names")
	schema_option.select(1)
	schema_option.emit_signal("item_selected", 1)
	await process_frame
	await process_frame
	_check(message.size.x <= message_host.size.x + 1.0, "message should stay within mobile host width in schema mode")
	_assert_row_children_within_bounds(message.get_node("SchemaMessageContainer/HBoxContainer"), "schema header row should fit in compact layout")
	var schema_form_scroll = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll")
	_check(schema_form_scroll is ScrollContainer, "schema form should use a scroll container")
	if schema_form_scroll is ScrollContainer:
		_check(schema_form_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "schema form should disable horizontal scrolling")
		_check(schema_form_scroll.size.y > 20.0, "schema form scroll area should have visible height in compact layout")
	var date_input_row = message.find_child("DateInputRow", true, false)
	if date_input_row != null:
		_assert_row_children_within_bounds(date_input_row, "date input row should fit in compact layout")
	message_host.size = Vector2(1200, 900)
	await process_frame
	await process_frame
	message.set_compact_layout(false)
	await process_frame
	_check(not message.vertical, "message root should return to desktop horizontal layout")
	_check(message.get_node("MessageSettingsContainer").vertical, "message actions should return to vertical in desktop layout")
	_check(message.get_node("TextMessageContainer/TextnachrichtLabel").get_theme_font_size("font_size") == 36, "message title should return to desktop font size")
	_check(message.size.x <= message_host.size.x + 1.0, "message should stay within desktop host width in schema mode")
	_assert_row_children_within_bounds(message.get_node("SchemaMessageContainer/HBoxContainer"), "schema header row should fit in desktop layout")
	if schema_form_scroll is ScrollContainer:
		_check(schema_form_scroll.size.y > 100.0, "schema form scroll area should have visible height in desktop layout")
	if date_input_row != null:
		_assert_row_children_within_bounds(date_input_row, "date input row should fit in desktop layout")

	var list_host = Control.new()
	list_host.position = Vector2(0, 920)
	list_host.size = Vector2(900, 700)
	get_root().add_child(list_host)
	var messages_list_container = VBoxContainer.new()
	list_host.add_child(messages_list_container)
	messages_list_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var list_message = load("res://scenes/message.tscn").instantiate()
	messages_list_container.add_child(list_message)
	await process_frame
	var list_message_type = list_message.get_node("MessageSettingsContainer/MessageType")
	list_message_type.select(3)
	list_message._on_message_type_item_selected(3)
	await process_frame
	var list_schema_option = list_message.get_node("SchemaMessageContainer/HBoxContainer/OptionButton")
	list_schema_option.select(1)
	list_schema_option.emit_signal("item_selected", 1)
	await process_frame
	await process_frame
	var list_schema_form_scroll = list_message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll")
	_check(list_schema_form_scroll is ScrollContainer, "list message schema form should use scroll container")
	if list_schema_form_scroll is ScrollContainer:
		_check(list_schema_form_scroll.size.y > 100.0, "list message schema form should stay visible instead of collapsing")

	var conversation_settings = load("res://scenes/conversation_settings.tscn").instantiate()
	var conversation_settings_host = Control.new()
	conversation_settings_host.position = Vector2.ZERO
	conversation_settings_host.size = Vector2(1200, 900)
	get_root().add_child(conversation_settings_host)
	conversation_settings_host.add_child(conversation_settings)
	conversation_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	conversation_settings.set_compact_layout(true)
	_check(conversation_settings.get_node("VBoxContainer/HBoxContainer").vertical, "global settings row should stack vertically in compact layout")
	_check(conversation_settings.get_node("VBoxContainer/APIKeySettingContainer").vertical, "api key row should stack vertically in compact layout")
	_check(conversation_settings.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "conversation settings should disable horizontal scrolling")
	conversation_settings.set_compact_layout(false)
	await process_frame
	await process_frame
	_check(not conversation_settings.get_node("VBoxContainer/APIKeySettingContainer").vertical, "api key row should stay horizontal in wide desktop tabs")
	var model_row = conversation_settings.get_node("VBoxContainer/ModelChoiceContainer")
	conversation_settings.get_node("VBoxContainer/ModelChoiceContainer/ModelChoiceRefreshButton").custom_minimum_size = Vector2(700, 0)
	conversation_settings_host.size = Vector2(620, 900)
	await process_frame
	await process_frame
	_check(model_row.vertical, "model choice row should stack in narrow desktop tabs to avoid overflow")
	for child in model_row.get_children():
		if child is Control and child.visible:
			var child_right = child.position.x + child.size.x
			_check(child_right <= model_row.size.x + 1.0, "model choice row controls should remain inside row bounds")

	var schema_container = load("res://scenes/schemas/json_schema_container.tscn").instantiate()
	get_root().add_child(schema_container)
	await process_frame
	schema_container.set_compact_layout(true)
	_check(schema_container.vertical, "json schema container should stack controls over editor in compact layout")
	_check(schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer").vertical, "schema name row should stack in compact layout")
	_check(schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/TitleLabel").get_theme_font_size("font_size") == 18, "schema title should use compact font size")
	var schema_tabs = schema_container.get_node("MarginContainer2/SchemasTabContainer")
	_check(schema_tabs.get_tab_count() == 2, "schema tabs should expose edit and openai pages")
	schema_tabs.current_tab = 1
	await process_frame
	_check(schema_tabs.current_tab == 1, "schema tabs should switch to openai page")
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
