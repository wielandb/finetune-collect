extends VBoxContainer


@onready var GRADER_SCENES: Array[PackedScene] = [
	preload("res://scenes/graders/string_check_grader.tscn"),
	preload("res://scenes/graders/string_similarity_grader.tscn"),
	preload("res://scenes/graders/score_model_grader.tscn"),
	preload("res://scenes/graders/label_model_grader.tscn"),
	preload("res://scenes/graders/python_grader.tscn"),
	preload("res://scenes/graders/multi_grader.tscn")
]

@onready var _grader_type_option_button: OptionButton = $GradersContainer/AddGraderControls/GraderTypeOptionButton

func _ready() -> void:
	pass

func _on_add_grader_button_pressed() -> void:
	var index := _grader_type_option_button.selected
	if index >= 0 and index < GRADER_SCENES.size():
		var margin_wrapper := MarginContainer.new()
		margin_wrapper.layout_mode = 2
		margin_wrapper.size_flags_vertical = 3
		margin_wrapper.add_theme_constant_override("margin_left", 50)
		var container := VBoxContainer.new()
		container.layout_mode = 2
		var inst := GRADER_SCENES[index].instantiate()
		container.add_child(inst)
		var delete_button := Button.new()
		delete_button.text = "Delete Grader"
		delete_button.connect("pressed", Callable(margin_wrapper, "queue_free"))
		container.add_child(delete_button)
		margin_wrapper.add_child(container)
		inst.connect("tree_exited", Callable(margin_wrapper, "queue_free"))
		$GradersContainer.add_child(margin_wrapper)
		$GradersContainer.move_child($GradersContainer/AddGraderControls, -1)
