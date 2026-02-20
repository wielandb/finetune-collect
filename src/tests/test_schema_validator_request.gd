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
	var fine = DummyFineTune.new()
	fine.name = "FineTune"
	get_root().add_child(fine)

	var scene = load("res://scenes/schemas/json_schema_container.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0).timeout

	var editor = scene.get_node("MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit")
	var schema = {
		"type": "object",
		"properties": {"name": {"type": "string"}},
		"required": ["name"],
		"additionalProperties": false
	}
	editor.text = JSON.stringify(schema)
	await scene._on_validate_timeout()
	var err_label = scene.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel")
	var oai_err_label = scene.get_node("MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel")
	_check(err_label.visible == false, "SchemaErrorLabel should stay hidden for valid schema")
	_check(err_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "SchemaErrorLabel should expand horizontally")
	_check(err_label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "SchemaErrorLabel should use arbitrary autowrap")
	_check(oai_err_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "OAISchemaErrorLabel should expand horizontally")
	_check(oai_err_label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "OAISchemaErrorLabel should use arbitrary autowrap")
	print("Schema validator local validation succeeded")
	quit(tests_failed)
