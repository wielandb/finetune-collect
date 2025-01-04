extends ScrollContainer
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")

func to_var():
	var me = {}
	me["useGlobalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed
	me["globalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text
	me["apikey"] = $VBoxContainer/APIKeySettingContainer/APIKeyEdit.text
	me["modelChoice"] = $VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.get_item_text($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.selected)
	var availableModels = []
	for i in range($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.item_count):
		availableModels.append($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.get_item_text(i))
	me["availableModels"] = availableModels
	me["includeFunctions"] = $VBoxContainer/AlwaysIncludeFunctionsSettingContainer/AlwaysIncludeFunctionsSettingOptionButton.selected
	return me
	
func from_var(me):
	# data -> SETTINGS
	$VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed = me["useGlobalSystemMessage"]
	$VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text = me["globalSystemMessage"]
	$VBoxContainer/APIKeySettingContainer/APIKeyEdit.text = me["apikey"]
	openai.set_api($VBoxContainer/APIKeySettingContainer/APIKeyEdit.text)
	$VBoxContainer/AlwaysIncludeFunctionsSettingContainer/AlwaysIncludeFunctionsSettingOptionButton.select(me.get("includeFunctions", 0))
	$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.clear()
	for m in me["availableModels"]:
		$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.add_item(m)
	for i in range($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.item_count):
		if ($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.get_item_text(i) == me["modelChoice"]):
			$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.select(i)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	openai.connect("models_received", models_received)
	openai.get_models()

func models_received(models: Array[String]):
	# Make the selectable models the models that are given back here
	for m in models:
		$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.add_item(m)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_settings_global():
	get_node("/root/FineTune").update_settings_internal()
	

func _on_api_key_edit_text_changed(new_text: String) -> void:
	openai.set_api(new_text)
	update_settings_global()
	openai.get_models()
	



func _on_model_choice_refresh_button_pressed() -> void:
	openai.get_models()
