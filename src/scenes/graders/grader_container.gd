extends VBoxContainer

@onready var GRADER_SCENES = [
	preload("res://scenes/graders/string_check_grader.tscn"),
	preload("res://scenes/graders/string_similarity_grader.tscn"),
	preload("res://scenes/graders/score_model_grader.tscn"),
	preload("res://scenes/graders/label_model_grader.tscn"),
	preload("res://scenes/graders/python_grader.tscn"),
	preload("res://scenes/graders/multi_grader.tscn")
]

var _verify_timer: Timer

func _ready() -> void:
	$GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.connect("item_selected", _on_grader_type_option_button_item_selected)
	_verify_timer = Timer.new()
	_verify_timer.one_shot = true
	_verify_timer.wait_time = 2.0
	add_child(_verify_timer)
	_verify_timer.connect("timeout", Callable(self, "_on_verify_timeout"))
	_on_grader_type_option_button_item_selected($GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.selected)

func _on_grader_type_option_button_item_selected(index: int) -> void:
	for child in $ActualGraderContainer/GraderMarginContainer.get_children():
		child.queue_free()
	if index >= 0 and index < GRADER_SCENES.size():
		var inst = GRADER_SCENES[index].instantiate()
		$ActualGraderContainer/GraderMarginContainer.add_child(inst)
		_connect_gui_input_signals(inst)

func _on_delete_button_pressed() -> void:
	queue_free()

func verify_grader() -> bool:
	print("Verifying grader!")
	var grader := $ActualGraderContainer/GraderMarginContainer.get_child_count() > 0 ? $ActualGraderContainer/GraderMarginContainer.get_child(0) : null
	if grader and grader.has_method("to_var"):
		var data := grader.to_var()
		print(data)
	return true

func _on_verify_timeout() -> void:
	verify_grader()

func _schedule_verify() -> void:
	_verify_timer.start()

func _on_any_gui_input(event: InputEvent) -> void:
	_schedule_verify()

func _on_child_entered(child: Node) -> void:
	_connect_gui_input_signals(child)

func _connect_gui_input_signals(node: Node) -> void:
	if node is Control:
		if not node.is_connected("gui_input", Callable(self, "_on_any_gui_input")):
			node.connect("gui_input", Callable(self, "_on_any_gui_input"))
	if not node.is_connected("child_entered_tree", Callable(self, "_on_child_entered")):
		node.connect("child_entered_tree", Callable(self, "_on_child_entered"))
	for child in node.get_children():
		_connect_gui_input_signals(child)
