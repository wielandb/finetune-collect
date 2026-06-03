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
			"name": "OrderSchema",
			"schema": {
				"type": "object",
				"required": ["id", "count"],
				"properties": {
					"id": {"type": "string"},
					"count": {"type": "integer", "default": 1},
					"active": {"type": "boolean", "default": false}
				},
				"additionalProperties": false
			}
		}
	]

	func get_available_function_names() -> Array:
		return []

	func update_available_schemas_in_UI_global() -> void:
		for node in get_tree().get_nodes_in_group("UI_needs_schema_list"):
			if not (node is OptionButton):
				continue
			var selected_text = ""
			if node.selected != -1 and node.selected < node.item_count:
				selected_text = node.get_item_text(node.selected)
			node.set_block_signals(true)
			node.clear()
			node.add_item("Only JSON")
			for schema_entry in SCHEMAS:
				node.add_item(str(schema_entry.get("name", "")))
			var selected_index = 0
			if selected_text != "":
				for i in range(node.item_count):
					if node.get_item_text(i) == selected_text:
						selected_index = i
						break
			node.select(selected_index)
			node.set_block_signals(false)

	func save_current_conversation() -> void:
		pass

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
	var message = load("res://scenes/message.tscn").instantiate()
	host.add_child(message)
	await process_frame
	await process_frame

	message.from_var({
		"role": "assistant",
		"type": "JSON",
		"jsonSchemaName": "",
		"jsonSchemaValue": "{\"id\":\"A-42\",\"extra\":\"remove me\"}"
	})
	await process_frame
	await process_frame

	var schema_option = message.get_node("SchemaMessageContainer/HBoxContainer/OptionButton")
	assert_true(schema_option is OptionButton, "schema option exists")
	if schema_option is OptionButton:
		schema_option.select(1)
		message._on_schema_option_selected(1)
	await process_frame
	await process_frame
	await process_frame

	var schema_edit = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaRawEditorRow/SchemaEdit")
	assert_true(schema_edit is CodeEdit, "schema raw editor exists")
	if schema_edit is CodeEdit:
		var parsed = JSON.parse_string(schema_edit.text)
		assert_true(parsed is Dictionary, "schema raw editor keeps valid JSON")
		if parsed is Dictionary:
			assert_true(parsed.get("id", "") == "A-42", "existing matching field is preserved")
			assert_true(parsed.get("count", 0) == 1, "missing required field is filled from schema default")
			assert_true(not parsed.has("extra"), "additional property is removed when schema disallows it")

	var saved = message.to_var()
	assert_true(str(saved.get("jsonSchemaName", "")) == "OrderSchema", "selected schema is saved")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
