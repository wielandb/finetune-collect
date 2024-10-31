extends VBoxContainer

@onready var result_parameters_scene = preload("res://scenes/function_call_results_parameter.tscn")
# Called when the node enters the scene tree for the first time.


func _ready() -> void:
	pass # Replace with function body.

func to_var():
	var me = {}
	me["name"] = $function/FunctionNameChoiceButton.selected
	var tmpParameters = []
	for parameter in get_children():
		if parameter.is_in_group("function_use_parameter"):
			tmpParameters.append(parameter.to_var())
	me["parameters"] = tmpParameters
	var tmpResults = []
	for result in get_children():
		if result.is_in_group("function_use_result"):
			tmpResults.append(result.to_var())
	me["results"] = tmpResults
	return me

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_result_button_pressed() -> void:
	var newResultParameter = result_parameters_scene.instantiate()
	add_child(newResultParameter)
	var addResultButton = $AddResultButton
	move_child(addResultButton, -1)
