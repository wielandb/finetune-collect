extends VBoxContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")

func _ready() -> void:
	$MarginContainer/AddGraderAButton.connect("pressed", _on_add_grader_a_button_pressed)
	$MarginContainer2/AddGraderBButton.connect("pressed", _on_add_grader_b_button_pressed)

func _on_add_grader_a_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$MarginContainer.add_child(inst)
	$MarginContainer/AddGraderAButton.queue_free()

func _on_add_grader_b_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$MarginContainer2.add_child(inst)
	$MarginContainer2/AddGraderBButton.queue_free()
