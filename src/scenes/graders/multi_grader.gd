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
@onready var _score_formula_edit: LineEdit = $ScoreFormulaContainer/ScoreFormulaEdit
@onready var _helper_buttons_container: FlowContainer = $ScoreFormulaHelperButtonsContainer
const DESKTOP_SUB_GRADER_MARGIN_LEFT = 50
const COMPACT_SUB_GRADER_MARGIN_LEFT = 12
var _compact_layout_enabled = false

func _apply_compact_layout_to_wrapper(wrapper: MarginContainer) -> void:
	if _compact_layout_enabled:
		wrapper.add_theme_constant_override("margin_left", COMPACT_SUB_GRADER_MARGIN_LEFT)
	else:
		wrapper.add_theme_constant_override("margin_left", DESKTOP_SUB_GRADER_MARGIN_LEFT)
	if wrapper.get_child_count() > 0:
		var container = wrapper.get_child(0)
		if container.get_child_count() > 0:
			var grader = container.get_child(0)
			if grader.has_method("set_compact_layout"):
				grader.set_compact_layout(_compact_layout_enabled)

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	$GradersContainer/AddGraderControls.vertical = enabled
	$ScoreFormulaContainer.vertical = enabled
	for child in $GradersContainer.get_children():
		if child is MarginContainer:
			_apply_compact_layout_to_wrapper(child)

func _create_sub_grader_wrapper(index: int):
	if index < 0 or index >= GRADER_SCENES.size():
		return null
	var margin_wrapper = MarginContainer.new()
	margin_wrapper.layout_mode = 2
	margin_wrapper.size_flags_vertical = 3
	var container = VBoxContainer.new()
	container.layout_mode = 2
	var inst = GRADER_SCENES[index].instantiate()
	container.add_child(inst)
	var delete_button = Button.new()
	delete_button.text = tr("GRADER_DELETE_GRADER")
	delete_button.icon = load("res://icons/trashcan_small.png")
	delete_button.connect("pressed", Callable(margin_wrapper, "queue_free"))
	delete_button.connect("mouse_entered", Callable(self, "_on_delete_button_mouse_entered").bind(delete_button))
	delete_button.connect("mouse_exited", Callable(self, "_on_delete_button_mouse_exited").bind(delete_button))
	container.add_child(delete_button)
	margin_wrapper.add_child(container)
	inst.connect("tree_exited", Callable(margin_wrapper, "queue_free"))
	_connect_grader_signals(inst, margin_wrapper)
	_apply_compact_layout_to_wrapper(margin_wrapper)
	return margin_wrapper

func _ready() -> void:
	for child in _helper_buttons_container.get_children():
		if child is Button:
			child.connect("pressed", Callable(self, "_on_helper_button_pressed").bind(child))
	_update_grader_name_buttons()
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func _on_helper_button_pressed(button: Button) -> void:
	_add_to_score_formula(button.text)

func _add_to_score_formula(text: String) -> void:
	var caret = _score_formula_edit.caret_column
	var txt = _score_formula_edit.text
	_score_formula_edit.text = txt.substr(0, caret) + text + txt.substr(caret)
	_score_formula_edit.caret_column = caret + text.length()
	_score_formula_edit.grab_focus()

func _update_grader_name_buttons() -> void:
	for child in _helper_buttons_container.get_children():
		if child.is_in_group("grader_name_button"):
			child.queue_free()
	for child in $GradersContainer.get_children():
		if child.name == "AddGraderControls":
			continue
		var container = child.get_child(0)
		var grader = container.get_child(0)
		var name_container = grader.get_node_or_null("NameContainer")
		if name_container:
			var name = name_container.grader_name
			if name != "":
				var b = Button.new()
				b.text = name
				b.add_to_group("grader_name_button")
				b.connect("pressed", Callable(self, "_on_helper_button_pressed").bind(b))
				_helper_buttons_container.add_child(b)

func _connect_grader_signals(grader: Node, wrapper: Node) -> void:
	var name_container = grader.get_node_or_null("NameContainer")
	if name_container:
		var name_edit: LineEdit = name_container.get_node_or_null("NameEdit")
		if name_edit and not name_edit.is_connected("text_changed", Callable(self, "_update_grader_name_buttons")):
			name_edit.connect("text_changed", Callable(self, "_update_grader_name_buttons"))
	wrapper.connect("tree_exited", Callable(self, "_update_grader_name_buttons"))

func to_var():
	var me = {}
	me["type"] = "multi"
	var name_container = get_node_or_null("NameContainer")
	me["name"] = name_container.grader_name if name_container else ""
	me["graders"] = {}
	for child in $GradersContainer.get_children():
		if child.name == "AddGraderControls":
			continue
		var container = child.get_child(0)
		var grader = container.get_child(0)
		if grader.has_method("to_var"):
			var gvar = grader.to_var()
			var var_name = gvar.get("name", "")
			if var_name != "":
				me["graders"][var_name] = gvar
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
	for key in grader_data.get("graders", {}).keys():
		var sub = grader_data["graders"][key]
		if not sub.has("name"):
			sub["name"] = key
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
			var margin_wrapper = _create_sub_grader_wrapper(index)
			if margin_wrapper == null:
				continue
			$GradersContainer.add_child(margin_wrapper)
			$GradersContainer.move_child($GradersContainer/AddGraderControls, -1)
			var container = margin_wrapper.get_child(0)
			var inst = container.get_child(0)
			if inst.has_method("from_var"):
				inst.from_var(sub)
	_update_grader_name_buttons()

func is_form_ready() -> bool:
	var name_container = get_node_or_null("NameContainer")
	if name_container and name_container.grader_name == "":
		return false
	if $ScoreFormulaContainer/ScoreFormulaEdit.text == "":
		return false
	var has_sub = false
	for child in $GradersContainer.get_children():
		if child.name == "AddGraderControls":
			continue
		var container = child.get_child(0)
		var grader = container.get_child(0)
		if grader.has_method("is_form_ready") and not grader.is_form_ready():
			return false
		has_sub = true
	return has_sub

func _on_add_grader_button_pressed() -> void:
	var index = _grader_type_option_button.selected
	if index >= 0 and index < GRADER_SCENES.size():
		var margin_wrapper = _create_sub_grader_wrapper(index)
		if margin_wrapper != null:
			$GradersContainer.add_child(margin_wrapper)
			$GradersContainer.move_child($GradersContainer/AddGraderControls, -1)
			_update_grader_name_buttons()

func _on_delete_button_mouse_entered(button: Button) -> void:
	if button.disabled:
		return
	button.icon = load("res://icons/trashcanOpen_small.png")

func _on_delete_button_mouse_exited(button: Button) -> void:
	if button.disabled:
		return
	button.icon = load("res://icons/trashcan_small.png")
