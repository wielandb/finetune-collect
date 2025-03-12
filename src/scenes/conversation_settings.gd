extends ScrollContainer
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")

var default_schema_editor_url = "https://example.com/editor.php"
var schema_loader_file_access_web = FileAccessWeb.new()

func to_var():
	var me = {}
	me["useGlobalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageCheckbox.button_pressed
	me["globalSystemMessage"] = $VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit.text
	me["apikey"] = $VBoxContainer/APIKeySettingContainer/APIKeyEdit.text
	if $VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.item_count == 0:
		me["modelChoice"] = ""
	else:
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
	me["tokenCounterPath"] = $VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.text
	me["exportConvos"] = $VBoxContainer/ExportWhatConvoContainer/ExportWhatConvosOptionButton.selected
	me["countTokensWhen"] = $VBoxContainer/TokenCountWhenContainer/TokenCounterWhenOptionButton.selected
	me["tokenCounts"] = $VBoxContainer/TokenCountPathContainer/TokenCountValueHolder.text
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
	$VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.text = me.get("tokenCounterPath", "")
	$VBoxContainer/ExportWhatConvoContainer/ExportWhatConvosOptionButton.selected = me.get("exportConvos", 0)
	$VBoxContainer/TokenCountWhenContainer/TokenCounterWhenOptionButton.selected = me.get("countTokensWhen", 0)
	$VBoxContainer/TokenCountPathContainer/TokenCountValueHolder.text = me.get("tokenCounts", "{}")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Explain why some things are disabled
	$VBoxContainer/FineTuningTypeSettingContainer/FineTuningTypeSettingOptionButton.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NOT_IMPLEMENTED_YET"))
	$VBoxContainer/ExportImagesHowContainer/ExportImagesHowOptionButton.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NOT_IMPLEMENTED_YET"))
	openai.connect("models_received", models_received)
	# TODO: This should only be called if an OpenAI API key is set
	openai.get_models()
	schema_loader_file_access_web.loaded.connect(_on_schema_file_loaded)
	#schema_loader_file_access_web.progress.connect(_on_file_access_web_progress)
	print("OSNAME")
	print(OS.get_name())
	match OS.get_name():
		"Web":
			$VBoxContainer/BatchCreatonContainer/BatchCreationButton.disabled = true
			$VBoxContainer/BatchCreatonContainer/BatchCreationButton.tooltip_text = tr("DISABLED_EXPLANATION_NOT_AVAILABLE_IN_WEB")
			$VBoxContainer/TokenCountPathContainer/TokenCounterFilePickerBtn.disabled = true
			$VBoxContainer/TokenCountPathContainer/TokenCounterFilePickerBtn.tooltip_text = tr("DISABLED_EXPLANATION_NOT_AVAILABLE_IN_WEB")
			$VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.disabled = true
func _on_schema_file_loaded(file_name: String, file_type: String, base64_data: String) -> void:
	var txtdata = Marshalls.base64_to_utf8(base64_data)
	$VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text = txtdata
	update_valid_json_for_schema_checker()

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
	match OS.get_name():
		"Web":
			schema_loader_file_access_web.open(".json, .txt, .jsonschema, .schema")
		_:
			$VBoxContainer/SchemaContainer/LoadSchemaFileDialog.visible = true


func _on_load_schema_file_dialog_file_selected(path: String) -> void:
	var json_as_text = FileAccess.get_file_as_string(path)
	$VBoxContainer/SchemaContainer/SchemaContentContainer/SchemaContentEditor.text = json_as_text
	update_valid_json_for_schema_checker()
	

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

# Batch Creation
func create_image_message_dict_from_path(path):
	# Returns a message var that contains that image as base64
	var bin = FileAccess.get_file_as_bytes(path)
	var base_64_data = Marshalls.raw_to_base64(bin)
	return {
		"role": "user",
		"type": "Image",
		"imageContent": base_64_data
	}

func create_text_message_dict_from_path(path):
	var txtcontent = FileAccess.get_file_as_string(path)
	return {
		"role": "user",
		"type": "Text",
		"textContent": txtcontent
	}


func _on_batch_creation_button_pressed() -> void:
	$VBoxContainer/BatchCreatonContainer/BatchCreationFileDialog.visible = true

func _on_batch_creation_file_dialog_files_selected(paths: PackedStringArray) -> void:
	var first_messages = []
	var ft = get_node("/root/FineTune")
	var userSelection = $VBoxContainer/BatchCreatonContainer/BatchCreationRoleChoiceBox.selected
	var modeSelection = $VBoxContainer/BatchCreatonContainer/BatchCreationModeChoiceBox.selected
	for file in paths:
		if file.ends_with(".jpg") or file.ends_with(".jpeg"):
			first_messages.append(create_image_message_dict_from_path(file))
		if file.ends_with(".txt") or file.ends_with(".json"):
			first_messages.append(create_text_message_dict_from_path(file))
		if file.ends_with(".mp3") or file.ends_with(".wav") or file.ends_with(".aac"):
			pass
	for message in first_messages:
			ft.create_new_conversation([{"type": "meta", "role": "meta"}, message])


func _on_token_counter_file_picker_btn_pressed() -> void:
	$VBoxContainer/TokenCountPathContainer/TokenCounterLocalizerFileDialog.visible = true

func _on_token_counter_localizer_file_dialog_file_selected(path: String) -> void:
	$VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.text = path
