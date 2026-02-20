extends VBoxContainer

@onready var PARAMETER_SCENE = preload("res://scenes/parameter.tscn")


func to_var():
	var me = {}
	me["name"] = $FunctionNameContainer/FunctionNameEdit.text
	me["description"] = $FunctionDescriptionContainer2/FunctionDescriptionEdit.text
	var tmpParameters = []
	# loop over all children and only treat the parameters
	for parameterContainer in get_children():
		if parameterContainer.is_in_group("available_parameter"):
			tmpParameters.append(parameterContainer.to_var())
	me["parameters"] = tmpParameters
	me["functionExecutionEnabled"] = $FunctionExecutionSettings/FunctionExecutionEnabled.button_pressed
	me["functionExecutionExecutable"] = $FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutablePathContainer/ExecutablePathEdit.text
	me["functionExecutionArgumentsString"] =  $FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutionParametersContainer/ExecutionParametersEdit.text
	return me
	
func from_var(data):
	PARAMETER_SCENE = load("res://scenes/parameter.tscn")
	$FunctionNameContainer/FunctionNameEdit.text = data["name"]
	$FunctionDescriptionContainer2/FunctionDescriptionEdit.text = data["description"]
	for parameter in data["parameters"]:
		var parameter_instance = PARAMETER_SCENE.instantiate()
		var parametersLabelIx = $parameterslabel.get_index()
		add_child(parameter_instance)
		parameter_instance.add_to_group("available_parameter")
		parameter_instance.from_var(parameter)
		move_child(parameter_instance, parametersLabelIx + 1)
	$FunctionExecutionSettings/FunctionExecutionEnabled.button_pressed = data.get("functionExecutionEnabled", false)
	$FunctionExecutionSettings/FunctionExecutionConfiguration.visible = data.get("functionExecutionEnabled", false)
	$FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutablePathContainer/ExecutablePathEdit.text = data.get("functionExecutionExecutable", "")
	$FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutionParametersContainer/ExecutionParametersEdit.text = data.get("functionExecutionArgumentsString", "")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_parameter_button_pressed() -> void:
	var AddParameterButton = $AddParameterButton
	var DelteFnBtn = $DeleteFunctionButton
	var fesettings = $FunctionExecutionSettings
	var newParameter = PARAMETER_SCENE.instantiate()
	newParameter.add_to_group("available_parameter")
	add_child(newParameter)
	move_child(DelteFnBtn, -1)
	move_child(fesettings, -2)
	move_child(AddParameterButton, -3)
	


func _on_delete_function_button_pressed() -> void:
	queue_free()

func _on_delete_function_button_mouse_entered() -> void:
	if $DeleteFunctionButton.disabled:
		return
	$DeleteFunctionButton.icon = load("res://icons/trashcanOpen_small.png")

func _on_delete_function_button_mouse_exited() -> void:
	if $DeleteFunctionButton.disabled:
		return
	$DeleteFunctionButton.icon = load("res://icons/trashcan_small.png")


func update_available_functions_global():
	get_node("/root/FineTune").update_functions_internal()

## Funktionen, die alle ausgeführt werden, wenn sich irgendwas ändert
func _on_function_name_edit_text_changed(new_text: String) -> void:
	update_available_functions_global()
	
func self_has_name() -> bool:
	if $FunctionNameContainer/FunctionNameEdit.text == "":
		return false
	return true

static func find_children_in_group(parent: Node, group: String, recursive: bool = false):
	var output: Array[Node] = []
	for child in parent.get_children() :
		if child.is_in_group(group) :
			output.append(child)
	if recursive :
		for child in parent.get_children() :
			var recursive_output =  find_children_in_group(child, group, recursive)
			for recursive_child in recursive_output :
				output.append(recursive_child)
	return output

func self_get_parameter_names():
	var parameter_names = []
	for paramScene in $".".find_children_in_group($".", "available_parameter"):
		var pn = paramScene.get_node("ParameterNameEdit").text
		parameter_names.append(pn)
	return parameter_names
		

func _on_test_button_pressed() -> void:
	var output = []
	var parameters_raw_string = $FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutionParametersContainer/ExecutionParametersEdit.text
	var parameters_replace_vars = parameters_raw_string
	print("Checking parameters")
	for parameterName in self_get_parameter_names():
		print(parameterName)
		print(parameters_replace_vars.contains("%"))
		print(parameters_replace_vars.contains("%"+ str(parameterName)))
		parameters_replace_vars = parameters_replace_vars.replace("%" + str(parameterName) + "%", "TESTVAR")
	var argumentslist = []
	for parameter in parameters_replace_vars.split("<|>"):
		argumentslist.append(parameter) # TODO: Append an example value
	var exit_code = OS.execute($FunctionExecutionSettings/FunctionExecutionConfiguration/ExecutablePathContainer/ExecutablePathEdit.text, argumentslist, output)
	print(exit_code)
	print(output[0])


func _on_function_execution_enabled_toggled(toggled_on: bool) -> void:
	$FunctionExecutionSettings/FunctionExecutionConfiguration.visible = toggled_on
