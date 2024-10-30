extends ScrollContainer

func to_var():
	var me = {}
	me["useGlobalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed
	me["globalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text
	return me
	
func from_var(me):
	# data -> SETTINGS
	$VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed = me["useGlobalSystemMessage"]
	$VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text = me["globalSystemMessage"]
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_settings_global():
	get_node("/root/FineTune").update_settings_internal()
	
