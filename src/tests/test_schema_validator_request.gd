extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var fine := Node.new()
	fine.name = "FineTune"
	fine.SETTINGS = {"schemaValidatorURL": "http://127.0.0.1:8001/"}
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

	var validator = scene.get_node("SchemaValidatorHTTPRequest")
	await validator.request_completed

	var err_label = scene.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel")
	assert(err_label.text != "HTTP error")
	print("Schema validator request succeeded")
	quit(0)

