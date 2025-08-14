extends HBoxContainer


func _on_delete_schema_button_pressed() -> void:
	queue_free()


func _on_edit_json_schema_code_edit_text_changed() -> void:
	pass # TODO: Automatically set the OAI JSON Schema Edit text to this text but sanitized
