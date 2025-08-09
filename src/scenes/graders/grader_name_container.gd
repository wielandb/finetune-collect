extends HBoxContainer

var grader_name: String:
	get:
		return $NameEdit.text
	set(value):
		$NameEdit.text = value
		
