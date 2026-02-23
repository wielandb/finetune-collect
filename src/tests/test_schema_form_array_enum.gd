extends SceneTree

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
			"type": "string",
			"enum": ["red", "green", "blue"]
		}
	}
	controller.load_schema(schema)
	controller.set_value_from_json("[]")
	var parsed = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed is Array, "parsed is array")
	assert_true(parsed.size() == 1, "minItems initialized")
	assert_true(parsed[0] == "red", "enum default selected")
	var descriptor = controller._descriptor
	controller._on_array_item_add_requested([], descriptor)
	var parsed_after_add = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed_after_add.size() == 2, "add item button behavior")
	assert_true(parsed_after_add[1] == "red", "added enum uses first value")
	controller._on_array_item_delete_requested(1, [], 1, descriptor)
	var parsed_after_delete = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed_after_delete.size() == 1, "delete item behavior")
	controller._on_array_item_add_requested([], descriptor)
	var enum_rows = root.find_children("CompactStringEnumRow", "", true, false)
	assert_true(enum_rows.size() == 2, "compact enum rows rendered")
	if enum_rows.size() > 1:
		var delete_button = enum_rows[1].get_node_or_null("DeleteButton")
		assert_true(delete_button is Button, "compact row delete button exists")
		if delete_button is Button:
			delete_button.emit_signal("pressed")
			var parsed_after_button_delete = JSON.parse_string(controller.get_value_as_json(false))
			assert_true(parsed_after_button_delete.size() == 1, "compact delete button behavior")
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
