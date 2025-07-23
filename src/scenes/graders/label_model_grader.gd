extends VBoxContainer

var passing_icon = preload("res://icons/check-decagram-custom.png")

func to_var():
	var me = {}
	me["type"] = "label_model"
	me["name"] = $NameContainer.grader_name
	me["model"] = $ModelContainer.model_name
	me["labels"] = []
	me["passing_labels"] = []
	for labelix in range($LabelsList.item_count):
		me["labels"].append($LabelsList.get_item_text(labelix))
		if $LabelsList.get_item_icon(labelix) != null:
			me["passing_labels"].append($LabelsList.get_item_text(labelix))
	
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$ModelContainer.model_name = grader_data.get("model", "")
	$LabelsList.clear()
	for label in grader_data.get("labels", []):
		if grader_data.get("passing_labels", []).has(label):
			$LabelsList.add_item(label, passing_icon)
		else:
			$LabelsList.add_item(label)
			

func _on_labels_list_item_activated(index: int) -> void:
	if $LabelsList.get_item_icon(index) != null:
		$LabelsList.set_item_icon(index, null)
	else:
		$LabelsList.set_item_icon(index, passing_icon)
	$LabelsList.deselect_all()
