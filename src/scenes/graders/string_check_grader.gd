extends VBoxContainer

func to_var():
	var me = {}
	me["type"] = "string_check"
	me["name"] = $NameContainer.grader_name
	me["input"] = $GridContainer/InputEdit.text
	me["reference"] = $GridContainer/ReferenceEdit.text
	me["operation"] = $GridContainer/OperationOptionButton.get_item_text($GridContainer/OperationOptionButton.selected)
	return me
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$GridContainer/InputEdit.text = grader_data.get("input", "")
	$GridContainer/ReferenceEdit.text = grader_data.get("reference")
	$GridContainer/OperationOptionButton.select(0)
	$GridContainer/OperationOptionButton.select($GridContainer/OperationOptionButton.get_item_index(grader_data.get("operation", "eq")))
