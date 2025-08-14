extends HBoxContainer

@onready var _code_edit: CodeEdit = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
@onready var _name_edit: LineEdit = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
var _updating := false

func _on_delete_schema_button_pressed() -> void:
	queue_free()

func _on_edit_json_schema_code_edit_text_changed() -> void:
	if _updating:
		return
	var data = JSON.parse_string(_code_edit.text)
	if data is Dictionary and data.has("title"):
		_updating = true
		_name_edit.text = str(data["title"])
		_updating = false

func _on_schema_name_line_edit_text_changed(new_text: String) -> void:
	if _updating:
		return
	var data = JSON.parse_string(_code_edit.text)
	if data is Dictionary:
		data["title"] = new_text
		_updating = true
		_code_edit.text = JSON.stringify(data)
		_updating = false
