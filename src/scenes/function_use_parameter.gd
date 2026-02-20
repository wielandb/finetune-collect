extends BoxContainer

var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	vertical = enabled

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func myParentFunction() -> String:
	var functionChooseBox = get_node("../function/FunctionNameChoiceButton")
	return functionChooseBox.get_item_text(functionChooseBox.selected)

func _get_fine_tune_node():
	if not is_inside_tree():
		return null
	var tree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("FineTune")

func to_var():
	var me = {}
	me["name"] = $ParameterName.text
	me["isUsed"] = $FunctionUseParameterIsUsedCheckbox.button_pressed
	me["parameterValueText"] = $FunctionUseParameterEdit.text
	print("Functionuseparameter Text")
	print($FunctionUseParameterEdit.text)
	me["parameterValueChoice"] = ""
	if $FunctionUseParameterChoice.selected != -1:
		me["parameterValueChoice"] = 	$FunctionUseParameterChoice.get_item_text($FunctionUseParameterChoice.selected)
	me["parameterValueNumber"] = $FunctionUseParameterNumberEdit.value
	print("Parameter to var result")
	print(me)
	return me	

func from_var(me):
	print("Use_Parameter from var:")
	print(me)
	$ParameterName.text = str(me.get("name", ""))
	var my_parameter_name = str(me.get("name", ""))
	$FunctionUseParameterNumberEdit.value = float(me.get("parameterValueNumber", 0))
	var my_function_name = myParentFunction()
	$FunctionUseParameterIsUsedCheckbox.button_pressed = bool(me.get("isUsed", false))
	$FunctionUseParameterEdit.text = str(me.get("parameterValueText", ""))
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		$FunctionUseParameterEdit.visible = true
		$FunctionUseParameterChoice.visible = false
		$FunctionUseParameterNumberEdit.visible = false
		return
	var my_parameter_def = ft_node.get_parameter_def(my_function_name, my_parameter_name)	
	# Falls der Paramter required ist, checkbox auf ja setzen und disablen
	var isUsedFunctionEnum = ft_node.is_function_parameter_enum(my_function_name, my_parameter_name)
	var usedParameterEnumOptions = ft_node.get_function_parameter_enums(my_function_name, my_parameter_name)
	var isUsedParameterRequired = ft_node.is_function_parameter_required(my_function_name, my_parameter_name)
	var usedParameterType = ft_node.get_function_parameter_type(my_function_name, my_parameter_name)
	print("Is used parameter required?")
	print(isUsedParameterRequired)
	print("Is function parameter enum?")
	print(isUsedFunctionEnum)
	# Activate/deactivate based on Type
	if isUsedParameterRequired:
		$FunctionUseParameterIsUsedCheckbox.button_pressed = true
		$FunctionUseParameterIsUsedCheckbox.disabled = true
	if isUsedFunctionEnum:
		$FunctionUseParameterEdit.visible = false
		$FunctionUseParameterChoice.visible = true
		$FunctionUseParameterChoice.clear()
		for pv in usedParameterEnumOptions:
			$FunctionUseParameterChoice.add_item(pv)
		$FunctionUseParameterChoice.select(selectionStringToIndex($FunctionUseParameterChoice, me["parameterValueChoice"]))
	else:
		$FunctionUseParameterEdit.visible = true
		$FunctionUseParameterChoice.visible = false
		$FunctionUseParameterEdit.text = me["parameterValueText"]
	if usedParameterType == "Number":
		$FunctionUseParameterEdit.visible = false
		$FunctionUseParameterChoice.visible = false
		$FunctionUseParameterNumberEdit.visible = true
		if my_parameter_def["hasLimits"]:
			$FunctionUseParameterNumberEdit.min_value = my_parameter_def["minimum"]
			$FunctionUseParameterNumberEdit.max_value = my_parameter_def["maximum"]
		else:
			$FunctionUseParameterNumberEdit.min_value = -99999
			$FunctionUseParameterNumberEdit.max_value = 99999
	if usedParameterType == "String":
		$FunctionUseParameterEdit.visible = true
		$FunctionUseParameterChoice.visible = true
		$FunctionUseParameterNumberEdit.visible = false
		# This is terrible. We need to check twice, das kann doch nicht sein!
		if isUsedFunctionEnum:
			$FunctionUseParameterEdit.visible = false
			$FunctionUseParameterChoice.visible = true
		else:
			$FunctionUseParameterEdit.visible = true
			$FunctionUseParameterChoice.visible = false
		



	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
