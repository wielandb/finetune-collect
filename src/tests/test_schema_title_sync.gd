extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var scene = load("res://scenes/schemas/json_schema_container.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0).timeout
	var editor = scene.get_node("MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit")
	var name_edit = scene.get_node("MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit")
	editor.text = '{"title": "My Title"}'
	await create_timer(0).timeout
	assert(name_edit.text == "My Title")
	name_edit.text = "Other"
	await create_timer(0).timeout
	var json := JSON.new()
	var err := json.parse(editor.text)
	assert(err == OK)
	assert(json.data["title"] == "Other")
	print("Schema title synchronized")
	quit(0)
