extends VBoxContainer

func to_var():
	var me = {}
	me["name"] = $NameContainer.grader_name
	me["image_tag"] = "latest"
	me["type"] = "python"
	me["source"] = $MarginContainer/PythonEdit.text
	return me
	
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$MarginContainer/PythonEdit.text = grader_data.get("source", "")
