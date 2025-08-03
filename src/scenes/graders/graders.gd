extends ScrollContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")

func _on_add_grader_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$GradersListContainer.add_child(inst)
	$GradersListContainer.move_child($GradersListContainer/AddGraderButton, -1)

func to_var():
	var all = []
	for child in $GradersListContainer.get_children():
		if child.name == "AddGraderButton":
			continue
		if child.has_method("to_var"):
			all.append(child.to_var())
	return all

func from_var(graders_data):
	for child in $GradersListContainer.get_children():
		if child.name != "AddGraderButton":
			child.queue_free()
	if graders_data is Array:
		for g in graders_data:
			var inst = GRADER_SCENE.instantiate()
			$GradersListContainer.add_child(inst)
			$GradersListContainer.move_child($GradersListContainer/AddGraderButton, -1)
			if inst.has_method("from_var"):
				inst.from_var(g)
