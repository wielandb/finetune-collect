extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var fine := Node.new()
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

	await create_timer(3).timeout
	var err_label = scene.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel")
	assert(err_label.visible == false)
	print("Schema validator local validation succeeded")
	quit(0)
