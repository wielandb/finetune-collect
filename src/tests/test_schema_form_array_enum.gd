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
	controller.set_value_at_path([1], "green", true)
	await process_frame
	var enum_rows = _find_compact_rows(root)
	assert_true(enum_rows.size() == 2, "compact enum rows rendered")
	if enum_rows.size() == 2:
		var first_move_up = enum_rows[0].get_node_or_null("MoveUpButton")
		var first_move_down = enum_rows[0].get_node_or_null("MoveDownButton")
		var first_duplicate = enum_rows[0].get_node_or_null("DuplicateButton")
		var second_move_up = enum_rows[1].get_node_or_null("MoveUpButton")
		var second_move_down = enum_rows[1].get_node_or_null("MoveDownButton")
		var second_delete = enum_rows[1].get_node_or_null("DeleteButton")
		assert_true(first_move_up is Button and first_move_up.disabled, "first compact row move up is disabled")
		assert_true(first_move_down is Button and not first_move_down.disabled, "first compact row move down is enabled")
		assert_true(first_duplicate is Button and not first_duplicate.disabled, "compact duplicate button exists")
		assert_true(second_move_up is Button and not second_move_up.disabled, "second compact row move up is enabled")
		assert_true(second_move_down is Button and second_move_down.disabled, "second compact row move down is disabled")
		assert_true(second_delete is Button and not second_delete.disabled, "second compact row delete button exists")
		if second_move_up is Button:
			second_move_up.emit_signal("pressed")
			await process_frame
			var parsed_after_move = JSON.parse_string(controller.get_value_as_json(false))
			assert_true(parsed_after_move[0] == "green" and parsed_after_move[1] == "red", "compact move up button reorders items")
		enum_rows = _find_compact_rows(root)
		if enum_rows.size() > 0:
			first_duplicate = enum_rows[0].get_node_or_null("DuplicateButton")
			if first_duplicate is Button:
				first_duplicate.emit_signal("pressed")
				await process_frame
				var parsed_after_button_duplicate = JSON.parse_string(controller.get_value_as_json(false))
				assert_true(parsed_after_button_duplicate.size() == 3, "compact duplicate button adds item")
				assert_true(parsed_after_button_duplicate[0] == "green" and parsed_after_button_duplicate[1] == "green" and parsed_after_button_duplicate[2] == "red", "compact duplicate inserts copied item below source")
		enum_rows = _find_compact_rows(root)
		if enum_rows.size() > 2:
			second_delete = enum_rows[1].get_node_or_null("DeleteButton")
			if second_delete is Button:
				second_delete.emit_signal("pressed")
				await process_frame
				var parsed_after_button_delete = JSON.parse_string(controller.get_value_as_json(false))
				assert_true(parsed_after_button_delete.size() == 2, "compact delete button behavior")

	var standard_root = VBoxContainer.new()
	get_root().add_child(standard_root)
	var standard_controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	standard_controller.bind_form_root(standard_root)
	var standard_schema = {
		"type": "array",
		"items": {
			"type": "string"
		}
	}
	standard_controller.load_schema(standard_schema)
	standard_controller.set_value_from_json("[\"eins\",\"zwei\"]")
	await process_frame
	var standard_rows = _find_standard_rows(standard_root)
	assert_true(standard_rows.size() == 2, "standard array rows rendered")
	if standard_rows.size() == 2:
		var standard_first_move_up = standard_rows[0].get_node_or_null("Header/MoveUpButton")
		var standard_second_move_up = standard_rows[1].get_node_or_null("Header/MoveUpButton")
		var standard_second_move_down = standard_rows[1].get_node_or_null("Header/MoveDownButton")
		var standard_first_duplicate = standard_rows[0].get_node_or_null("Header/DuplicateButton")
		assert_true(standard_first_move_up is Button and standard_first_move_up.disabled, "standard first row move up is disabled")
		assert_true(standard_second_move_up is Button and not standard_second_move_up.disabled, "standard second row move up is enabled")
		assert_true(standard_second_move_down is Button and standard_second_move_down.disabled, "standard second row move down is disabled")
		assert_true(standard_first_duplicate is Button and not standard_first_duplicate.disabled, "standard duplicate button exists")
		if standard_second_move_up is Button:
			standard_second_move_up.emit_signal("pressed")
			await process_frame
			var parsed_standard_after_move = JSON.parse_string(standard_controller.get_value_as_json(false))
			assert_true(parsed_standard_after_move[0] == "zwei" and parsed_standard_after_move[1] == "eins", "standard move up button reorders items")
		standard_rows = _find_standard_rows(standard_root)
		if standard_rows.size() > 0:
			standard_first_duplicate = standard_rows[0].get_node_or_null("Header/DuplicateButton")
			if standard_first_duplicate is Button:
				standard_first_duplicate.emit_signal("pressed")
				await process_frame
				var parsed_standard_after_duplicate = JSON.parse_string(standard_controller.get_value_as_json(false))
				assert_true(parsed_standard_after_duplicate.size() == 3, "standard duplicate button adds item")
				assert_true(parsed_standard_after_duplicate[0] == "zwei" and parsed_standard_after_duplicate[1] == "zwei" and parsed_standard_after_duplicate[2] == "eins", "standard duplicate inserts copied item below source")
	root.queue_free()
	standard_root.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

func _find_compact_rows(root: Node) -> Array:
	var rows = []
	for node in root.find_children("*", "HBoxContainer", true, false):
		var selector_holder = node.get_node_or_null("CompactSelectorHolder")
		var delete_button = node.get_node_or_null("DeleteButton")
		if selector_holder is VBoxContainer and delete_button is Button:
			rows.append(node)
	return rows

func _find_standard_rows(root: Node) -> Array:
	var rows = []
	for node in root.find_children("*", "VBoxContainer", true, false):
		var item_label = node.get_node_or_null("Header/ItemLabel")
		var delete_button = node.get_node_or_null("Header/DeleteButton")
		if item_label is Label and delete_button is Button:
			rows.append(node)
	return rows
