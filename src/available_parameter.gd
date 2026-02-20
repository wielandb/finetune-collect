extends BoxContainer

func set_compact_layout(enabled: bool) -> void:
	vertical = enabled

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func to_var():
	var me = {}
	me["type"] = $ParameterTypeBox.get_item_text($ParameterTypeBox.selected)
	me["name"] = $ParameterNameEdit.text
	me["description"] = $ParameterDescriptionEdit.text
	me["minimum"] = $ParameterMinimumEdit.value
	me["maximum"] = $ParameterMaximumEdit.value
	me["isEnum"] = $ParameterIsEnumCheckBox.button_pressed
	me["hasLimits"] = $ParameterHasMinMaxCheckbox.button_pressed
	me["enumOptions"] = $ParameterEnumEdit.text # TODO: Maybe split into options already?, if so change from_var too!
	me["isRequired"] = $ParameterIsRequiredCheckBox.button_pressed
	return me	

func from_var(me):
	var myType = me["type"]
	$ParameterTypeBox.select(selectionStringToIndex($ParameterTypeBox, myType))
	# Activate and deactivate things based on if its a String or a number
	## Deactivate all
	$ParameterHasMinMaxCheckbox.visible = false
	$ParameterMinimumLabel.visible = false
	$ParameterMinimumEdit.visible = false
	$ParameterMaximumLabel.visible = false
	$ParameterMaximumEdit.visible = false
	$ParameterIsEnumCheckBox.visible = false
	$ParameterEnumEdit.visible = false
	## Activate based on Type
	if myType == "String":
		$ParameterIsEnumCheckBox.visible = true
		$ParameterEnumEdit.visible = true
	if myType == "Number":
		$ParameterHasMinMaxCheckbox.visible = true
		$ParameterHasMinMaxCheckbox.button_pressed = me["hasLimits"]
		if me["hasLimits"]:
			$ParameterMinimumLabel.visible = true
			$ParameterMinimumEdit.visible = true
			$ParameterMaximumLabel.visible = true
			$ParameterMaximumEdit.visible = true
	$ParameterNameEdit.text = me["name"]
	$ParameterDescriptionEdit.text = me["description"]
	$ParameterHasMinMaxCheckbox.button_pressed = me["hasLimits"]
	$ParameterMinimumEdit.value = me["minimum"]
	$ParameterMaximumEdit.value = me["maximum"]
	$ParameterIsEnumCheckBox.button_pressed = me["isEnum"]
	$ParameterEnumEdit.text = me["enumOptions"]
	$ParameterIsRequiredCheckBox.button_pressed = me["isRequired"]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_functions_global():
	get_node("/root/FineTune").update_functions_internal()

func _on_delete_button_pressed() -> void:
	update_functions_global()
	queue_free()


func _on_parameter_type_box_item_selected(index: int) -> void:
	$ParameterMinimumLabel.visible = false
	$ParameterMinimumEdit.visible = false
	$ParameterMaximumLabel.visible = false
	$ParameterMaximumEdit.visible = false
	$ParameterIsEnumCheckBox.visible = false
	$ParameterEnumEdit.visible = false
	$ParameterHasMinMaxCheckbox.visible = false
	match index:
		0:
			$ParameterIsEnumCheckBox.visible = true
		1:
			if $ParameterHasMinMaxCheckbox.button_pressed:
				$ParameterMinimumLabel.visible = true
				$ParameterMinimumEdit.visible = true
				$ParameterMaximumLabel.visible = true
				$ParameterMaximumEdit.visible = true
			$ParameterHasMinMaxCheckbox.visible = true
	update_functions_global()

func _on_parameter_is_enum_check_box_pressed() -> void:
	update_functions_global()
	if $ParameterIsEnumCheckBox.button_pressed:
		$ParameterEnumEdit.visible = true
	else:
		$ParameterEnumEdit.visible = false


func _on_parameter_has_min_max_checkbox_pressed() -> void:
	update_functions_global()
	$ParameterMinimumLabel.visible = false
	$ParameterMinimumEdit.visible = false
	$ParameterMaximumLabel.visible = false
	$ParameterMaximumEdit.visible = false
	if $ParameterHasMinMaxCheckbox.button_pressed:
		$ParameterMinimumLabel.visible = true
		$ParameterMinimumEdit.visible = true
		$ParameterMaximumLabel.visible = true
		$ParameterMaximumEdit.visible = true
	

# Funktionsrepräsentationne updaten, wenn irgendetwas geändert wird
func _on_parameter_name_edit_text_changed(new_text: String) -> void:
	update_functions_global()


func _on_delete_button_mouse_entered() -> void:
	if $DeleteButton.disabled:
		return
	$DeleteButton.icon = load("res://icons/trashcanOpen_small.png")


func _on_delete_button_mouse_exited() -> void:
	if $DeleteButton.disabled:
		return
	$DeleteButton.icon = load("res://icons/trashcan_small.png")
