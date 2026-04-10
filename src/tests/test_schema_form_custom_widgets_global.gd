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
	var registry = load("res://scenes/schema_runtime/custom/schema_custom_widget_registry.gd").new()
	var scene_paths = registry.get_registered_scene_paths()
	assert_true(scene_paths.has("res://scenes/schema_runtime/custom_widgets/special_code_leaf_widget.tscn"), "global registry discovers productive special widget")

	controller.load_schema({"type": "string"})
	controller.set_value_from_json("\"plain text\"")
	await process_frame
	await process_frame
	var non_match_special_edit = root.find_child("SpecialCodeLineEdit", true, false)
	assert_true(non_match_special_edit == null, "non-matching schema does not render productive custom widget")
	var standard_line_edits = root.find_children("*", "LineEdit", true, false)
	assert_true(standard_line_edits.size() >= 1, "non-matching schema keeps standard renderer")

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
	var preview_label = root.find_child("PreviewLabel", true, false)
	var error_label = root.find_child("ErrorLabel", true, false)
	assert_true(special_edit is LineEdit, "exact match renders productive custom widget")
	assert_true(preview_label is Label, "custom widget preview label exists")
	assert_true(error_label is Label, "custom widget error label exists")
	assert_true(not _contains_label_with_text(root, "special_code *"), "leaf replacement hides standard property controls")
	if special_edit is LineEdit:
		assert_true(special_edit.text == "abc", "custom widget is initialized from controller value")
		special_edit.text = ""
		special_edit.emit_signal("text_changed", special_edit.text)
		var parsed_after_empty = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_empty is Dictionary and parsed_after_empty.get("special_code", "") == "", "custom widget writes empty value into controller")
		assert_true(_errors_contain_message(controller.get_validation_errors(), "special_code darf nicht leer sein"), "custom widget set_error updates validation")
		if preview_label is Label:
			assert_true(preview_label.text == "Vorschau: ", "preview reflects empty value")
		if error_label is Label:
			assert_true(error_label.visible, "error label visible on invalid value")
		special_edit.text = "ok"
		special_edit.emit_signal("text_changed", special_edit.text)
		var parsed_after_ok = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_ok is Dictionary and parsed_after_ok.get("special_code", "") == "ok", "custom widget writes corrected value into controller")
		assert_true(not _errors_contain_message(controller.get_validation_errors(), "special_code darf nicht leer sein"), "custom widget clear_error removes validation message")
		if preview_label is Label:
			assert_true(preview_label.text == "Vorschau: ok", "preview reflects non-empty value")
		if error_label is Label:
			assert_true(not error_label.visible, "error label hidden after correction")

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
