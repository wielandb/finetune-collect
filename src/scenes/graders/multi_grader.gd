extends VBoxContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")

func _ready() -> void:
	if $MarginContainer.get_child_count() == 0:
		$MarginContainer.add_child(GRADER_SCENE.instantiate())
	if $MarginContainer2.get_child_count() == 0:
		$MarginContainer2.add_child(GRADER_SCENE.instantiate())
