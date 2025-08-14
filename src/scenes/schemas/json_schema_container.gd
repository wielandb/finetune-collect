extends HBoxContainer

const SchemaAlignOpenAI := preload("res://scenes/schemas/schema_align_openai.gd")

var _updating_from_name := false


func _on_delete_schema_button_pressed() -> void:
	queue_free()


func _on_edit_json_schema_code_edit_text_changed() -> void:
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name_edit := $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
	var json := JSON.new()
	var err := json.parse(editor.text)
	if err != OK:
		oai_editor.text = ""
		return
	var sanitized = SchemaAlignOpenAI.sanitize_envelope_or_schema(json.data)
	oai_editor.text = JSON.stringify(sanitized, "\t")
	if not _updating_from_name and json.data is Dictionary and json.data.has("title"):
		var title = json.data["title"]
		if title is String:
			name_edit.text = title


func _on_schema_name_line_edit_text_changed(new_text: String) -> void:
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var json := JSON.new()
	var err := json.parse(editor.text)
	if err != OK or not (json.data is Dictionary):
		return
	_updating_from_name = true
	json.data["title"] = new_text
	editor.text = JSON.stringify(json.data, "\t")
	_updating_from_name = false
