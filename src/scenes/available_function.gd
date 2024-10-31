extends VBoxContainer

@onready var PARAMETER_SCENE = preload("res://parameter.tscn")


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
	return me
	
func from_var(data):
	$FunctionNameContainer/FunctionNameEdit.text = data["name"]
	$FunctionDescriptionContainer2/FunctionDescriptionEdit.text = data["description"]
	for parameter in data["parameters"]:
		var parameter_instance = PARAMETER_SCENE.instantiate()
		var parametersLabelIx = $parameterslabel.get_index()
		add_child(parameter_instance)
		parameter_instance.from_var(parameter)
		move_child(parameter_instance, parametersLabelIx + 1)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_parameter_button_pressed() -> void:
	var AddParameterButton = $AddParameterButton
	var DelteFnBtn = $DeleteFunctionButton
	var newParameter = PARAMETER_SCENE.instantiate()
	newParameter.add_to_group("available_parameter")
	add_child(newParameter)
	move_child(DelteFnBtn, -1)
	move_child(AddParameterButton, -2)
	


func _on_delete_function_button_pressed() -> void:
	queue_free()


func update_available_functions_global():
	get_node("/root/FineTune").update_functions_internal()

## Funktionen, die alle ausgeführt werden, wenn sich irgendwas ändert
func _on_function_name_edit_text_changed(new_text: String) -> void:
	update_available_functions_global()
	
