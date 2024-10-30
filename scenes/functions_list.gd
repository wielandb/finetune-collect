extends ScrollContainer

@onready var available_function_scene = preload("res://scenes/available_function.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func to_var():
	var me = []
	for functionContainer in $FunctionsListContainer.get_children():
		if functionContainer.is_in_group("available_function"):
			me.append(functionContainer.to_var())
	return me

func from_var(data):
	# data -> FUNCTIONS -> [] function
	for f in data:
		var availableFunctionInstance = available_function_scene.instantiate()
		var addButton = $FunctionsListContainer/AddFunctionButton
		$FunctionsListContainer.add_child(availableFunctionInstance)
		availableFunctionInstance.from_var(f)
		$FunctionsListContainer.move_child(addButton, -1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_function_button_pressed() -> void:
	var newInst = available_function_scene.instantiate()
	$FunctionsListContainer.add_child(newInst)
	var newBtn = $FunctionsListContainer/AddFunctionButton
	$FunctionsListContainer.move_child(newBtn, -1)
	print(self.to_var())
