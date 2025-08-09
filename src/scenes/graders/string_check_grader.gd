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
	var operation = grader_data.get("operation", "eq")
	for i in range($GridContainer/OperationOptionButton.item_count):
		if $GridContainer/OperationOptionButton.get_item_text(i) == operation:
			$GridContainer/OperationOptionButton.select(i)
			break

func is_form_ready() -> bool:
	return (
		$NameContainer.grader_name != "" and
		$GridContainer/InputEdit.text != "" and
		$GridContainer/ReferenceEdit.text != "" and
		$GridContainer/OperationOptionButton.selected >= 0
	)
