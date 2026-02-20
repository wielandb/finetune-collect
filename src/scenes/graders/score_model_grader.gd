extends VBoxContainer

var MESSAGE_SCENE = preload("res://scenes/message.tscn")
const DESKTOP_MESSAGE_MARGIN_LEFT = 90
const DESKTOP_MESSAGE_MARGIN_RIGHT = 95
const COMPACT_MESSAGE_MARGIN_LEFT = 12
const COMPACT_MESSAGE_MARGIN_RIGHT = 12
var _compact_layout_enabled = false

func _apply_compact_layout_to_message_container(container: MarginContainer) -> void:
	if _compact_layout_enabled:
		container.add_theme_constant_override("margin_left", COMPACT_MESSAGE_MARGIN_LEFT)
		container.add_theme_constant_override("margin_right", COMPACT_MESSAGE_MARGIN_RIGHT)
	else:
		container.add_theme_constant_override("margin_left", DESKTOP_MESSAGE_MARGIN_LEFT)
		container.add_theme_constant_override("margin_right", DESKTOP_MESSAGE_MARGIN_RIGHT)
	var msg = container.get_node_or_null("Message")
	if msg != null and msg.has_method("set_compact_layout"):
		msg.set_compact_layout(_compact_layout_enabled)

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	$RangeContainer.vertical = enabled
	$SamplingParametersContainer.vertical = enabled
	if $NameContainer.has_method("set_compact_layout"):
		$NameContainer.set_compact_layout(enabled)
	if $ModelContainer.has_method("set_compact_layout"):
		$ModelContainer.set_compact_layout(enabled)
	for child in $MessagesContainer.get_children():
		if child is MarginContainer:
			_apply_compact_layout_to_message_container(child)

func _ready() -> void:
	for child in $MessagesContainer.get_children():
		var msg = child.get_node_or_null("Message")
		if msg:
			msg._on_message_type_item_selected(msg.get_node("MessageSettingsContainer/MessageType").selected)
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func to_var():
	var me = {}
	me["type"] = "score_model"
	me["name"] = $NameContainer.grader_name
	me["model"] = $ModelContainer.model_name
	me["range"] = [float($RangeContainer/RangeFromEdit.text), float($RangeContainer/RangeToEdit.text)]
	me["sampling_params"] = {
		"temperature": float($SamplingParametersContainer/TemperatureEdit.text),
		"top_p": float($SamplingParametersContainer/TopPEdit.text),
		"seed": int($SamplingParametersContainer/SeedEdit.text)
	}
	me["input"] = []
	for child in $MessagesContainer.get_children():
		var msg = child.get_node_or_null("Message")
		if msg:
			me["input"].append(msg.to_grader_var())
	return me

func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$ModelContainer.model_name = grader_data.get("model", "")
	$RangeContainer/RangeFromEdit.text = str(grader_data.get("range", [0,1])[0])
	$RangeContainer/RangeToEdit.text = str(grader_data.get("range", [0,1])[1])
	$SamplingParametersContainer/TemperatureEdit.text = str(grader_data.get("sampling_params", {}).get("temperature", 1))
	$SamplingParametersContainer/TopPEdit.text = str(grader_data.get("sampling_params", {}).get("top_p", 1))
	$SamplingParametersContainer/SeedEdit.text = str(grader_data.get("sampling_params", {}).get("seed", 42))

func is_form_ready() -> bool:
	if $NameContainer.grader_name == "" or $ModelContainer.model_name == "":
		return false
	if $RangeContainer/RangeFromEdit.text == "" or $RangeContainer/RangeToEdit.text == "":
		return false
	if (
		$SamplingParametersContainer/TemperatureEdit.text == "" or
		$SamplingParametersContainer/TopPEdit.text == "" or
		$SamplingParametersContainer/SeedEdit.text == ""
	):
		return false
	for child in $MessagesContainer.get_children():
		var msg = child.get_node_or_null("Message")
		if msg:
			return true
	return false

func _on_add_message_button_pressed() -> void:
	var container = MarginContainer.new()
	container.layout_mode = 2
	var msg = MESSAGE_SCENE.instantiate()
	container.add_child(msg)
	msg._on_message_type_item_selected(msg.get_node("MessageSettingsContainer/MessageType").selected)
	if msg.has_method("set_compact_layout"):
		msg.set_compact_layout(_compact_layout_enabled)
	$MessagesContainer.add_child(container)
	_apply_compact_layout_to_message_container(container)
	$MessagesContainer.move_child($MessagesContainer/AddMessageButton, -1)
	
