extends ScrollContainer

@onready var SCHEMA_SCENE = preload("res://scenes/schemas/json_schema_container.tscn")
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	for child in $SchemasListVBox.get_children():
		if child.name == "AddSchemaButton":
			continue
		if child.has_method("set_compact_layout"):
			child.set_compact_layout(enabled)

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func _on_add_schema_button_pressed() -> void:
	var inst = SCHEMA_SCENE.instantiate()
	$SchemasListVBox.add_child(inst)
	if inst.has_method("set_compact_layout"):
		inst.set_compact_layout(_compact_layout_enabled)
	$SchemasListVBox.move_child($SchemasListVBox/AddSchemaButton, -1)
	get_node("/root/FineTune").update_schemas_internal()

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
			if inst.has_method("set_compact_layout"):
				inst.set_compact_layout(_compact_layout_enabled)
			if inst.has_method("from_var"):
				inst.from_var(s)
	$SchemasListVBox.move_child($SchemasListVBox/AddSchemaButton, -1)
	get_node("/root/FineTune").update_schemas_internal()
