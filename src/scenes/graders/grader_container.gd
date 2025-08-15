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
@onready var _copy_button: Button = $GraderSettingsContainer/CopyGraderToClipboardButton
var _last_grader_data := {}

func _ready() -> void:
	$GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.connect("item_selected", _on_grader_type_option_button_item_selected)
	_verify_timer = Timer.new()
	_verify_timer.one_shot = true
	_verify_timer.wait_time = 2.0
	add_child(_verify_timer)
	_verify_timer.connect("timeout", Callable(self, "_on_verify_timeout"))
	if openai:
		_grader = openai.create_grader()
		_grader.validation_completed.connect(Callable(self, "_on_grader_validation_completed"))
		_grader.run_completed.connect(Callable(self, "_on_grader_run_completed"))
	_status_label.text = tr("GRADER_NOT_VERIFIED_YET")
	_spinner.visible = false
	_set_grader_controls_disabled(true)
	_use_button.connect("toggled", Callable(self, "_on_use_this_grader_button_toggled"))
	_copy_button.connect("pressed", Callable(self, "_on_copy_grader_to_clipboard_button_pressed"))
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

func _on_delete_button_mouse_entered() -> void:
	$GraderSettingsContainer/DeleteGraderButton.icon = load("res://icons/trashcanOpen_small.png")

func _on_delete_button_mouse_exited() -> void:
	$GraderSettingsContainer/DeleteGraderButton.icon = load("res://icons/trashcan_small.png")

func _exit_tree() -> void:
	if _grader:
		_grader.queue_free()

func verify_grader() -> bool:
	print("Verifying grader!")
	var api_key = get_node("/root/FineTune").SETTINGS.get("apikey", "")
	if api_key == "":
		_status_label.text = tr("DISABLED_EXPLANATION_NEEDS_OPENAI_API_KEY")
		_spinner.visible = false
		_use_button.button_pressed = false
		return false
	_set_grader_controls_disabled(true)

	var grader_gui = null
	if $ActualGraderContainer/GraderMarginContainer.get_child_count() > 0:
		grader_gui = $ActualGraderContainer/GraderMarginContainer.get_child(0)

	# Form-Validierung, falls vorhanden
	if grader_gui and grader_gui.has_method("is_form_ready"):
		if not grader_gui.is_form_ready():
			_status_label.text = tr("GRADER_NOT_COMPLETE")
			_spinner.visible = false
			return false

	# Daten-Serialisierung und Request
	if grader_gui and grader_gui.has_method("to_var"):
		var data = grader_gui.to_var()
		_last_grader_data = data
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

	# Standard-Fehlerfall
	_status_label.text = tr("GRADER_VERIFICATION_ERROR")
	_spinner.visible = false
	_use_button.button_pressed = false
	return false

func _parse_json_or_string(text: String):
	var stripped = text.strip_edges()
	if stripped == "":
		return ""
	var json = JSON.new()
	var err = json.parse(stripped)
	if err == OK:
		return json.get_data()
	return stripped

func _on_grader_validation_completed(response: Dictionary) -> void:
	print(response)
	var error_label := $ErrorMessageLabel
	_spinner.visible = false
	if response.has("error"):
		error_label.text = response.get("error", {}).get("message", "")
		error_label.visible = true
		_status_label.text = tr("GRADER_VERIFICATION_ERROR")
		_set_grader_controls_disabled(true)
		_use_button.button_pressed = false
	else:
		error_label.text = ""
		error_label.visible = false
		if _last_grader_data and _grader:
			_spinner.visible = true
			var list_container = get_parent()
			var model_sample = ""
			var item = null
			if list_container:
				var model_node = list_container.get_node_or_null("SampleItemsContainer/SampleModelOutputEdit")
				if model_node:
					var json = JSON.new()
					if json.parse(model_node.text) == OK and json.data is Dictionary:
						model_sample = str(json.data.get("output_text", ""))
					else:
						model_sample = model_node.text
				var item_node = list_container.get_node_or_null("SampleItemsContainer/SampleItemTextEdit")
				if item_node:
					item = _parse_json_or_string(item_node.text)
			_grader.run_grader(_last_grader_data, model_sample, item)
		else:
			_status_label.text = tr("GRADER_VERIFIED")
			_set_grader_controls_disabled(false)

func _on_grader_run_completed(response: Dictionary) -> void:
	print(response)
	var error_label := $ErrorMessageLabel
	_spinner.visible = false
	if response.has("error"):
		error_label.text = response.get("error", {}).get("message", "")
		error_label.visible = true
		_status_label.text = tr("GRADER_VERIFICATION_ERROR")
		_set_grader_controls_disabled(true)
		_use_button.button_pressed = false
		return
	var errors = response.get("metadata", {}).get("errors", {})
	var messages: Array[String] = []
	for key in errors.keys():
		var val = errors[key]
		if typeof(val) == TYPE_BOOL:
			if val:
				messages.append(str(key))
		elif val:
			messages.append(str(val))
	if messages.size() > 0:
		error_label.text = "; ".join(messages)
		error_label.visible = true
		_status_label.text = tr("GRADER_VERIFICATION_ERROR")
		_set_grader_controls_disabled(true)
		_use_button.button_pressed = false
	else:
		error_label.text = ""
		error_label.visible = false
		var reward = response.get("reward", 0)
		_status_label.text = "%s (%.3f)" % [tr("GRADER_VERIFIED"), reward]
		_set_grader_controls_disabled(false)

func _on_verify_timeout() -> void:
	verify_grader()

func _schedule_verify() -> void:
	_verify_timer.start()

func _on_any_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
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

func _set_grader_controls_disabled(disabled: bool) -> void:
	_use_button.disabled = disabled
	_copy_button.disabled = disabled

func _on_copy_grader_to_clipboard_button_pressed() -> void:
	var data = to_var().get("grader", {})
	DisplayServer.clipboard_set(JSON.stringify(data))

func to_var():
	var result = {"use": _use_button.button_pressed, "grader": {}}
	var grader_gui = null
	if $ActualGraderContainer/GraderMarginContainer.get_child_count() > 0:
		grader_gui = $ActualGraderContainer/GraderMarginContainer.get_child(0)
	if grader_gui and grader_gui.has_method("to_var"):
		result["grader"] = grader_gui.to_var()
	return result

func from_var(data):
	_use_button.button_pressed = data.get("use", false)
	var grader_data = data.get("grader", {})
	var type = grader_data.get("type", "")
	var index = 0
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
			index = 0
	$GraderHeaderMarginContainer/LabelAndChoiceBoxContainer/GraderTypeOptionButton.select(index)
	_on_grader_type_option_button_item_selected(index)
	var grader_gui = null
	if $ActualGraderContainer/GraderMarginContainer.get_child_count() > 0:
		grader_gui = $ActualGraderContainer/GraderMarginContainer.get_child(0)
	if grader_gui and grader_gui.has_method("from_var"):
		grader_gui.from_var(grader_data)
