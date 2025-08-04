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
