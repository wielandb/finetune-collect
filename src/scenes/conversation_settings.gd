extends ScrollContainer
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")

var default_schema_editor_url = "https://example.com/editor.php"
var default_schema_validator_url = ""
const DESKTOP_SETTINGS_TITLE_FONT_SIZE = 29
const COMPACT_SETTINGS_TITLE_FONT_SIZE = 22
const SETTINGS_ROW_OVERFLOW_BUFFER = 2.0
const SETTINGS_ROW_NAMES = [
	"HBoxContainer",
	"MinimalImageHeightContainer",
	"FineTuningTypeSettingContainer",
	"RFTSplitConversationsSettingContainer",
	"ExportImagesHowContainer",
	"AlwaysIncludeFunctionsSettingContainer",
	"ExportWhatConvoContainer",
	"APIKeySettingContainer",
	"ModelChoiceContainer",
	"BatchCreatonContainer",
	"FromClipboardJSONCreationContainer",
	"TokenCountPathContainer",
	"TokenCountWhenContainer",
	"TokenCountModelChoiceContainer",
	"ImageUplaodSettingContainer",
	"ImageUploadServerURLContainer",
	"ImageUploadServerKeyContainer",
	"ImageUploadServerTestContainer",
	"SchemaEditorURLContainer",
	"SchemaValidatorURLContainer"
]
var _compact_layout_enabled = false
var _effective_compact_layout_enabled = false
var _layout_refresh_queued = false
var _compact_control_defaults = {}

func _remember_control_defaults(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var rel_path = get_path_to(control)
	if _compact_control_defaults.has(rel_path):
		return
	var defaults = {
		"size_flags_horizontal": control.size_flags_horizontal,
		"custom_minimum_size": control.custom_minimum_size,
		"visible": control.visible
	}
	if control is OptionButton:
		defaults["fit_to_longest_item"] = control.fit_to_longest_item
	if control is Label:
		defaults["autowrap_mode"] = control.autowrap_mode
	if control is BaseButton:
		defaults["clip_text"] = control.clip_text
	_compact_control_defaults[rel_path] = defaults

func _apply_compact_to_control(control: Control, enabled: bool) -> void:
	if not is_instance_valid(control):
		return
	var rel_path = get_path_to(control)
	_remember_control_defaults(control)
	if enabled:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var min_size = control.custom_minimum_size
		min_size.x = 0
		control.custom_minimum_size = min_size
		if control is OptionButton:
			control.fit_to_longest_item = false
		if control is Label:
			control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if control is BaseButton:
			control.clip_text = true
		if control is TextureRect and control.name.find("Hint") != -1:
			control.visible = false
	else:
		if _compact_control_defaults.has(rel_path):
			var defaults = _compact_control_defaults[rel_path]
			control.size_flags_horizontal = int(defaults.get("size_flags_horizontal", control.size_flags_horizontal))
			control.custom_minimum_size = defaults.get("custom_minimum_size", control.custom_minimum_size)
			control.visible = bool(defaults.get("visible", control.visible))
			if control is OptionButton and defaults.has("fit_to_longest_item"):
				control.fit_to_longest_item = bool(defaults["fit_to_longest_item"])
			if control is Label and defaults.has("autowrap_mode"):
				control.autowrap_mode = int(defaults["autowrap_mode"])
			if control is BaseButton and defaults.has("clip_text"):
				control.clip_text = bool(defaults["clip_text"])

func _apply_compact_to_controls_recursive(node: Node, enabled: bool) -> void:
	if node is Control:
		_apply_compact_to_control(node, enabled)
	for child in node.get_children():
		_apply_compact_to_controls_recursive(child, enabled)

func _get_settings_rows() -> Array:
	var rows = []
	for row_name in SETTINGS_ROW_NAMES:
		var row = get_node_or_null("VBoxContainer/" + row_name)
		if row is BoxContainer:
			rows.append(row)
	return rows

func _row_requires_stacked_layout(row: BoxContainer) -> bool:
	if row == null or not row.visible:
		return false
	var available_width = row.size.x
	if available_width <= 0.0:
		return false
	var furthest_child_right = 0.0
	var visible_children = 0
	for child in row.get_children():
		if child is Control and child.visible:
			furthest_child_right = maxf(furthest_child_right, child.position.x + child.size.x)
			visible_children += 1
	if visible_children <= 1:
		return false
	if furthest_child_right > available_width + SETTINGS_ROW_OVERFLOW_BUFFER:
		return true
	var required_width = 0.0
	var separation = float(row.get_theme_constant("separation"))
	for child in row.get_children():
		if child is Control and child.visible:
			required_width += child.get_combined_minimum_size().x
	if visible_children > 1:
		required_width += separation * float(visible_children - 1)
	return required_width > available_width + SETTINGS_ROW_OVERFLOW_BUFFER

func _desktop_rows_would_overflow() -> bool:
	for row in _get_settings_rows():
		if _row_requires_stacked_layout(row):
			return true
	return false

func _apply_effective_compact_layout(enabled: bool, force: bool = false) -> void:
	if not force and _effective_compact_layout_enabled == enabled:
		return
	_effective_compact_layout_enabled = enabled
	for row in _get_settings_rows():
		row.vertical = enabled
	_apply_compact_to_controls_recursive($VBoxContainer, enabled)
	if enabled:
		scroll_horizontal = 0
	if enabled:
		$VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextLabel.add_theme_font_size_override("font_size", COMPACT_SETTINGS_TITLE_FONT_SIZE)
	else:
		$VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextLabel.add_theme_font_size_override("font_size", DESKTOP_SETTINGS_TITLE_FONT_SIZE)

func _queue_layout_refresh() -> void:
	if _layout_refresh_queued:
		return
	_layout_refresh_queued = true
	call_deferred("_refresh_layout_state")

func _refresh_layout_state() -> void:
	_layout_refresh_queued = false
	if not is_inside_tree():
		return
	if _compact_layout_enabled:
		_apply_effective_compact_layout(true)
		return
	# Measure in desktop mode first so overflow detection uses desktop metrics.
	_apply_effective_compact_layout(false, true)
	call_deferred("_apply_desktop_overflow_safety")

func _apply_desktop_overflow_safety() -> void:
	if not is_inside_tree() or _compact_layout_enabled:
		return
	if _desktop_rows_would_overflow():
		_apply_effective_compact_layout(true)
	else:
		_apply_effective_compact_layout(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_layout_refresh()

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	_refresh_layout_state()

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
	me["schemaValidatorURL"] = $VBoxContainer/SchemaValidatorURLContainer/SchemaValidatorURLEdit.text
	me["imageUploadSetting"] = $VBoxContainer/ImageUplaodSettingContainer/ImageUplaodSettingOptionButton.selected
	me["imageUploadServerURL"] = $VBoxContainer/ImageUploadServerURLContainer/ImageUploadServerURLEdit.text
	me["imageUploadServerKey"] = $VBoxContainer/ImageUploadServerKeyContainer/ImageUploadServerKeyEdit.text
	me["tokenCounterPath"] = $VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.text
	me["exportConvos"] = $VBoxContainer/ExportWhatConvoContainer/ExportWhatConvosOptionButton.selected
	me["countTokensWhen"] = $VBoxContainer/TokenCountWhenContainer/TokenCounterWhenOptionButton.selected
	me["tokenCounts"] = $VBoxContainer/TokenCountPathContainer/TokenCountValueHolder.text
	me["countTokensModel"] = $VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.selected
	me["doRFTExportConversationSplits"] = $VBoxContainer/RFTSplitConversationsSettingContainer/RFTSplitOptionButton.selected
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
	$VBoxContainer/SchemaValidatorURLContainer/SchemaValidatorURLEdit.text = me.get("schemaValidatorURL", default_schema_validator_url)
	$VBoxContainer/ImageUplaodSettingContainer/ImageUplaodSettingOptionButton.selected = me.get("imageUploadSetting", 0)
	$VBoxContainer/ImageUploadServerURLContainer/ImageUploadServerURLEdit.text = me.get("imageUploadServerURL", "")
	$VBoxContainer/ImageUploadServerKeyContainer/ImageUploadServerKeyEdit.text = me.get("imageUploadServerKey", "")
	$VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.text = me.get("tokenCounterPath", "")
	$VBoxContainer/ExportWhatConvoContainer/ExportWhatConvosOptionButton.selected = me.get("exportConvos", 0)
	$VBoxContainer/TokenCountWhenContainer/TokenCounterWhenOptionButton.selected = me.get("countTokensWhen", 0)
	$VBoxContainer/TokenCountPathContainer/TokenCountValueHolder.text = me.get("tokenCounts", "{}")
	# Token count model choice
	## Load the available models
	$VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.clear()
	for item in load_available_fine_tuning_models_from_file():
		$VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.add_item(item)
	$VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.selected = me.get("countTokensModel", 0)
	$VBoxContainer/RFTSplitConversationsSettingContainer/RFTSplitOptionButton.selected = me.get("doRFTExportConversationSplits", 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	clip_contents = true
	# Explain why some things are disabled
	$VBoxContainer/FineTuningTypeSettingContainer/FineTuningTypeSettingOptionButton.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NOT_IMPLEMENTED_YET"))
	$VBoxContainer/ExportImagesHowContainer/ExportImagesHowOptionButton.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NOT_IMPLEMENTED_YET"))
	openai.connect("models_received", models_received)
	# Get available fine-tuning-models from asset file and set for the option button
	$VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.clear()
	for item in load_available_fine_tuning_models_from_file():
		$VBoxContainer/TokenCountModelChoiceContainer/TokenCountModelChoiceOptionButton.add_item(item)
	# TODO: This should only be called if an OpenAI API key is set
	openai.get_models()
	print("OSNAME")
	print(OS.get_name())
	match OS.get_name():
		"Web":
			$VBoxContainer/BatchCreatonContainer/BatchCreationButton.disabled = true
			$VBoxContainer/BatchCreatonContainer/BatchCreationButton.tooltip_text = tr("DISABLED_EXPLANATION_NOT_AVAILABLE_IN_WEB")
			$VBoxContainer/TokenCountPathContainer/TokenCounterFilePickerBtn.disabled = true
			$VBoxContainer/TokenCountPathContainer/TokenCounterFilePickerBtn.tooltip_text = tr("DISABLED_EXPLANATION_NOT_AVAILABLE_IN_WEB")
			$VBoxContainer/TokenCountPathContainer/TokenCounterPathLineEdit.disabled = true
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func models_received(models: Array[String]):
	# Make the selectable models the models that are given back here
	$VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton.clear()
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
	
func load_available_fine_tuning_models_from_file():
	var cost_json = FileAccess.get_file_as_string("res://assets/openai_costs.json").strip_edges()
	#print(cost_json)
	var costs = JSON.parse_string(cost_json)
	return costs["available_models"]

func validate_is_json(testtext) -> bool:
	if testtext == "":
		return false
	var json = JSON.new()
	var err = json.parse(testtext)
	if err == OK:
		return true
	return false


func _on_model_choice_refresh_button_pressed() -> void:
	openai.get_models()


# Batch Creation
func create_image_message_dict_from_path(path):
	# Returns a message var that contains that image as base64
	var bin = FileAccess.get_file_as_bytes(path)
	var base_64_data = Marshalls.raw_to_base64(bin)
	return {
		"role": "user",
		"type": "Image",
		"imageContent": base_64_data,
		"imageDetail": 0
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
		if file.ends_with(".jpg") or file.ends_with(".jpeg") or file.ends_with(".png"):
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

func _on_something_int_needs_update_global(index: int) -> void:
	update_settings_global()

func _on_image_upload_server_key_edit_text_changed(new_text: String) -> void:
	update_settings_global()
	
func _on_image_upload_server_url_edit_text_changed(new_text: String) -> void:
	update_settings_global()

func _on_image_uplaod_setting_option_button_item_selected(index: int) -> void:
	update_settings_global()

func _on_image_upload_server_test_button_pressed() -> void:
	var upload_url = $VBoxContainer/ImageUploadServerURLContainer/ImageUploadServerURLEdit.text
	var upload_key = $VBoxContainer/ImageUploadServerKeyContainer/ImageUploadServerKeyEdit.text
	if upload_url == "" or upload_key == "":
		$VBoxContainer/ImageUploadServerTestContainer/ImageUploadServerTestResultImg.texture = load("res://icons/code-json-check-negative.png")
		return
	var test_url = upload_url + "?test=1&key=" + upload_key
	var err = $ImageUploadServerTestRequest.request(test_url)
	if err != OK:
		$VBoxContainer/ImageUploadServerTestContainer/ImageUploadServerTestResultImg.texture = load("res://icons/code-json-check-negative.png")

func _on_image_upload_server_test_request_completed(result, response_code, headers, body):
	var txt = body.get_string_from_utf8().strip_edges()
	if response_code == 200 and txt == "ok":
		$VBoxContainer/ImageUploadServerTestContainer/ImageUploadServerTestResultImg.texture = load("res://icons/code-json-check-positive.png")
	else:
		$VBoxContainer/ImageUploadServerTestContainer/ImageUploadServerTestResultImg.texture = load("res://icons/code-json-check-negative.png")
