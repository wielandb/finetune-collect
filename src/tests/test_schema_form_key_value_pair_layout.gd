extends SceneTree

class OpenAiStub:
	extends Node

	signal gpt_response_completed(message, response)
	signal models_received(models)

	func get_models() -> void:
		pass

class FineTuneUIStub:
	extends Node

	var SETTINGS = {
		"finetuneType": 0,
		"tokenCounterPath": "",
		"useUserNames": false
	}

	var SCHEMAS = []

	func get_available_function_names() -> Array:
		return []

	func update_available_schemas_in_UI_global() -> void:
		pass

var tests_run = 0
var tests_failed = 0

func assert_true(condition: bool, name: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error("Assertion failed: " + name)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root = VBoxContainer.new()
	get_root().add_child(root)
	var controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	controller.bind_form_root(root)
	var schema = {
		"type": "array",
		"minItems": 1,
		"items": {
			"type": "object",
			"required": ["key", "value"],
			"additionalProperties": false,
			"properties": {
				"key": {
					"type": "string",
					"enum": ["alpha", "beta"],
					"description": "Zusatzinfo fuer ComboBox"
				},
				"value": {
					"type": "string",
					"description": "Zusatzinfos fuer Text Input feld"
				}
			}
		}
	}
	controller.load_schema(schema)
	controller.set_value_from_json("[]")
	await process_frame

	var item_labels = root.find_children("ItemLabel", "Label", true, false)
	assert_true(item_labels.is_empty(), "no Item label for key/value pair rows")
	var key_value_rows = root.find_children("KeyValueItemRow", "VBoxContainer", true, false)
	assert_true(key_value_rows.size() == 1, "key/value row rendered")
	if key_value_rows.size() > 0:
		var first_row = key_value_rows[0]
		var fields = first_row.find_child("KeyValueFields", true, false)
		assert_true(fields is HBoxContainer, "fields row uses HBox layout")
		var key_cell = first_row.find_child("KeyCell", true, false)
		var value_cell = first_row.find_child("ValueCell", true, false)
		assert_true(key_cell is VBoxContainer, "key cell rendered")
		assert_true(value_cell is VBoxContainer, "value cell rendered")
		if key_cell is VBoxContainer:
			assert_true(key_cell.get_child_count() >= 2, "key cell has input and info")
			var key_input = key_cell.get_child(0)
			assert_true(key_input is OptionButton, "key uses enum dropdown")
			var key_info = key_cell.find_child("KeyInfo", true, false)
			assert_true(key_info is VBoxContainer, "key info container exists")
			if key_info is VBoxContainer:
				assert_true(key_cell.get_children().find(key_info) > 0, "key info is below key input")
				assert_true(_labels_contain_text(key_info, "Zusatzinfo fuer ComboBox"), "key description is rendered")
		if value_cell is VBoxContainer:
			assert_true(value_cell.get_child_count() >= 2, "value cell has input and info")
			var value_input = value_cell.get_child(0)
			assert_true(value_input is LineEdit, "value uses text input")
			var value_info = value_cell.find_child("ValueInfo", true, false)
			assert_true(value_info is VBoxContainer, "value info container exists")
			if value_info is VBoxContainer:
				assert_true(value_cell.get_children().find(value_info) > 0, "value info is below value input")
				assert_true(_labels_contain_text(value_info, "Zusatzinfos fuer Text Input feld"), "value description is rendered")

	var descriptor = controller._descriptor
	controller._on_array_item_add_requested([], descriptor)
	await process_frame
	var parsed_after_add = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed_after_add is Array, "added value remains array")
	assert_true(parsed_after_add.size() == 2, "add item works for key/value rows")
	assert_true(parsed_after_add[1] is Dictionary, "new row is object")
	assert_true(parsed_after_add[1].get("key", "") == "alpha", "new key uses enum default")
	assert_true(parsed_after_add[1].get("value", "") == "", "new value uses string default")
	var delete_buttons = root.find_children("DeleteButton", "Button", true, false)
	var disabled_button_found = false
	var disabled_icon_unchanged = true
	for btn in delete_buttons:
		if btn is Button and btn.disabled:
			disabled_button_found = true
			var icon_before = btn.icon
			btn.emit_signal("mouse_entered")
			var icon_after_enter = btn.icon
			btn.emit_signal("mouse_exited")
			var icon_after_exit = btn.icon
			disabled_icon_unchanged = icon_before == icon_after_enter and icon_before == icon_after_exit
			break
	assert_true(disabled_button_found, "disabled delete button exists for minItems")
	assert_true(disabled_icon_unchanged, "disabled delete button icon does not animate on hover")
	var clicked_delete = false
	for btn in delete_buttons:
		if btn is Button and not btn.disabled:
			btn.emit_signal("pressed")
			clicked_delete = true
			break
	assert_true(clicked_delete, "delete button is clickable")
	await process_frame
	var parsed_after_delete = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed_after_delete is Array, "value remains array after delete")
	assert_true(parsed_after_delete.size() == 1, "delete button removes item")
	var item_labels_after_add = root.find_children("ItemLabel", "Label", true, false)
	assert_true(item_labels_after_add.is_empty(), "no Item label after add")

	var long_root = VBoxContainer.new()
	get_root().add_child(long_root)
	var long_controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	long_controller.bind_form_root(long_root)
	var long_schema = {
		"type": "object",
		"title": "Ein sehr langer Schema Titel der umbrechen muss und keine horizontale Breite erzwingen darf",
		"required": ["extrem_langer_schluesselname_der_geclippt_werden_muss_und_nicht_das_layout_sprengen_darf"],
		"properties": {
			"extrem_langer_schluesselname_der_geclippt_werden_muss_und_nicht_das_layout_sprengen_darf": {
				"type": "string"
			}
		}
	}
	long_controller.load_schema(long_schema)
	await process_frame
	var title_label = _find_label_with_prefix(long_root, "Ein sehr langer Schema Titel")
	assert_true(title_label is Label, "long schema title label rendered")
	if title_label is Label:
		assert_true(title_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "long title label wraps")
	var prop_label = _find_label_with_prefix(long_root, "extrem_langer_schluesselname")
	assert_true(prop_label is Label, "long property label rendered")
	if prop_label is Label:
		assert_true(prop_label.clip_text, "long property label clips text")
		assert_true(prop_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "long property label uses ellipsis")

	var fine_tune_stub = Node.new()
	fine_tune_stub = FineTuneUIStub.new()
	fine_tune_stub.name = "FineTune"
	var openai_stub = OpenAiStub.new()
	openai_stub.name = "OpenAi"
	fine_tune_stub.add_child(openai_stub)
	get_root().add_child(fine_tune_stub)

	var messages_list_scene = load("res://scenes/messages_list.tscn")
	var messages_list = messages_list_scene.instantiate()
	get_root().add_child(messages_list)
	await process_frame
	assert_true(messages_list.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "messages list horizontal scroll is disabled")
	messages_list.queue_free()

	var message_scene = load("res://scenes/message.tscn")
	var message_node = message_scene.instantiate()
	message_node._render_schema_validation_errors("[{\"path\":\"/foo\",\"message\":\"Expected object\"}]")
	var err_container = message_node.get_node("SchemaMessageContainer/SchemaValidationErrorsContainer")
	assert_true(err_container.visible, "schema error container is visible")
	assert_true(err_container.get_child_count() > 0, "schema error rows are created")
	if err_container.get_child_count() > 0:
		var first_row = err_container.get_child(0)
		assert_true(first_row is HBoxContainer, "schema error row uses horizontal layout")
		if first_row is HBoxContainer:
			assert_true(first_row.get_child_count() >= 2, "schema error row has message and path labels")
			if first_row.get_child_count() >= 2:
				var message_label = first_row.get_child(0)
				var path_label = first_row.get_child(1)
				assert_true(message_label is Label, "schema error message label exists")
				assert_true(path_label is Label, "schema error path label exists")
				if message_label is Label:
					assert_true(str(message_label.text).strip_edges() != "", "schema error message text is not empty")
				if path_label is Label:
					assert_true(path_label.clip_text, "schema error path label clips text")
	message_node.free()

	fine_tune_stub.queue_free()
	root.queue_free()
	long_root.queue_free()
	await process_frame

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

func _labels_contain_text(node: Node, text: String) -> bool:
	for child in node.get_children():
		if child is Label and str(child.text).find(text) != -1:
			return true
	return false

func _find_label_with_prefix(node: Node, prefix: String):
	for child in node.get_children():
		if child is Label and str(child.text).begins_with(prefix):
			return child
		var nested = _find_label_with_prefix(child, prefix)
		if nested != null:
			return nested
	return null
