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
	var root = Control.new()
	get_root().add_child(root)
	var schema_container_scene = load("res://scenes/schemas/json_schema_container.tscn")
	var schema_container = schema_container_scene.instantiate()
	root.add_child(schema_container)

	var name_edit = schema_container.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit")
	var edit_code = schema_container.get_node("MarginContainer2/SchemasTabContainer/EditSchemaTab/EditJSONSchemaCodeEdit")
	assert_true(name_edit is LineEdit, "name line edit exists")
	assert_true(edit_code is CodeEdit, "schema code edit exists")
	if not (name_edit is LineEdit) or not (edit_code is CodeEdit):
		print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
		quit(tests_failed)
		return

	edit_code.text = "{\"title\":\"Alpha\",\"type\":\"object\"}"
	name_edit.text = "Alpha"
	name_edit.grab_focus()
	await process_frame
	name_edit.caret_column = 2
	await schema_container._on_validate_timeout()
	assert_true(name_edit.text == "Alpha", "focused line edit keeps text when title unchanged")
	assert_true(name_edit.caret_column == 2, "caret position preserved while focused")

	edit_code.text = "{\"title\":\"Beta\",\"type\":\"object\"}"
	await schema_container._on_validate_timeout()
	assert_true(name_edit.text == "Alpha", "focused line edit is not overwritten by schema title sync")

	edit_code.grab_focus()
	await process_frame
	await schema_container._on_validate_timeout()
	assert_true(name_edit.text == "Beta", "line edit syncs from title when not focused")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
