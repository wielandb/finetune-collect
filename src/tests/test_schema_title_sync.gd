extends SceneTree

class DummyFineTune:
	extends Node
	func update_schemas_internal():
		pass

var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		tests_failed += 1
		push_error(message)

func _init():
	call_deferred("_run")

func _run():
	var ft = DummyFineTune.new()
	ft.name = "FineTune"
	get_root().add_child(ft)
	var scene = load("res://scenes/schemas/json_schema_container.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0).timeout
	var editor = scene.get_node("MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit")
	var name_edit = scene.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit")
	editor.text = '{"title": "My Title"}'
	scene._on_validate_timeout()
	_check(name_edit.text == "My Title", "Title should sync from schema to name field")
	name_edit.text = "Other"
	scene._on_schema_name_line_edit_text_changed("Other")
	var json = JSON.new()
	var err = json.parse(editor.text)
	_check(err == OK, "Schema JSON should parse after title edit")
	if err == OK:
		_check(json.data["title"] == "Other", "Title should sync from name field to schema")
	print("Schema title synchronized")
	quit(tests_failed)
