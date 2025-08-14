extends HBoxContainer

const SchemaAlignOpenAI := preload("res://scenes/schemas/schema_align_openai.gd")


func _on_delete_schema_button_pressed() -> void:
	queue_free()


func _on_edit_json_schema_code_edit_text_changed() -> void:
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var json := JSON.new()
	var err := json.parse(editor.text)
	if err != OK:
		oai_editor.text = ""
		return
	var sanitized = SchemaAlignOpenAI.sanitize_envelope_or_schema(json.data)
	oai_editor.text = JSON.stringify(sanitized, "\t")
