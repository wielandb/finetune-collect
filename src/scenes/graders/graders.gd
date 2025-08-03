extends ScrollContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")

func _on_add_grader_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$GradersListContainer.add_child(inst)
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
	var btn_index = $GradersListContainer.get_children().find($GradersListContainer/AddGraderButton)
	$GradersListContainer.move_child(inst, btn_index)


func to_var():
	var all = []
	for child in $GradersListContainer.get_children():
		if child.name == "AddGraderButton" or child.name == "SampleItemsContainer":
			continue
		if child.has_method("to_var"):
			all.append(child.to_var())
	return all


func from_var(graders_data):
	for child in $GradersListContainer.get_children():
		if child.name != "AddGraderButton" and child.name != "SampleItemsContainer":
			child.queue_free()
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
	if graders_data is Array:
		for g in graders_data:
			var inst = GRADER_SCENE.instantiate()
			$GradersListContainer.add_child(inst)
			$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
			var btn_index = $GradersListContainer.get_children().find($GradersListContainer/AddGraderButton)
			$GradersListContainer.move_child(inst, btn_index)
			if inst.has_method("from_var"):
				inst.from_var(g)
