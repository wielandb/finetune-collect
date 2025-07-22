extends ScrollContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")

func _on_add_grader_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$GradersListContainer.add_child(inst)
	$GradersListContainer.move_child($GradersListContainer/AddGraderButton, -1)
