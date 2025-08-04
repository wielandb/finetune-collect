extends HBoxContainer

@export var dataStr: String:
	get:
		return $CopyAbleDataContentLabel.text
	set(value):
		$CopyAbleDataContentLabel.text = str(value)

@export var copyable: bool:
	get:
		return not $CopyButton.disabled
	set(value):
		if value:
			$CopyButton.disabled = false
		else:
			$CopyButton.disabled = true


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set($CopyAbleDataContentLabel.text)
