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
	var registry_script = load("res://scenes/schema_runtime/custom/schema_custom_widget_registry.gd")
	var missing_registry = registry_script.new("res://tests/fixtures/custom_widgets_missing")
	assert_true(missing_registry.get_registered_scene_paths().is_empty(), "missing custom widget directory is treated like an empty registry")
	controller.set_custom_widget_registry(missing_registry)
	controller.bind_form_root(root)
	controller.load_schema({"type": "string"})
	controller.set_value_from_json("\"plain text\"")
	await process_frame
	await process_frame
	var missing_registry_special = root.find_child("SpecialCodeLineEdit", true, false)
	assert_true(missing_registry_special == null, "missing custom widget directory keeps standard rendering")

	var test_registry = registry_script.new("res://tests/fixtures/custom_widgets_valid")
	controller.set_custom_widget_registry(test_registry)

	controller.load_schema({"type": "string"})
	controller.set_value_from_json("\"plain text\"")
	await process_frame
	await process_frame
	var special_edit_non_match = root.find_child("SpecialCodeLineEdit", true, false)
	assert_true(special_edit_non_match == null, "non-matching schema does not render custom widget")
	var string_line_edits = root.find_children("*", "LineEdit", true, false)
	assert_true(string_line_edits.size() >= 1, "non-matching schema keeps standard rendering")

	var exact_schema = {
		"type": "object",
		"required": ["special_code"],
		"properties": {
			"special_code": {"type": "string"}
		},
		"additionalProperties": false
	}
	controller.load_schema(exact_schema)
	controller.set_value_from_json("{\"special_code\":\"abc\"}")
	await process_frame
	await process_frame
	var special_edit = root.find_child("SpecialCodeLineEdit", true, false)
	assert_true(special_edit is LineEdit, "exact-matching schema renders custom widget")
	assert_true(not _contains_label_with_text(root, "special_code *"), "leaf replacement hides standard property controls")
	if special_edit is LineEdit:
		assert_true(special_edit.text == "abc", "custom widget is initialized with current value")
		special_edit.text = ""
		special_edit.emit_signal("text_changed", special_edit.text)
		var parsed_after_empty = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_empty is Dictionary and parsed_after_empty.get("special_code", "") == "", "custom widget writes value changes")
		assert_true(_errors_contain_message(controller.get_validation_errors(), "special_code must not be empty"), "custom widget set_error propagates into validation")
		special_edit.text = "ok"
		special_edit.emit_signal("text_changed", special_edit.text)
		var parsed_after_ok = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_ok is Dictionary and parsed_after_ok.get("special_code", "") == "ok", "custom widget writes value after error state")
		assert_true(not _errors_contain_message(controller.get_validation_errors(), "special_code must not be empty"), "custom widget clear_error removes validation entry")

	var conflict_schema = {
		"type": "object",
		"required": ["conflict_key"],
		"properties": {
			"conflict_key": {"type": "string"}
		},
		"additionalProperties": false
	}
	controller.load_schema(conflict_schema)
	controller.set_value_from_json("{\"conflict_key\":\"x\"}")
	await process_frame
	await process_frame
	var conflict_a_label = root.find_child("ConflictAFlagLabel", true, false)
	var conflict_b_label = root.find_child("ConflictBFlagLabel", true, false)
	assert_true(conflict_a_label is Label, "conflict resolution prefers alphabetical scene path")
	assert_true(conflict_b_label == null, "non-winning conflicting widget is not rendered")

	var invalid_registry = registry_script.new("res://tests/fixtures/custom_widgets_invalid")
	var invalid_paths = invalid_registry.get_registered_scene_paths()
	assert_true(invalid_paths.is_empty(), "invalid custom widget scene is skipped during discovery")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

func _contains_label_with_text(root: Node, text: String) -> bool:
	var labels = root.find_children("*", "Label", true, false)
	for label in labels:
		if label is Label and str(label.text) == text:
			return true
	return false

func _errors_contain_message(errors: Array, message: String) -> bool:
	for error_entry in errors:
		if not (error_entry is Dictionary):
			continue
		if str(error_entry.get("message", "")) == message:
			return true
	return false
