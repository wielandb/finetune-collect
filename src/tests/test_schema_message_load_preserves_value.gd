extends SceneTree

class FineTuneStub:
	extends Node

	var SETTINGS = {
		"finetuneType": 0,
		"tokenCounterPath": "",
		"useUserNames": false,
		"schemaEditorURL": "",
		"schemaValidatorURL": "",
		"imageUploadSetting": 0,
		"imageUploadServerURL": "",
		"imageUploadServerKey": ""
	}
	var SCHEMAS = [
		{
			"name": "VZ-Liste",
			"schema": {
				"type": "object",
				"properties": {
					"signs": {
						"type": "array",
						"items": {"type": "string"}
					}
				},
				"required": ["signs"],
				"additionalProperties": false
			}
		}
	]
	var suppress_updates = false

	func get_available_function_names() -> Array:
		return []

	func update_available_schemas_in_UI_global() -> void:
		for node in get_tree().get_nodes_in_group("UI_needs_schema_list"):
			if node is OptionButton:
				var selected_text = ""
				if node.selected != -1 and node.selected < node.item_count:
					selected_text = node.get_item_text(node.selected)
				node.set_block_signals(true)
				node.clear()
				node.add_item("Only JSON")
				for schema_entry in SCHEMAS:
					node.add_item(str(schema_entry.get("name", "")))
				if selected_text != "":
					for i in range(node.item_count):
						if node.get_item_text(i) == selected_text:
							node.select(i)
							break
				if node.selected == -1:
					node.select(0)
				node.set_block_signals(false)

	func save_current_conversation() -> void:
		pass

	func is_message_update_suppressed() -> bool:
		return suppress_updates

	func is_compact_layout_enabled() -> bool:
		return false

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
	var fine_tune = FineTuneStub.new()
	fine_tune.name = "FineTune"
	get_root().add_child(fine_tune)
	await process_frame

	var host = Control.new()
	get_root().add_child(host)
	var message_scene = load("res://scenes/message.tscn")
	var message = message_scene.instantiate()
	host.add_child(message)
	await process_frame

	var loaded_json_text = "{\n\t\"signs\": [\n\t\t\"101-12 - Viehtrieb - Aufstellung rechts\"\n\t]\n}"
	message.from_var({
		"role": "assistant",
		"type": "JSON",
		"jsonSchemaName": "VZ-Liste",
		"jsonSchemaValue": loaded_json_text
	})

	# Simulate an option-selection event during suppressed conversation load.
	fine_tune.suppress_updates = true
	message._on_schema_option_selected(1)
	fine_tune.suppress_updates = false

	# Wait for async schema form rebuild to finish.
	await process_frame
	await process_frame
	message._rebuild_schema_form_from_selection(false)
	await process_frame
	await process_frame
	await process_frame

	var schema_edit = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaEdit")
	assert_true(schema_edit is CodeEdit, "schema raw editor exists")
	if schema_edit is CodeEdit:
		assert_true(schema_edit.text.strip_edges() != "", "raw editor text stays non-empty after rebuild")
		assert_true(schema_edit.text == loaded_json_text, "loaded json schema value is preserved in raw editor")

	var schema_form_scroll = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll")
	var schema_form_root = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll/SchemaFormRoot")
	assert_true(schema_form_scroll is ScrollContainer, "schema form scroll exists")
	assert_true(schema_form_root is VBoxContainer, "schema form root exists")
	if schema_form_scroll is ScrollContainer and schema_form_root is VBoxContainer:
		var form_height = schema_form_root.get_combined_minimum_size().y
		var scroll_min_height = schema_form_scroll.custom_minimum_size.y
		assert_true(scroll_min_height + 0.5 >= form_height, "form tab min height covers full schema form content")

	var msg = message.to_var()
	assert_true(msg.get("jsonSchemaValue", "") == loaded_json_text, "to_var keeps loaded json schema value")
	assert_true(msg.get("jsonSchemaName", "") == "VZ-Liste", "schema name remains selected")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
