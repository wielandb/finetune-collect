extends VBoxContainer

var passing_icon = preload("res://icons/check-decagram-custom.png")
var MESSAGE_SCENE = preload("res://scenes/message.tscn")

func _ready() -> void:
	for child in $MessagesContainer.get_children():
		var msg = child.get_node_or_null("Message")
		if msg:
			msg._on_message_type_item_selected(msg.get_node("MessageSettingsContainer/MessageType").selected)

func to_var():
	var me = {}
	me["type"] = "label_model"
	me["name"] = $NameContainer.grader_name
	me["model"] = $ModelContainer.model_name
	me["labels"] = []
	me["passing_labels"] = []
	for labelix in range($LabelsList.item_count):
		me["labels"].append($LabelsList.get_item_text(labelix))
		if $LabelsList.get_item_icon(labelix) != null:
			me["passing_labels"].append($LabelsList.get_item_text(labelix))
	
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$ModelContainer.model_name = grader_data.get("model", "")
	$LabelsList.clear()
	for label in grader_data.get("labels", []):
		if grader_data.get("passing_labels", []).has(label):
			$LabelsList.add_item(label, passing_icon)
		else:
			$LabelsList.add_item(label)
			

func _on_labels_list_item_activated(index: int) -> void:
	if $LabelsList.get_item_icon(index) != null:
		$LabelsList.set_item_icon(index, null)
	else:
		$LabelsList.set_item_icon(index, passing_icon)
	$LabelsList.deselect_all()



func _on_new_label_button_pressed() -> void:
	var text = $NewLabelsContainer/NewLabelLabel2.text
	if text != "":
		$LabelsList.add_item(text)
		$NewLabelsContainer/NewLabelLabel2.text = ""
		$LabelsList.deselect_all()

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

func _on_labels_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		$LabelsList.remove_item(index)
