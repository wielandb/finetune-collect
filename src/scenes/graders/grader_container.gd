extends VBoxContainer

@onready var GRADER_SCENES = [
	preload("res://scenes/graders/string_check_grader.tscn"),
	preload("res://scenes/graders/string_similarity_grader.tscn"),
	preload("res://scenes/graders/score_model_grader.tscn"),
	preload("res://scenes/graders/label_model_grader.tscn"),
	preload("res://scenes/graders/python_grader.tscn"),
	preload("res://scenes/graders/multi_grader.tscn")
]

func _ready() -> void:
	$GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.connect("item_selected", _on_grader_type_option_button_item_selected)
	_on_grader_type_option_button_item_selected($GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.selected)

func _on_grader_type_option_button_item_selected(index: int) -> void:
	for child in $ActualGraderContainer/GraderMarginContainer.get_children():
		child.queue_free()
	if index >= 0 and index < GRADER_SCENES.size():
		var inst = GRADER_SCENES[index].instantiate()
		$ActualGraderContainer/GraderMarginContainer.add_child(inst)

func _on_delete_button_pressed() -> void:
	queue_free()

