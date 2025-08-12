extends HBoxContainer


func _on_delete_schema_button_pressed() -> void:
	queue_free()
