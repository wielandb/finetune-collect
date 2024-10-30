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
	$ParameterName.text = me["name"]
	$FunctionUseParameterIsUsedCheckbox.button_pressed = me["isUsed"]
	$FunctionUseParameterEdit.text = me["parameterValueText"]
	$FunctionUseParameterChoice.select(selectionStringToIndex($FunctionUseParameterChoice, me["parameterValueChoice"]))
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
