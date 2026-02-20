extends HBoxContainer

func to_var():
	var me = {}
	me["key"] = $KeyLineEdit.text
	me["value"] = $ValueLineEdit.text
	return me
	
func from_var(me):
	$KeyLineEdit.text = me["key"]
	$ValueLineEdit.text = me["value"]
	
	
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_delete_button_pressed() -> void:
	queue_free()

func _on_delete_button_mouse_entered() -> void:
	if $DeleteButton.disabled:
		return
	$DeleteButton.icon = load("res://icons/trashcanOpen_small.png")

func _on_delete_button_mouse_exited() -> void:
	if $DeleteButton.disabled:
		return
	$DeleteButton.icon = load("res://icons/trashcan_small.png")
