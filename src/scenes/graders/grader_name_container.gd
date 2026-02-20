extends BoxContainer

var grader_name: String:
	get:
		return $NameEdit.text
	set(value):
		$NameEdit.text = value

func set_compact_layout(enabled: bool) -> void:
	vertical = enabled
		
