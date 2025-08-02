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

func to_var():
	var me = {}
	me["type"] = "multi"
	var name_container = get_node_or_null("NameContainer")
	me["name"] = name_container.grader_name if name_container else ""
	me["graders"] = []
	for child in $GradersContainer.get_children():
		if child.name == "AddGraderControls":
			continue
		var container = child.get_child(0)
		var grader = container.get_child(0)
		if grader.has_method("to_var"):
			me["graders"].append(grader.to_var())
	me["calculate_output"] = $ScoreFormulaContainer/ScoreFormulaEdit.text
	return me

func from_var(grader_data):
	var name_container = get_node_or_null("NameContainer")
	if name_container:
		name_container.grader_name = grader_data.get("name", "")
	$ScoreFormulaContainer/ScoreFormulaEdit.text = grader_data.get("calculate_output", "")
	for child in $GradersContainer.get_children():
		if child.name != "AddGraderControls":
			child.queue_free()
	for sub in grader_data.get("graders", []):
		var type = sub.get("type", "")
		var index = -1
		match type:
			"string_check":
				index = 0
			"string_similarity":
				index = 1
			"score_model":
				index = 2
			"label_model":
				index = 3
			"python":
				index = 4
			"multi":
				index = 5
			_:
				index = -1
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
			if inst.has_method("from_var"):
				inst.from_var(sub)

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
