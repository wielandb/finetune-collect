extends HBoxContainer

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func to_var():
	var me = {}
	me["name"] = $ParameterName.text
	me["isUsed"] = $FunctionUseParameterIsUsedCheckbox.button_pressed
	me["parameterValueText"] = $FunctionUseParameterEdit.text
	me["parameterValueChoice"] = ""
	if $FunctionUseParameterChoice.selected != -1:
		me["parameterValueChoice"] = 	$FunctionUseParameterChoice.get_item_text($FunctionUseParameterChoice.selected)
	return me	

func from_var(me):
	print("Use_Parameter from var:")
	print(me)
	$ParameterName.text = me["name"]
	var my_parameter_name = me["name"]
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	# Falls der Paramter required ist, checkbox auf ja setzen und disablen
	var isUsedFunctionEnum = get_node("/root/FineTune").is_function_parameter_enum(my_function_name, my_parameter_name)
	var usedParameterEnumOptions = get_node("/root/FineTune").get_function_parameter_enums(my_function_name, my_parameter_name)
	$FunctionUseParameterIsUsedCheckbox.button_pressed = me["isUsed"]
	if isUsedFunctionEnum:
		$FunctionUseParameterEdit.visible = false
		$FunctionUseParameterChoice.visible = true
		$FunctionUseParameterChoice.clear()
		for pv in str(usedParameterEnumOptions).split(",", false):
			$FunctionUseParameterChoice.add_item(pv)
	else:
		$FunctionUseParameterEdit.visible = true
		$FunctionUseParameterChoice.visible = false
	$FunctionUseParameterEdit.text = me["parameterValueText"]
	$FunctionUseParameterChoice.select(selectionStringToIndex($FunctionUseParameterChoice, me["parameterValueChoice"]))
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
