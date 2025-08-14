extends ScrollContainer

@onready var SCHEMA_SCENE = preload("res://scenes/schemas/json_schema_container.tscn")

func _on_add_schema_button_pressed() -> void:
	var inst = SCHEMA_SCENE.instantiate()
	$SchemasListVBox.add_child(inst)
	$SchemasListVBox.move_child($SchemasListVBox/AddSchemaButton, -1)

func to_var():
	var all = []
	for child in $SchemasListVBox.get_children():
		if child.name == "AddSchemaButton":
			continue
		if child.has_method("to_var"):
			all.append(child.to_var())
	return all

func from_var(schemas_data):
	for child in $SchemasListVBox.get_children():
		if child.name != "AddSchemaButton":
			child.queue_free()
	if schemas_data is Array:
		for s in schemas_data:
			var inst = SCHEMA_SCENE.instantiate()
			$SchemasListVBox.add_child(inst)
			if inst.has_method("from_var"):
				inst.from_var(s)
	$SchemasListVBox.move_child($SchemasListVBox/AddSchemaButton, -1)
