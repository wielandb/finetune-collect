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
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")
var _grader: Grader
@onready var _status_label: Label = $GraderSettingsContainer/GraderVerificationStatus
@onready var _spinner: Control = $GraderSettingsContainer/Spinner
@onready var _use_button: CheckBox = $GraderSettingsContainer/UseThisGraderButton

func _ready() -> void:
	$GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.connect("item_selected", _on_grader_type_option_button_item_selected)
	_verify_timer = Timer.new()
	_verify_timer.one_shot = true
	_verify_timer.wait_time = 0.75
	add_child(_verify_timer)
	_verify_timer.connect("timeout", Callable(self, "_on_verify_timeout"))
	if openai:
		_grader = openai.create_grader()
		_grader.validation_completed.connect(Callable(self, "_on_grader_validation_completed"))
	_status_label.text = tr("GRADER_NOT_VERIFIED_YET")
	_spinner.visible = false
	_use_button.disabled = true
	_use_button.connect("toggled", Callable(self, "_on_use_this_grader_button_toggled"))
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

func _exit_tree() -> void:
	if _grader:
		_grader.queue_free()

func verify_grader() -> bool:
	print("Verifying grader!")
	_use_button.disabled = true
	var grader = $ActualGraderContainer/GraderMarginContainer.get_child(0) if $ActualGraderContainer/GraderMarginContainer.get_child_count() > 0 else null
	if grader and grader.has_method("to_var"):
		var data = grader.to_var()
		print(data)
		if _grader:
			_spinner.visible = true
			_status_label.text = tr("GRADER_VERIFYING")
			_grader.validate_grader(data)
		else:
			_status_label.text = tr("GRADER_VERIFICATION_ERROR")
			_spinner.visible = false
			_use_button.button_pressed = false
		return true
	_status_label.text = tr("GRADER_VERIFICATION_ERROR")
	_spinner.visible = false
	_use_button.button_pressed = false
	return false

func _on_grader_validation_completed(response: Dictionary) -> void:
	print(response)
	var error_label := $ErrorMessageLabel
	_spinner.visible = false
	if response.has("error"):
		error_label.text = response.get("error", {}).get("message", "")
		error_label.visible = true
		_status_label.text = tr("GRADER_VERIFICATION_ERROR")
		_use_button.disabled = true
		_use_button.button_pressed = false
	else:
		error_label.text = ""
		error_label.visible = false
		_status_label.text = tr("GRADER_VERIFIED")
		_use_button.disabled = false

func _on_verify_timeout() -> void:
	verify_grader()

func _schedule_verify() -> void:
	_verify_timer.start()

func _on_any_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	_schedule_verify()

func _on_use_this_grader_button_toggled(pressed: bool) -> void:
	if pressed:
		var list_container = get_parent()
		if list_container:
			for child in list_container.get_children():
				if child != self:
					var btn := child.get_node_or_null("GraderSettingsContainer/UseThisGraderButton")
					if btn:
						btn.button_pressed = false

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
