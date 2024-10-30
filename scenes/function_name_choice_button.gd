extends OptionButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_down() -> void:
	print("Updating dropdown menu")
	clear()
	for item in get_tree().get_node("FineTune").get_available_function_names():
		add_item(item)	
