extends ScrollContainer
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")

var default_schema_editor_url = "https://example.com/editor.php"

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
	me["finetuneType"] = $VBoxContainer/FineTuningTypeSettingContainer/FineTuningTypeSettingOptionButton.selected
	me["exportImagesHow"] = $VBoxContainer/ExportImagesHowContainer/ExportImagesHowOptionButton.selected
	me["useUserNames"] = $VBoxContainer/UseUserNamesCheckbox.button_pressed
	me["schemaEditorURL"] = $VBoxContainer/SchemaEditorURLContainer/SchemaEditorURLEdit.text
	me["jsonSchema"] = $VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text
	return me
	
func from_var(me):
	# data -> SETTINGS
	$VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed = me["useGlobalSystemMessage"]
	$VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text = me["globalSystemMessage"]
	$VBoxContainer/APIKeySettingContainer/APIKeyEdit.text = me["apikey"]
	openai.set_api($VBoxContainer/APIKeySettingContainer/APIKeyEdit.text)
	$VBoxContainer/AlwaysIncludeFunctionsSettingContainer/AlwaysIncludeFunctionsSettingOptionButton.select(me.get("includeFunctions", 0))
	$VBoxContainer/ExportImagesHowContainer/ExportImagesHowOptionButton.select(me.get("exportImagesHow", 0))
	$VBoxContainer/UseUserNamesCheckbox.button_pressed = me.get("useUserNames", false)
	$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.clear()
	for m in me["availableModels"]:
		$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.add_item(m)
	for i in range($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.item_count):
		if ($VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.get_item_text(i) == me["modelChoice"]):
			$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.select(i)
	$VBoxContainer/FineTuningTypeSettingContainer/FineTuningTypeSettingOptionButton.select(me.get("finetuneType", 0))
	$VBoxContainer/SchemaEditorURLContainer/SchemaEditorURLEdit.text = me.get("schemaEditorURL", default_schema_editor_url)
	$VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text = me.get("jsonSchema", "")
	_on_schema_content_editor_text_changed()

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


func _on_schema_content_load_from_file_btn_pressed() -> void:
	$VBoxContainer/SchemaContainer/LoadSchemaFileDialog.visible = true

func _on_load_schema_file_dialog_file_selected(path: String) -> void:
	var json_as_text = FileAccess.get_file_as_string(path)
	$VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text = json_as_text

func validate_is_json(testtext) -> bool:
	if testtext == "":
		return false
	var json = JSON.new()
	var error = json.parse(testtext)
	if error == OK:
		return true
	else:
		return false
		
func update_valid_json_for_schema_checker() -> bool:
	# The return value is not used in the function below, but it is when called externally by the message object
	if validate_is_json($VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text):
		$VBoxContainer/SchemaContainer/SchemaValidCheckImg.texture = load("res://icons/code-json-check-positive.png")
		return true
	else:
		$VBoxContainer/SchemaContainer/SchemaValidCheckImg.texture = load("res://icons/code-json-check-negative.png")
		return false

func _on_schema_content_editor_text_changed() -> void:
	update_valid_json_for_schema_checker()
