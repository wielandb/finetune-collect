extends VBoxContainer

var MESSAGE_SCENE = preload("res://scenes/message.tscn")

func _ready() -> void:
	for child in $MessagesContainer.get_children():
		var msg = child.get_node_or_null("Message")
		if msg:
			msg._on_message_type_item_selected(msg.get_node("MessageSettingsContainer/MessageType").selected)

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

func _on_add_message_button_pressed() -> void:
	var container = MarginContainer.new()
	container.layout_mode = 2
	container.add_theme_constant_override("margin_left", 90)
	container.add_theme_constant_override("margin_right", 95)
	var msg = MESSAGE_SCENE.instantiate()
	container.add_child(msg)
	msg._on_message_type_item_selected(msg.get_node("MessageSettingsContainer/MessageType").selected)
	$MessagesContainer.add_child(container)
	$MessagesContainer.move_child($MessagesContainer/AddMessageButton, -1)
	
