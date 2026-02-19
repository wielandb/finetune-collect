extends HBoxContainer
const RESULT_PARAMETERS_SCENE = preload("res://scenes/function_call_results_parameter.tscn")
const FUNCTION_USE_PARAMETERS_SCENE = preload("res://scenes/function_use_parameter.tscn")
@onready var schema_edit = $SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaEdit
@onready var schema_tabs = $SchemaMessageContainer/SchemaEditTabs
@onready var schema_form_root = $SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll/SchemaFormRoot
@onready var schema_form_hint_label = $SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormHintLabel

var image_access_web = null
var token = "" # The token for the schema editor for this message
var edit_message_url = ""
var last_base64_to_upload = ""

const VALID_ICON_OK := "res://icons/code-json-check-positive.png"
const VALID_ICON_BAD := "res://icons/code-json-check-negative.png"
const JsonSchemaValidator := preload("res://json_schema_validator.gd")
const SchemaFormController = preload("res://scenes/schema_runtime/schema_form_controller.gd")
var _schema_validate_timer: Timer
var _schema_form_controller = SchemaFormController.new()
var _schema_sync_guard = false
var _schema_last_selected_name = ""

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func _schema_edit_node():
	if schema_edit != null:
		return schema_edit
	return get_node_or_null("SchemaMessageContainer/SchemaEditTabs/SchemaRawTab/SchemaRawVBox/SchemaEdit")

func _schema_tabs_node():
	if schema_tabs != null:
		return schema_tabs
	return get_node_or_null("SchemaMessageContainer/SchemaEditTabs")

func _schema_form_root_node():
	if schema_form_root != null:
		return schema_form_root
	return get_node_or_null("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll/SchemaFormRoot")

func _schema_form_hint_label_node():
	if schema_form_hint_label != null:
		return schema_form_hint_label
	return get_node_or_null("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormHintLabel")

func _ensure_schema_form_bound() -> void:
	var form_root_node = _schema_form_root_node()
	if form_root_node != null:
		_schema_form_controller.bind_form_root(form_root_node)

func _get_fine_tune_node():
	if not is_inside_tree():
		return null
	var tree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("FineTune")

func to_var():
	var me = {}
	me["role"] = $MessageSettingsContainer/Role.get_item_text($MessageSettingsContainer/Role.selected)
	me["type"] = $MessageSettingsContainer/MessageType.get_item_text($MessageSettingsContainer/MessageType.selected)
	if me["type"] == "JSON Schema":
		me["type"] = "JSON"
	me["textContent"] = $TextMessageContainer/Message.text
	me["unpreferredTextContent"] = $TextMessageContainer/DPOMessagesContainer/DPOUnpreferredMsgContainer/DPOUnpreferredMsgEdit.text
	me["preferredTextContent"] = $TextMessageContainer/DPOMessagesContainer/DPOPreferredMsgContainer/DPOPreferredMsgEdit.text
	me["imageContent"] = $ImageMessageContainer/Base64ImageEdit.text
	me["imageDetail"] = $ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.selected
	me["functionName"] = ""
	if $FunctionMessageContainer/function/FunctionNameChoiceButton.selected != -1:
		me["functionName"] = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var tmpFunctionParameters = []
	for parameter in $FunctionMessageContainer.get_children():
		if parameter.is_in_group("function_use_parameter"):
			tmpFunctionParameters.append(parameter.to_var())
	me["functionParameters"] = tmpFunctionParameters
	#var tmpFunctionResults = []
	#for result in $FunctionMessageContainer.get_children():
	#	print("Inspecting Function Message Container")
	#	if result.is_in_group("function_use_result"):
	#		print("It was a function use result")
	#		tmpFunctionResults.append(result.to_var())
	me["functionResults"] = $FunctionMessageContainer/FunctionUseResultText.text
	me["functionUsePreText"] = $FunctionMessageContainer/preFunctionCallTextContainer/preFunctionCallTextEdit.text
	me["userName"] = $MessageSettingsContainer/UserNameEdit.text
	var schema_edit_node = _schema_edit_node()
	me["jsonSchemaValue"] = "{}"
	if schema_edit_node != null:
		me["jsonSchemaValue"] = schema_edit_node.text
	var schema_name := ""
	if $SchemaMessageContainer/HBoxContainer/OptionButton.selected > 0:
		schema_name = $SchemaMessageContainer/HBoxContainer/OptionButton.get_item_text($SchemaMessageContainer/HBoxContainer/OptionButton.selected)
	me["jsonSchemaName"] = schema_name
	if $MetaMessageContainer.visible:
		me["metaData"] = {}
		me["metaData"]["ready"] = $MetaMessageContainer/ConversationReadyContainer/ConversationReadyCheckBox.button_pressed
		me["metaData"]["conversationName"] = $MetaMessageContainer/ConversationNameContainer/ConversationNameEdit.text
		me["metaData"]["notes"] = $MetaMessageContainer/ConversationNotesEdit.text
		me["role"] = "meta"
		me["type"] = "meta"
	# Audio Message section
	me["audioData"] = $AudioMessageContainer/Base64AudioEdit.text
	me["audioTranscript"] = $AudioMessageContainer/TranscriptionContainer/RichTextLabel.text
	me["audioFiletype"] = $AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text
	# File Message section
	me["fileMessageData"] = $FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileDataBase64Edit.text
	me["fileMessageName"] = $FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileNameEdit.text
	return me

func from_var(data):
	var ft_node = _get_fine_tune_node()
	var settings = {}
	if ft_node != null:
		settings = ft_node.SETTINGS
	var finetunetype = settings.get("finetuneType", 0)
	var useUserNames = settings.get("useUserNames", false)
	print("tokenCounts:")
	print(settings.get("tokenCounts", "{}"))
	var savedTokenCounts = JSON.parse_string("{}")
	if settings.get("tokenCounts", "{}") != "":
		savedTokenCounts = JSON.parse_string(settings.get("tokenCounts", "{}"))
	print("Building from var")
	print(data)
	if data.get("role", "user") == "meta" and data.get("type", "Text") == "meta":
		$MessageSettingsContainer.visible = false
		$MetaMessageContainer.visible = true
		var metaData = data.get("metaData", {})
		$MetaMessageContainer/ConversationReadyContainer/ConversationReadyCheckBox.button_pressed = metaData.get("ready", false)
		$MetaMessageContainer/ConversationNameContainer/ConversationNameEdit.text = metaData.get("conversationName", "")
		$MetaMessageContainer/ConversationNotesEdit.text = metaData.get("notes", "")
		# Update the saved token counts if available
		if savedTokenCounts:
			update_token_costs(savedTokenCounts)
		return
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, data.get("role", "user")))
	_on_role_item_selected($MessageSettingsContainer/Role.selected)
	var msg_type = data.get("type", "Text")
	if msg_type == "JSON Schema":
		msg_type = "JSON"
		data["type"] = "JSON"
	$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, msg_type))
	_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
	$TextMessageContainer/Message.text = data.get("textContent", "")
	$TextMessageContainer/DPOMessagesContainer/DPOUnpreferredMsgContainer/DPOUnpreferredMsgEdit.text = data.get("unpreferredTextContent", "")
	$TextMessageContainer/DPOMessagesContainer/DPOPreferredMsgContainer/DPOPreferredMsgEdit.text = data.get("preferredTextContent", "")
	# Set the correct kind of message visible
	$TextMessageContainer/Message.visible = false
	$TextMessageContainer/DPOMessagesContainer.visible = false
	match finetunetype:
		0:
			$TextMessageContainer/Message.visible = true
		1:
			if data["role"] == "assistant":
				$TextMessageContainer/DPOMessagesContainer.visible = true
			else:
				$TextMessageContainer/Message.visible = true
		2:
			pass
	$ImageMessageContainer/Base64ImageEdit.text = data.get("imageContent", "")
	# If not empty, create the image from the base64
	if $ImageMessageContainer/Base64ImageEdit.text != "":
		if isImageURL($ImageMessageContainer/Base64ImageEdit.text):
			load_image_container_from_url($ImageMessageContainer/Base64ImageEdit.text)
		else:
			base64_to_image($ImageMessageContainer/TextureRect, $ImageMessageContainer/Base64ImageEdit.text)
	if data.has("imageDetail"):
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(data["imageDetail"])
	else: # TODO: Add option what the standard quality should be
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(0)
	maybe_upload_base64_image()
	# Now everything regarding functions
	var function_choice_button = $FunctionMessageContainer/function/FunctionNameChoiceButton
	var desired_function_name = str(data.get("functionName", ""))
	var function_ix = selectionStringToIndex(function_choice_button, desired_function_name)
	if function_ix < 0 and desired_function_name != "":
		function_choice_button.add_item(desired_function_name)
		function_ix = selectionStringToIndex(function_choice_button, desired_function_name)
	function_choice_button.select(function_ix)
	#if data["functionName"] != "":
	#	_on_function_name_choice_button_item_selected(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	for d in data.get("functionParameters", []):
		var parameterInstance = FUNCTION_USE_PARAMETERS_SCENE.instantiate()
		$FunctionMessageContainer.add_child(parameterInstance)
		var parameterSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel.get_index()
		$FunctionMessageContainer.move_child(parameterInstance, parameterSectionLabelIx)
		parameterInstance.from_var(d)
	$FunctionMessageContainer/FunctionUseResultText.text = str(data.get("functionResults", ""))
	$FunctionMessageContainer/preFunctionCallTextContainer/preFunctionCallTextEdit.text = str(data.get("functionUsePreText", ""))
	check_if_function_button_should_be_visible_or_disabled()
	_on_check_what_text_message_should_be_visisble()
	# All about user names
	$MessageSettingsContainer/UserNameEdit.visible = false
	$MessageSettingsContainer/UserNameEdit.text = data.get("userName", "")
	if data.get("role", "user") == "user":
		if useUserNames:
			$MessageSettingsContainer/UserNameEdit.visible = true
	# JSON
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node != null:
		_schema_sync_guard = true
		schema_edit_node.text = data.get("jsonSchemaValue", "{}")
		_schema_sync_guard = false
	var schema_option = $SchemaMessageContainer/HBoxContainer/OptionButton
	if schema_option.item_count == 0:
		schema_option.add_item("Only JSON")
	var saved_name = data.get("jsonSchemaName", "")
	if saved_name == "":
		if schema_option.item_count > 0:
			schema_option.select(0)
	else:
		var saved_ix = selectionStringToIndex(schema_option, saved_name)
		if saved_ix >= 0:
			schema_option.select(saved_ix)
		elif schema_option.item_count > 0:
			schema_option.select(0)
	_rebuild_schema_form_from_selection(false)
	_validate_schema_message()
	# Audio Message
	$AudioMessageContainer/Base64AudioEdit.text = data.get("audioData", "")
	$AudioMessageContainer/TranscriptionContainer/RichTextLabel.text = data.get("audioTranscript", "")
	# - Load the Audio Data into the Audio stream, if available
	if $AudioMessageContainer/Base64AudioEdit.text != "":
		$AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text = data.get("audioFiletype", "")
		var bin_audio_data = Marshalls.base64_to_raw($AudioMessageContainer/Base64AudioEdit.text)
		if $AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text == "mp3":
			$AudioMessageContainer/AudioStreamPlayer.stream = AudioStreamMP3.load_from_buffer(bin_audio_data)
		elif $AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text == "wav":
			$AudioMessageContainer/AudioStreamPlayer.stream = AudioStreamWAV.load_from_buffer(bin_audio_data)
		else:
			print("Invalid file format!")
	# File message
	$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileNameEdit.text = data.get("fileMessageName", "")
	$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileDataBase64Edit.text = data.get("fileMessageData", "")
	if $FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileNameEdit.text.ends_with(".pdf"):
		$FileMessageContainer/FileSelectorContainer/FileTypeSymbolTextureRect.texture = load("res://icons/file-pdf.png")

	#for d in data["functionResults"]:
	#	var resultInstance = result_parameters_scene.instantiate()
	#	$FunctionMessageContainer.add_child(resultInstance)
	#	var resultsSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel2.get_index()
	#	$FunctionMessageContainer.move_child(resultInstance, resultsSectionLabelIx)
	#	resultInstance.from_var(d)
		

## Functions for if the message object is part of a grader
func to_grader_var():
	var mevar = to_var()
	var gradermessage = {}
	if mevar["role"] == "user":
		if mevar["type"] == "Text":
			gradermessage = {
				"type": "message",
				"role": "user",
				"content": {
					"type": "input_text",
					"text" : mevar["textContent"]
				}
			}
			return gradermessage
		if mevar["type"] == "Image":
			var image_detail_map = {0: "high", 1: "low", 2: "auto"}
			gradermessage = {
				"type": "message",
				"role": "user",
				"content": {
					"type": "input_image",
					"image_url": mevar["imageContent"],
					"detail": image_detail_map.get(int(mevar.get("imageDetail", 0)), "high")
				}
			}
			return gradermessage
		return {
			"type": "message",
			"role": "user",
			"content": {
				"type": "input_text",
				"text": "[A UNSUPPORTED MESSAGE TYPE WAS OMITTED]"
			}
		}
	if mevar["role"] == "system":
		if mevar["type"] == "Text":
			gradermessage = {
				"type": "message",
				"role": "system",
				"content": {
					"type": "input_text",
					"text": mevar["textContent"]
				}
			}
			return gradermessage
		return {
			"type": "message",
			"role": "system",
			"content": {
				"type": "input_text",
				"text": "[A UNSUPPORTED MESSAGE TYPE WAS OMITTED]"
			}
		}
	if mevar["role"] == "assistant":
		if mevar["type"] == "Text":
			gradermessage = {
				"type": "message",
				"role": "assistant",
				"content": {
					"type": "output_text",
					"text": mevar["textContent"]
				}
			}
			return gradermessage
		return {
			"type": "message",
			"role": "assistant",
			"content": {
				"type": "input_text",
				"text": "[A UNSUPPORTED MESSAGE TYPE WAS OMITTED]"
			}
		}

func from_grader_var(gradermessage):
	var role = gradermessage.get("role", "user")
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, role))
	_on_role_item_selected($MessageSettingsContainer/Role.selected)
	var content = gradermessage.get("content", {})
	var content_type = content.get("type", "")
	if role == "user":
		if content_type == "input_text":
			$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Text"))
			_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
			$TextMessageContainer/Message.text = content.get("text", "")
		elif content_type == "input_image":
			$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Image"))
			_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
			var img = content.get("image_url", "")
			$ImageMessageContainer/Base64ImageEdit.text = img
			var image_detail_map = {"high":0, "low":1, "auto":2}
			$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(image_detail_map.get(content.get("detail", "high"), 0))
			if img != "":
				if isImageURL(img) or img.begins_with("http://") or img.begins_with("https://"):
					load_image_container_from_url(img)
				else:
					base64_to_image($ImageMessageContainer/TextureRect, img)
			maybe_upload_base64_image()
	elif role == "system":
		if content_type == "input_text":
			$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Text"))
			_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
			$TextMessageContainer/Message.text = content.get("text", "")
	elif role == "assistant":
		if content_type == "output_text":
			$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Text"))
			_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
			$TextMessageContainer/Message.text = content.get("text", "")




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Init Message object")
	var ft_node = _get_fine_tune_node()
	if ft_node != null:
		for item in ft_node.get_available_function_names():
			$FunctionMessageContainer/function/FunctionNameChoiceButton.add_item(item)
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(-1)
	if ft_node != null and ft_node.has_method("update_available_schemas_in_UI_global"):
		ft_node.update_available_schemas_in_UI_global()
	elif $SchemaMessageContainer/HBoxContainer/OptionButton.item_count == 0:
		$SchemaMessageContainer/HBoxContainer/OptionButton.add_item("Only JSON")
	$SchemaMessageContainer/HBoxContainer/OptionButton.select(-1)
	var finetunetype = 0
	if ft_node != null:
		finetunetype = ft_node.SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		# DPO: Only User and assistant messages are available, only text
		$MessageSettingsContainer/MessageType.set_item_disabled(1, true)
		$MessageSettingsContainer/MessageType.set_item_disabled(2, true)
		$MessageSettingsContainer/Role.set_item_disabled(0, true)
	_on_check_what_text_message_should_be_visisble()
	if OS.get_name() == "Web":
		image_access_web = FileAccessWeb.new()
		if image_access_web != null:
			image_access_web.loaded.connect(_on_file_loaded)
			image_access_web.progress.connect(_on_progress)
	var token_counter_path = ""
	if ft_node != null:
		token_counter_path = ft_node.SETTINGS.get("tokenCounterPath", "")
	if token_counter_path == "":
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.disabled = true
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_TOKEN_COUNTER_PATH")
	else:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.tooltip_text = ""
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.disabled = false
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node != null:
		schema_edit_node.text_changed.connect(_on_schema_edit_text_changed)
	$SchemaMessageContainer/HBoxContainer/OptionButton.item_selected.connect(_on_schema_option_selected)
	var schema_tabs_node = _schema_tabs_node()
	if schema_tabs_node != null:
		var schema_tab_bar = schema_tabs_node.get_tab_bar()
		schema_tab_bar.set_tab_title(0, tr("MESSAGES_JSON_SCHEMA_FORM_TAB"))
		schema_tab_bar.set_tab_title(1, tr("MESSAGES_JSON_SCHEMA_RAW_TAB"))
	_ensure_schema_form_bound()
	_schema_form_controller.value_changed.connect(_on_schema_form_value_changed)
	_schema_form_controller.validation_updated.connect(_on_schema_form_validation_updated)
	_schema_form_controller.schema_loaded.connect(_on_schema_form_loaded)
	_schema_validate_timer = Timer.new()
	_schema_validate_timer.one_shot = true
	_schema_validate_timer.wait_time = 2.0
	add_child(_schema_validate_timer)
	_schema_validate_timer.connect("timeout", Callable(self, "_on_schema_validate_timeout"))
	_set_schema_validation_idle()
	_update_external_schema_editor_button_state()
	_clear_schema_form_root()
	var schema_hint = _schema_form_hint_label_node()
	if schema_hint != null:
		schema_hint.text = tr("MESSAGES_JSON_SCHEMA_FORM_NO_SCHEMA")

func _on_progress(current_bytes: int, total_bytes: int) -> void:
	var percentage: float = float(current_bytes) / float(total_bytes) * 100
	

func _on_file_loaded(file_name: String, type: String, base64_data: String) -> void:
	# var raw_data: PackedByteArray = Marshalls.base64_to_raw(base64_data)
	base64_to_image($ImageMessageContainer/TextureRect, base64_data)
	$ImageMessageContainer/Base64ImageEdit.text = base64_data

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_message_type_item_selected(index: int) -> void:
	# Change what Container is visible depending on what was selected
	$TextMessageContainer.visible = false
	$ImageMessageContainer.visible = false
	$FunctionMessageContainer.visible = false
	$SchemaMessageContainer.visible = false
	$AudioMessageContainer.visible = false
	$FileMessageContainer.visible = false
	match index:
		0:
			$TextMessageContainer.visible = true
		1:
			$ImageMessageContainer.visible = true
		2:
			$FunctionMessageContainer.visible = true
		3:
			$SchemaMessageContainer.visible = true
		4:
			$AudioMessageContainer.visible = true
		5:
			$FileMessageContainer.visible = true


func _on_file_dialog_file_selected(path: String) -> void:
	# Load the file into the Image and create the base64 string
	var image_path = path
	var image = Image.new()
	image.load(image_path)
	var image_texture = ImageTexture.new()
	image_texture.set_image(image)
	
	get_node("ImageMessageContainer/TextureRect").texture = image_texture
	var bin = FileAccess.get_file_as_bytes(image_path)
	var base_64_data = Marshalls.raw_to_base64(bin)
	var ft_node = _get_fine_tune_node()
	var settings = {}
	if ft_node != null:
		settings = ft_node.SETTINGS
	var upload_url = settings.get("imageUploadServerURL", "")
	var upload_key = settings.get("imageUploadServerKey", "")
	var upload_enabled = settings.get("imageUploadSetting", 0)
	last_base64_to_upload = base_64_data
	if upload_enabled == 1 and upload_url != "" and upload_key != "":
		var http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(self._on_image_upload_request_completed.bind(http))
		var headers := PackedStringArray()
		headers.append("Content-Type: application/json")
		var ext = "jpg"
		if image_path.to_lower().ends_with(".png"):
			ext = "png"
		var payload = {"key": upload_key, "image": base_64_data, "ext": ext}
		var err = http.request(upload_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
		if err != OK:
			$ImageMessageContainer/Base64ImageEdit.text = base_64_data
		return
	$ImageMessageContainer/Base64ImageEdit.text = base_64_data

func _on_image_upload_request_completed(result, response_code, headers, body, request):
	request.queue_free()
	if response_code == 200:
		var url = body.get_string_from_utf8().strip_edges()
		$ImageMessageContainer/Base64ImageEdit.text = url
		load_image_container_from_url(url)
	else:
		$ImageMessageContainer/Base64ImageEdit.text = last_base64_to_upload
		base64_to_image($ImageMessageContainer/TextureRect, last_base64_to_upload)

func base64_to_image(textureRectNode, b64Data):
	var img = Image.new()
	img.load_jpg_from_buffer(
		Marshalls.base64_to_raw(b64Data)
	)
	textureRectNode.texture = ImageTexture.create_from_image(img)

func get_ext_from_base64(b64:String) -> String:
	var raw = Marshalls.base64_to_raw(b64)
	if raw.size() >= 3 and raw[0] == 0xFF and raw[1] == 0xD8 and raw[2] == 0xFF:
		return "jpg"
	if raw.size() >= 8 and raw[0] == 0x89 and raw[1] == 0x50 and raw[2] == 0x4E and raw[3] == 0x47:
		return "png"
	return "jpg"

func maybe_upload_base64_image():
	var img_data = $ImageMessageContainer/Base64ImageEdit.text
	if img_data == "" or isImageURL(img_data) or img_data.begins_with("http://") or img_data.begins_with("https://"):
		return
	var ft_node = _get_fine_tune_node()
	var settings = {}
	if ft_node != null:
		settings = ft_node.SETTINGS
	var upload_url = settings.get("imageUploadServerURL", "")
	var upload_key = settings.get("imageUploadServerKey", "")
	var upload_enabled = settings.get("imageUploadSetting", 0)
	if upload_enabled == 1 and upload_url != "" and upload_key != "":
		last_base64_to_upload = img_data
		var http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(self._on_image_upload_request_completed.bind(http))
		var headers := PackedStringArray()
		headers.append("Content-Type: application/json")
		var ext = get_ext_from_base64(img_data)
		var payload = {"key": upload_key, "image": img_data, "ext": ext}
		var err = http.request(upload_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
		if err != OK:
				$ImageMessageContainer/Base64ImageEdit.text = img_data
	
func _on_load_image_button_pressed() -> void:
	match OS.get_name():
		"Web":
			if image_access_web == null:
				image_access_web = FileAccessWeb.new()
				if image_access_web != null:
					image_access_web.loaded.connect(_on_file_loaded)
					image_access_web.progress.connect(_on_progress)
			image_access_web.open(".png, .jpg, .jpeg")
		_:
			$ImageMessageContainer/FileDialog.visible = true


func _on_delete_button_pressed() -> void:
	queue_free()


func _on_add_result_button_pressed() -> void:
	var newResultParameter = RESULT_PARAMETERS_SCENE.instantiate()
	$FunctionMessageContainer.add_child(newResultParameter)
	var addResultButton = $FunctionMessageContainer/AddResultButton
	$FunctionMessageContainer.move_child(addResultButton, -1)



func _on_role_item_selected(index: int) -> void:
	# Change what message types are enabled depending on what role was selected
	$MessageSettingsContainer/MessageType.set_item_disabled(0, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(1, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(2, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(3, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(4, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(5, true)
	$MessageSettingsContainer/MessageType.set_item_tooltip(0, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(1, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(2, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(3, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(4, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(5, "")
	var ft_node = _get_fine_tune_node()
	var settings = {}
	if ft_node != null:
		settings = ft_node.SETTINGS
	var finetunetype = settings.get("finetuneType", 0)
	match finetunetype:
		0, 2:
			match index:
				0:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(4, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(5, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
				1:
					$MessageSettingsContainer/MessageType.set_item_disabled(1, false)
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_disabled(4, false)
					$MessageSettingsContainer/MessageType.set_item_disabled(5, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_ONLY_ASSISTANT_CAN_USE_FUNCTIONS"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_ONLY_ASSISTANT_CAN_RESPOND_IN_SCHEMA"))
				2:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_ASSISTANT_CANT_SEND_IMAGES"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(4, tr("DISABLED_EXPLANATION_ASSISTANT_CANT_SEND_AUDIO"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(5, tr("DISABLED_EXPLANATION_ASSISTANT_CANT_SEND_PDF"))
					# Only make functions available if there are any
					if ft_node != null and len(ft_node.get_available_function_names()) > 0:
						$MessageSettingsContainer/MessageType.set_item_disabled(2, false)
					else:
						$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NEEDS_AT_LEAST_ONE_FUNCTION"))
					# JSON schema messages are always available
					$MessageSettingsContainer/MessageType.set_item_disabled(3, false)
		1:
			# In DPO, there is only text messages
			$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
			$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
			$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
			$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
			
func _on_function_name_choice_button_item_selected(index: int) -> void:
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		check_if_function_button_should_be_visible_or_disabled()
		print("-------------------")
		return
	# Die parameter abrufen, die es für diese Funktion gibt
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var pn = ft_node.get_available_parameter_names_for_function(my_function_name)
	print("Parameter names for that selected function:")
	print(pn)
	# Alle Parameter Dinger löschen
	for parameter in $FunctionMessageContainer.get_children():
		if parameter.is_in_group("function_use_parameter"):
			parameter.queue_free()
	# den Index des Parameter-Labels finden
	var pix = $FunctionMessageContainer/ParamterSectionLabel.get_index()
	for p in pn:
		var my_parameter_def = ft_node.get_parameter_def(my_function_name, p)
		print("Adding " + p)
		var newScene = FUNCTION_USE_PARAMETERS_SCENE.instantiate()
		$FunctionMessageContainer.add_child(newScene)
		newScene.get_node("ParameterName").text = p
		$FunctionMessageContainer.move_child(newScene, pix + 1)
		# Falls der Paramter required ist, checkbox auf ja setzen und disablen
		if ft_node.is_function_parameter_required($FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected), p):
			print("Parameter required, disabling....")
			newScene.get_node("FunctionUseParameterIsUsedCheckbox").button_pressed = true
			newScene.get_node("FunctionUseParameterIsUsedCheckbox").disabled = true
		# Dinge die wir tun müssen je nachdem ob es ein String oder eine Number ist
		print("Parameter Typ:")
		print(my_parameter_def["type"])
		if my_parameter_def["type"] == "Number":
			newScene.get_node("FunctionUseParameterEdit").visible = false
			newScene.get_node("FunctionUseParameterChoice").visible = false
			newScene.get_node("FunctionUseParameterNumberEdit").visible = true
			if my_parameter_def["hasLimits"]:
				newScene.get_node("FunctionUseParameterNumberEdit").min_value = my_parameter_def["minimum"]
				newScene.get_node("FunctionUseParameterNumberEdit").max_value = my_parameter_def["maximum"]
			else:
				newScene.get_node("FunctionUseParameterNumberEdit").min_value = -99999
				newScene.get_node("FunctionUseParameterNumberEdit").max_value = 99999
		if my_parameter_def["type"] == "String":
			newScene.get_node("FunctionUseParameterEdit").visible = true
			newScene.get_node("FunctionUseParameterChoice").visible = true
			newScene.get_node("FunctionUseParameterNumberEdit").visible = false
			# Falls der Paramter eine Enumeration ist, die auswahlbox füllen und aktivieren, wenn nicht, die TextEdit aktivieren
			## Zuerst beide deaktivieren
			newScene.get_node("FunctionUseParameterEdit").visible = false
			newScene.get_node("FunctionUseParameterChoice").visible = false
			if ft_node.is_function_parameter_enum(my_function_name, p):
				newScene.get_node("FunctionUseParameterChoice").visible = true
				newScene.get_node("FunctionUseParameterChoice").clear()
				for pv in ft_node.get_function_parameter_enums(my_function_name, p):
					newScene.get_node("FunctionUseParameterChoice").add_item(pv)
			else:
				newScene.get_node("FunctionUseParameterEdit").visible = true
	check_if_function_button_should_be_visible_or_disabled()
	print("-------------------")

func _schema_validation_row_node():
	return $SchemaMessageContainer/HBoxContainer

func _schema_validation_error_container_node():
	return $SchemaMessageContainer/SchemaValidationErrorsContainer

func _clear_schema_validation_error_rows() -> void:
	var container = _schema_validation_error_container_node()
	for child in container.get_children():
		child.queue_free()

func _set_schema_validation_idle() -> void:
	var row = _schema_validation_row_node()
	var error_container = _schema_validation_error_container_node()
	row.get_node("Spinner").visible = false
	row.get_node("SchemaValidationTextureRect").visible = false
	_clear_schema_validation_error_rows()
	error_container.visible = false

func _set_schema_validation_pending() -> void:
	var row = _schema_validation_row_node()
	var error_container = _schema_validation_error_container_node()
	row.get_node("Spinner").visible = true
	row.get_node("SchemaValidationTextureRect").visible = false
	_clear_schema_validation_error_rows()
	error_container.visible = false

func _set_schema_validation_result(ok: bool, msg: String = "") -> void:
	var row = _schema_validation_row_node()
	var error_container = _schema_validation_error_container_node()
	row.get_node("Spinner").visible = false
	row.get_node("SchemaValidationTextureRect").visible = true
	if ok:
		row.get_node("SchemaValidationTextureRect").texture = load(VALID_ICON_OK)
		_clear_schema_validation_error_rows()
		error_container.visible = false
	else:
		row.get_node("SchemaValidationTextureRect").texture = load(VALID_ICON_BAD)
		_render_schema_validation_errors(msg)

func _render_schema_validation_errors(msg: String) -> void:
	var container = _schema_validation_error_container_node()
	_clear_schema_validation_error_rows()
	var entries = _parse_schema_validation_errors(msg)
	for i in range(entries.size()):
		var entry = entries[i]
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)
		var message_label = Label.new()
		message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		message_label.autowrap_mode = 0
		message_label.add_theme_font_size_override("font_size", 15)
		message_label.text = str(entry.get("message", tr("MESSAGES_JSON_SCHEMA_ERROR_UNKNOWN")))
		row.add_child(message_label)
		var path_label = Label.new()
		path_label.autowrap_mode = 0
		path_label.horizontal_alignment = 2
		path_label.add_theme_font_size_override("font_size", 11)
		path_label.text = tr("MESSAGES_JSON_SCHEMA_ERROR_PATH").replace("{path}", str(entry.get("path", "/")))
		row.add_child(path_label)
		if i < entries.size() - 1:
			var separator = HSeparator.new()
			separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(separator)
	container.visible = true

func _parse_schema_validation_errors(msg: String) -> Array:
	var entries = []
	var normalized = msg.strip_edges()
	if normalized == "":
		entries.append(_make_schema_validation_error_entry("/", tr("MESSAGES_JSON_SCHEMA_ERROR_UNKNOWN")))
		return entries
	var parsed = JSON.parse_string(normalized)
	if parsed is Array:
		_append_schema_validation_error_entries_from_array(entries, parsed)
	elif parsed is Dictionary:
		if parsed.has("errors") and parsed["errors"] is Array:
			_append_schema_validation_error_entries_from_array(entries, parsed["errors"])
		elif parsed.has("message"):
			_append_schema_validation_error_entry(entries, str(parsed.get("path", "/")), str(parsed.get("message", "")))
		else:
			_append_schema_validation_error_entry(entries, "/", normalized)
	else:
		_append_schema_validation_error_entry(entries, "/", normalized)
	if entries.is_empty():
		entries.append(_make_schema_validation_error_entry("/", tr("MESSAGES_JSON_SCHEMA_ERROR_UNKNOWN")))
	return entries

func _append_schema_validation_error_entries_from_array(output: Array, entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary:
			if entry.has("errors") and entry["errors"] is Array:
				_append_schema_validation_error_entries_from_array(output, entry["errors"])
			else:
				_append_schema_validation_error_entry(output, str(entry.get("path", "/")), str(entry.get("message", "")))
		else:
			_append_schema_validation_error_entry(output, "/", str(entry))

func _append_schema_validation_error_entry(output: Array, path: String, message: String) -> void:
	var normalized_path = path.strip_edges()
	if normalized_path == "":
		normalized_path = "/"
	if not normalized_path.begins_with("/"):
		normalized_path = "/" + normalized_path
	var translated_message = _translate_schema_error_message(message)
	if translated_message.strip_edges() == "":
		translated_message = tr("MESSAGES_JSON_SCHEMA_ERROR_UNKNOWN")
	output.append(_make_schema_validation_error_entry(normalized_path, translated_message))

func _make_schema_validation_error_entry(path: String, message: String) -> Dictionary:
	return {
		"path": path,
		"message": message
	}

func _translate_schema_error_message(message: String) -> String:
	var normalized = message.strip_edges()
	match normalized:
		"Schema editor missing":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_SCHEMA_EDITOR_MISSING")
		"Invalid JSON":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_INVALID_JSON")
		"No schema":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NO_SCHEMA")
		"exactly one oneOf branch must match":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_ONE_OF_EXACTLY_ONE")
		"no anyOf branch matched":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_ANY_OF_NONE")
		"type mismatch":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_TYPE_MISMATCH")
		"expected object", "Expected object":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_OBJECT")
		"expected array", "Expected array":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_ARRAY")
		"expected string", "Expected string":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_STRING")
		"expected number", "Expected number":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_NUMBER")
		"expected integer", "Expected integer":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_INTEGER")
		"expected boolean", "Expected boolean":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_EXPECTED_BOOLEAN")
		"additional property":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_ADDITIONAL_PROPERTY")
		"Additional property not allowed":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_ADDITIONAL_PROPERTY_NOT_ALLOWED")
		"missing property":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_MISSING_PROPERTY")
		"Missing required property":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_MISSING_REQUIRED_PROPERTY")
		"too few items":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_TOO_FEW_ITEMS")
		"too many items":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_TOO_MANY_ITEMS")
		"Too few array items":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_TOO_FEW_ARRAY_ITEMS")
		"Too many array items":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_TOO_MANY_ARRAY_ITEMS")
		"duplicate item":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_DUPLICATE_ITEM")
		"value not in enum", "Value not in enum":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_VALUE_NOT_IN_ENUM")
		"value does not match const", "Value does not match const":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_CONST_MISMATCH")
		"number below minimum":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NUMBER_BELOW_MINIMUM")
		"number above maximum":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NUMBER_ABOVE_MAXIMUM")
		"number below or equal exclusiveMinimum":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NUMBER_BELOW_OR_EQUAL_EXCLUSIVE_MINIMUM")
		"number above or equal exclusiveMaximum":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NUMBER_ABOVE_OR_EQUAL_EXCLUSIVE_MAXIMUM")
		"number not multipleOf":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NUMBER_NOT_MULTIPLE_OF")
		"string shorter than minLength":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_STRING_MIN_LENGTH")
		"string longer than maxLength":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_STRING_MAX_LENGTH")
		"invalid pattern":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_INVALID_PATTERN")
		"string does not match pattern":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_STRING_PATTERN_MISMATCH")
		"No union branch matches value":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NO_UNION_BRANCH")
		"Value must not be null":
			return tr("MESSAGES_JSON_SCHEMA_ERROR_NULL_NOT_ALLOWED")
	if normalized.begins_with("string does not match format "):
		var prefix = "string does not match format "
		var format_name = normalized.substr(prefix.length())
		return tr("MESSAGES_JSON_SCHEMA_ERROR_STRING_FORMAT_MISMATCH").replace("{format}", format_name)
	return normalized

func _clear_schema_form_root() -> void:
	var form_root = _schema_form_root_node()
	if form_root == null:
		return
	for child in form_root.get_children():
		child.queue_free()

func _is_only_json_option_text(option_text: String) -> bool:
	var normalized = option_text.strip_edges()
	if normalized == "":
		return true
	if normalized == "Only JSON":
		return true
	if normalized == "ONLY_JSON_NO_SCHEMA":
		return true
	if normalized == tr("ONLY_JSON_NO_SCHEMA"):
		return true
	return false

func _is_only_json_selection(option: OptionButton) -> bool:
	if option == null:
		return true
	if option.selected < 0 or option.selected >= option.item_count:
		return true
	return _is_only_json_option_text(option.get_item_text(option.selected))

func _get_selected_schema_data():
	var option = $SchemaMessageContainer/HBoxContainer/OptionButton
	if option.selected < 0 or option.selected >= option.item_count:
		return null
	var selected_text = option.get_item_text(option.selected)
	if _is_only_json_option_text(selected_text):
		return null
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return null
	var schema_name = selected_text
	for schema_entry in ft_node.SCHEMAS:
		if schema_entry.get("name", "") == schema_name:
			return schema_entry
	return null

func _update_external_schema_editor_button_state() -> void:
	var schema_button = $SchemaMessageContainer/HBoxContainer/SchemaEditButtonsContainer/SchemaEditButton
	var editor_url = ""
	var ft_node = _get_fine_tune_node()
	if ft_node != null:
		editor_url = str(ft_node.SETTINGS.get("schemaEditorURL", "")).strip_edges()
	if editor_url == "":
		schema_button.disabled = true
		schema_button.tooltip_text = tr("MESSAGES_JSON_SCHEMA_EXTERNAL_EDITOR_DISABLED")
	else:
		schema_button.disabled = false
		schema_button.tooltip_text = tr("MESSAGES_JSON_SCHEMA_EXTERNAL_EDITOR_ENABLED")

func _rebuild_schema_form_from_selection(sync_raw_from_form: bool = true) -> void:
	_ensure_schema_form_bound()
	var schema_hint = _schema_form_hint_label_node()
	var schema_edit_node = _schema_edit_node()
	var option = $SchemaMessageContainer/HBoxContainer/OptionButton
	var selected_schema_name = ""
	if option.selected >= 0 and option.selected < option.item_count:
		selected_schema_name = option.get_item_text(option.selected)
	var schema_data = _get_selected_schema_data()
	if schema_data == null:
		_schema_last_selected_name = ""
		_clear_schema_form_root()
		if schema_hint != null:
			schema_hint.text = tr("MESSAGES_JSON_SCHEMA_FORM_NO_SCHEMA")
		return
	var selected_schema = schema_data.get("schema", null)
	if not (selected_schema is Dictionary):
		selected_schema = schema_data.get("sanitizedSchema", null)
	if not (selected_schema is Dictionary):
		_schema_last_selected_name = ""
		_clear_schema_form_root()
		if schema_hint != null:
			schema_hint.text = tr("MESSAGES_JSON_SCHEMA_FORM_NO_SCHEMA")
		return
	if schema_hint != null:
		schema_hint.text = ""
	_schema_form_controller.load_schema(selected_schema)
	var schema_changed = selected_schema_name != _schema_last_selected_name
	_schema_last_selected_name = selected_schema_name
	var apply_result = {}
	if sync_raw_from_form and schema_changed:
		apply_result = _schema_form_controller.set_value_from_json("")
	else:
		var source_json = "{}"
		if schema_edit_node != null:
			source_json = schema_edit_node.text
		apply_result = _schema_form_controller.set_value_from_json(source_json)
	if sync_raw_from_form and (schema_changed or not bool(apply_result.get("ok", false))):
		if schema_edit_node != null:
			_schema_sync_guard = true
			schema_edit_node.text = _schema_form_controller.get_value_as_json(true)
			_schema_sync_guard = false
	update_messages_global()

func _on_schema_form_loaded(has_fallback: bool) -> void:
	if has_fallback:
		var schema_hint = _schema_form_hint_label_node()
		if schema_hint != null:
			schema_hint.text = tr("MESSAGES_JSON_SCHEMA_FORM_PARTIAL_FALLBACK")

func _on_schema_form_value_changed(json_text: String) -> void:
	if _schema_sync_guard:
		return
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node != null:
		_schema_sync_guard = true
		schema_edit_node.text = json_text
		_schema_sync_guard = false
	update_messages_global()
	_schedule_schema_validate()

func _on_schema_form_validation_updated(_errors: Array) -> void:
	_schedule_schema_validate()

func _validate_schema_message() -> void:
	var option = $SchemaMessageContainer/HBoxContainer/OptionButton
	if option.selected == -1:
		_set_schema_validation_idle()
		return
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node == null:
		_set_schema_validation_result(false, "Schema editor missing")
		return
	var json = JSON.new()
	var err = json.parse(schema_edit_node.text)
	if err != OK:
		_set_schema_validation_result(false, "Invalid JSON")
		return
	if _is_only_json_selection(option):
		_set_schema_validation_result(true)
		return
	var local_form_errors = _schema_form_controller.get_errors()
	if local_form_errors.size() > 0:
		_set_schema_validation_result(false, JSON.stringify(local_form_errors))
		return
	var schema_data = _get_selected_schema_data()
	if schema_data == null:
		_set_schema_validation_result(false, "No schema")
		return
	var selected_schema = schema_data.get("schema", null)
	if not (selected_schema is Dictionary):
		selected_schema = schema_data.get("sanitizedSchema", null)
	if not (selected_schema is Dictionary):
		_set_schema_validation_result(false, "No schema")
		return
	_set_schema_validation_pending()
	var res = JsonSchemaValidator.validate(json.data, selected_schema)
	if res["ok"]:
		_set_schema_validation_result(true)
	else:
		_set_schema_validation_result(false, JSON.stringify(res["errors"]))

func _on_schema_edit_text_changed() -> void:
	if _schema_sync_guard:
		return
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node == null:
		return
	update_messages_global()
	if _get_selected_schema_data() != null:
		var json = JSON.new()
		if json.parse(schema_edit_node.text) == OK:
			_schema_form_controller.set_value_from_json(schema_edit_node.text)
	_schedule_schema_validate()

func _on_schema_option_selected(_index: int) -> void:
	_rebuild_schema_form_from_selection(true)
	_schedule_schema_validate()

func _schedule_schema_validate() -> void:
	_schema_validate_timer.start()

func _on_schema_validate_timeout() -> void:
	_validate_schema_message()
## Funktionen, die den nachrichtenverlauf speichern wenn etwas passiert

func update_messages_global():
	var ft_node = _get_fine_tune_node()
	if ft_node != null:
		ft_node.save_current_conversation()
# Jetzt die Events

func _on_something_int_changed(index: int) -> void:
	update_messages_global()
	_on_check_what_text_message_should_be_visisble()
	
func _on_something_string_changed(new_text: String) -> void:
	update_messages_global()


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				$ImageMessageContainer/TextureRect.custom_minimum_size.y = 900
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				$ImageMessageContainer/TextureRect.custom_minimum_size.y = 0

func _on_check_what_text_message_should_be_visisble() -> void:
	var finetunetype = 0
	var ft_node = _get_fine_tune_node()
	if ft_node != null:
		finetunetype = ft_node.SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		if $MessageSettingsContainer/Role.selected == 2:
			$TextMessageContainer/Message.visible = false
			$TextMessageContainer/DPOMessagesContainer.visible = true
			return
	$TextMessageContainer/Message.visible = true
	$TextMessageContainer/DPOMessagesContainer.visible = false

func _on_delete_button_mouse_entered() -> void:
	$MessageSettingsContainer/DeleteButton.icon = load("res://icons/trashcanOpen.png")


func _on_delete_button_mouse_exited() -> void:
	$MessageSettingsContainer/DeleteButton.icon = load("res://icons/trashcan.png")


func _on_load_image_url_button_pressed() -> void:
	load_image_container_from_url($ImageMessageContainer/Base64ImageEdit.text)
	
func load_image_container_from_url(url):
	if not is_inside_tree():
		return
	$ImageMessageContainer/TextureRect.texture = load("res://icons/image-sync-custom.png")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._image_http_request_completed)
	
	var urlToBeLoadedFrom = url
	if not isImageURL(urlToBeLoadedFrom):
		print("Not a image url to load...")
		$ImageMessageContainer/TextureRect.texture = load("res://icons/image-remove-custom.png")
		return
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(urlToBeLoadedFrom)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		$ImageMessageContainer/TextureRect.texture = load("res://icons/image-remove-custom.png")

# Called when the HTTP request is completed.
func _image_http_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		$ImageMessageContainer/TextureRect.texture = load("res://icons/image-remove-custom.png")
		push_error("Image couldn't be downloaded. Try a different image.")

	var image = Image.new()
	var imageType = getImageType($ImageMessageContainer/Base64ImageEdit.text)
	var error = false
	if imageType == "jpg":
		error = image.load_jpg_from_buffer(body)
	elif imageType == "png":
		error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		$ImageMessageContainer/TextureRect.texture = load("res://icons/image-remove-custom.png")


	var texture = ImageTexture.create_from_image(image)
	$ImageMessageContainer/TextureRect.texture = texture
	

func isImageURL(url: String) -> bool:
	# Return false if the URL is empty or only whitespace.
	if url.strip_edges() == "":
		return false

	# Define valid URL schemes. Adjust this list if you need to allow other schemes.
	var valid_schemes = ["http://", "https://"]

	# Convert the URL to lowercase for case-insensitive comparisons.
	var lower_url = url.to_lower()

	# Check if the URL begins with one of the valid schemes.
	var scheme_valid = false
	for scheme in valid_schemes:
		if lower_url.begins_with(scheme):
			scheme_valid = true
			break
	if not scheme_valid:
		return false

	# Remove fragment identifiers for easier handling.
	var no_fragment = lower_url.split("#")[0]

	# Check path part first (before query string).
	var path_part = no_fragment.split("?")[0]
	if path_part.ends_with(".jpg") or path_part.ends_with(".jpeg") or path_part.ends_with(".png"):
		return true

	# Check query parameters for an 'image' parameter with a jpg/jpeg extension.
	var query_index := no_fragment.find("?")
	if query_index != -1:
		var query = no_fragment.substr(query_index + 1)
		var params = query.split("&")
		for param in params:
			var kv = param.split("=")
			if kv.size() == 2 and kv[0] == "image":
				var value = kv[1]
				if value.ends_with(".jpg") or value.ends_with(".jpeg") or value.ends_with(".png"):
					return true

	return false
# This function uses the above isImageURL() to check if the URL is valid,
# and if so, returns "jpg" for URLs ending with .jpg or .jpeg.
# Otherwise, it returns an empty string.
func getImageType(url: String) -> String:
	# Use our helper function to ensure the URL is valid.
	if not isImageURL(url):
		return ""

	var lower_url = url.to_lower()
	var no_fragment = lower_url.split("#")[0]
	var path_part = no_fragment.split("?")[0]

	if path_part.ends_with(".png"):
		return "png"
	if path_part.ends_with(".jpg") or path_part.ends_with(".jpeg"):
		return "jpg"

	var query_index := no_fragment.find("?")
	if query_index != -1:
		var query = no_fragment.substr(query_index + 1)
		var params = query.split("&")
		for param in params:
			var kv = param.split("=")
			if kv.size() == 2 and kv[0] == "image":
				var value = kv[1]
				if value.ends_with(".png"):
					return "png"
				if value.ends_with(".jpg") or value.ends_with(".jpeg"):
					return "jpg"

	return ""


func _on_schema_edit_button_pressed() -> void:
	# POST the Schema and The Data we already have to the editor URL to retrieve a token
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return
	var editor_url = str(ft_node.SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")).strip_edges()
	if editor_url == "":
		return
	var schema_name = ""
	if $SchemaMessageContainer/HBoxContainer/OptionButton.selected != -1:
		schema_name = $SchemaMessageContainer/HBoxContainer/OptionButton.get_item_text($SchemaMessageContainer/HBoxContainer/OptionButton.selected)
	var schema_dict = ft_node.get_schema_by_name(schema_name)
	var json_schema_string = ""
	if schema_dict != null:
		json_schema_string = JSON.stringify(schema_dict)
	var existing_json_data = "{}"
	var schema_edit_node = _schema_edit_node()
	if schema_edit_node != null:
		existing_json_data = schema_edit_node.text
	var data_to_send = {"json_data": existing_json_data, "json_schema": json_schema_string}
	print("Sending data:")
	print(data_to_send)
	var json_to_send = JSON.stringify(data_to_send)
	var custom_headers = PackedStringArray()
	custom_headers.append("Content-Type: application/json")
	print("json_to_send")
	print(json_to_send)
	$SchemaMessageContainer/InitEditingRequestToken.request(editor_url, custom_headers, HTTPClient.METHOD_POST, json_to_send)
	print("Requested!")

func _on_init_editing_request_token_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print(result)
	print(response_code)
	print(headers)
	print(body)
	if response_code == 200:
		token = body.get_string_from_utf8()
		print(token)
		if token == "":
			print("Kein Token, versuche es nochmal")
			_on_schema_edit_button_pressed()
			return
		var editor_url = "https://www.haukauntrie.de/online/api/schema-editor/"
		var ft_node = _get_fine_tune_node()
		if ft_node != null:
			editor_url = ft_node.SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")
		edit_message_url = editor_url + "?token=" + token
		OS.shell_open(edit_message_url)
		$SchemaMessageContainer/SchemaMessagePolling/SchemaMessagePollingOpenBrowserLink.uri = edit_message_url
		$SchemaMessageContainer/PollingTimer.start()
		$SchemaMessageContainer/SchemaMessagePolling.visible = true
		# Make the Desktop "Reopen Browser" button and the Web-Export "Open Browser" Link invisible and make visible what needs to be depending on platform
		$SchemaMessageContainer/SchemaMessagePolling/SchemaMessagePollingReopenBrowserBtn.visible = false
		$SchemaMessageContainer/SchemaMessagePolling/SchemaMessagePollingOpenBrowserLink.visible = false
		if OS.get_name() != "Web":
			$SchemaMessageContainer/SchemaMessagePolling/SchemaMessagePollingReopenBrowserBtn.visible = true
		else:
			$SchemaMessageContainer/SchemaMessagePolling/SchemaMessagePollingOpenBrowserLink.visible = true
		$SchemaMessageContainer/SchemaEditTabs.visible = false
		$SchemaMessageContainer/HBoxContainer/SchemaEditButtonsContainer.visible = false
	else:
		print("Es kam kein 200 zurueck")

func _on_polling_timer_timeout() -> void:
	var editor_url = "https://www.haukauntrie.de/online/api/schema-editor/"
	var ft_node = _get_fine_tune_node()
	if ft_node != null:
		editor_url = ft_node.SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")
	# Start a HTTP Request to Poll for completion of the edit from users side
	$SchemaMessageContainer/PollForCompletion.request(editor_url + "?poll=1&token=" + token, [], HTTPClient.METHOD_GET, "")

func _on_poll_for_completion_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json_data = JSON.parse_string(body.get_string_from_utf8())
		if json_data["ready"] == false:
			return
		elif json_data["ready"] == true:
			var schema_edit_node = _schema_edit_node()
			if schema_edit_node != null:
				_schema_sync_guard = true
				schema_edit_node.text = json_data["json_data"]
				_schema_sync_guard = false
			$SchemaMessageContainer/PollingTimer.stop()
			$SchemaMessageContainer/SchemaMessagePolling.visible = false
			$SchemaMessageContainer/SchemaEditTabs.visible = true
			$SchemaMessageContainer/HBoxContainer/SchemaEditButtonsContainer.visible = true
			_rebuild_schema_form_from_selection(true)
			update_messages_global()
			_validate_schema_message()


func _on_schema_message_polling_reopen_browser_btn_pressed() -> void:
	OS.shell_open(edit_message_url)

## Function Execution
func get_current_function_parameter_names():
	# returns a list of names of the parameters of the function currently chosen
	var function_button = $FunctionMessageContainer/function/FunctionNameChoiceButton
	if function_button.selected < 0:
		return []
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return []
	var my_function_name = function_button.get_item_text(function_button.selected)
	return ft_node.get_available_parameter_names_for_function(my_function_name)

func get_current_value_for_function_parameter_name(parametername):
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var fdefdict = get_function_defintion_dict(my_function_name)
	if not fdefdict.has("parameters"):
		return ""
	var thisparameterdict = {}
	for parameter in $FunctionMessageContainer.get_children():
		if parameter.is_in_group("function_use_parameter"):
			thisparameterdict = parameter.to_var()
			if thisparameterdict["name"] == parametername:
				break
	var thisparameterdefdict = {}
	for parameter in fdefdict["parameters"]:
		if parameter["name"] == parametername:
			thisparameterdefdict = parameter
	# First, check string:
	if thisparameterdefdict["type"] == "String" and thisparameterdefdict["isEnum"] == false:
		return thisparameterdict["parameterValueText"]
	# Then, check string choice
	if thisparameterdefdict["type"] == "String" and thisparameterdefdict["isEnum"] == true:
		return thisparameterdict["parameterValueChoice"]
	# If its none, retun the number (problem: We cannot check the existence of the number in any meaningful way, because it is 0.0
	if thisparameterdefdict["type"] == "Number":
		return thisparameterdict["parameterValueNumber"]
	return tr("UNEXPECTED_PARAMETER_ERROR_PLEASE_REPORT_THIS")

func get_function_defintion_dict(fname):
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return {}
	var allfunctiondefs = ft_node.FUNCTIONS
	for fdef in allfunctiondefs:
		if fdef["name"] == fname:
			return fdef
	return {}

func _on_function_execution_button_pressed() -> void:
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var fdefdict = get_function_defintion_dict(my_function_name)
	if fdefdict.is_empty():
		return
	var output = []
	var executable_path = fdefdict["functionExecutionExecutable"]
	var parameters_raw_string = fdefdict["functionExecutionArgumentsString"]
	var parameters_replace_vars = parameters_raw_string
	print("Checking parameters")
	for parameterName in get_current_function_parameter_names():
		parameters_replace_vars = parameters_replace_vars.replace("%" + str(parameterName) + "%", get_current_value_for_function_parameter_name(parameterName))
	var argumentslist = []
	for parameter in parameters_replace_vars.split("<|>"):
		argumentslist.append(parameter)
	var exit_code = OS.execute(executable_path, argumentslist, output)
	var outputstring = output[0]
	$FunctionMessageContainer/FunctionUseResultText.text = outputstring

func check_if_function_button_should_be_visible_or_disabled():
	if not $FunctionMessageContainer.visible:
		return
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	print("Check if execution should be...")
	print(my_function_name)
	if my_function_name == "":
		$FunctionMessageContainer/FunctionExecutionButton.visible = false
		$FunctionMessageContainer/FunctionExecutionButton.disabled = true
		return
	var fdefdict = get_function_defintion_dict(my_function_name)
	if fdefdict.is_empty():
		$FunctionMessageContainer/FunctionExecutionButton.visible = false
		$FunctionMessageContainer/FunctionExecutionButton.disabled = true
		return
	if fdefdict["functionExecutionEnabled"]:
		$FunctionMessageContainer/FunctionExecutionButton.visible = true
	else:
		$FunctionMessageContainer/FunctionExecutionButton.visible = false
		return
	# Now, check if the button should be visible, yes, but should it be disabled because something is wrong?
	if fdefdict["functionExecutionExecutable"] == "":
		$FunctionMessageContainer/FunctionExecutionButton.disabled = true
		$FunctionMessageContainer/FunctionExecutionButton.tooltip_text = tr("DISABLED_EXPLANATION_NO_EXECUTABLE_DEFINED")
		return
	# Check that none of the parameters are empty
	for parameterName in get_current_function_parameter_names():
		print("Checking parameter values set for")
		print("Parameter Name")
		print(parameterName)
		print("Value:")
		print(get_current_value_for_function_parameter_name(parameterName))
		if str(get_current_value_for_function_parameter_name(parameterName)) == "":
			$FunctionMessageContainer/FunctionExecutionButton.disabled = true
			$FunctionMessageContainer/FunctionExecutionButton.tooltip_text = tr("DISABLED_EXPLANATION_ALL_PARAMETER_VALUES_MUST_BE_SET")
			return
	if OS.get_name() == "Web":
		$FunctionMessageContainer/FunctionExecutionButton.disabled = true
		$FunctionMessageContainer/FunctionExecutionButton.tooltip_text = tr("DISABLED_EXPLANATION_NOT_AVAILABLE_IN_WEB")
		return
	$FunctionMessageContainer/FunctionExecutionButton.visible = true
	$FunctionMessageContainer/FunctionExecutionButton.disabled = false
	# No check for the argument string, it is technically not nessecary
	

func _on_function_message_container_mouse_entered() -> void:
	check_if_function_button_should_be_visible_or_disabled()

func update_token_costs(conversation_token_counts):
	if conversation_token_counts == {}:
		return
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return
	var cost_json = FileAccess.get_file_as_string("res://assets/openai_costs.json").strip_edges()
	#print(cost_json)
	var costs = JSON.parse_string(cost_json)
	var my_convo_ix = ft_node.CURRENT_EDITED_CONVO_IX
	if not conversation_token_counts.has(my_convo_ix):
		return
	var tokens_this_conversation = conversation_token_counts[my_convo_ix]
	var tokens_all_conversations = {"total": 0, "input": 0, "output": 0}
	for convoIx in conversation_token_counts:
		tokens_all_conversations["total"] += conversation_token_counts[convoIx]["total"]
		tokens_all_conversations["input"] += conversation_token_counts[convoIx]["input"]
		tokens_all_conversations["output"] += conversation_token_counts[convoIx]["output"]
	# Get the dollar to currency multiplier
	var dollar_to_currency_multiplier = costs.get("dollar_to_currency_muliplier", 1)
	# Get the chosen model for fine-tuning
	var chosen_model_ix = int(ft_node.SETTINGS.get("countTokensModel", 0))
	var chosen_model = costs["available_models"][chosen_model_ix]
	$MetaMessageContainer/InfoLabelsGridContainer/TokenCostEstimationTitleLabel.text = tr("META_MESSAGE_TOKEN_COST_ESTIMATION") + " (" + str(chosen_model) + ")"
	# Training cost (this conversation)
	var training_cost_this_conversation = (tokens_this_conversation["total"] * (costs["training"][chosen_model] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4oThisConversation.text = str(snapped(training_cost_this_conversation, 0.001)) + " €"
	# Training cost (whole fine tune)
	var training_cost_whole_fine_tune = (tokens_all_conversations["total"] * (costs["training"][chosen_model] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4oWholeFineTune.text = str(snapped(training_cost_whole_fine_tune, 0.001)) + " €"
	# Inference cost (this conversation)
	## Inference cost = input tokens * input token price + output tokens * output token price (here and below)
	var inferecence_cost_this_conversation = (tokens_this_conversation["input"] * (costs["inference"][chosen_model]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4oThisConversation.text = str(snapped(inferecence_cost_this_conversation, 0.001)) + " €"
	# Inference cost (whole fine tune)
	var inferecence_cost_whole_fine_tune = (tokens_all_conversations["input"] * (costs["inference"][chosen_model]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4oWholeFineTune.text = str(snapped(inferecence_cost_whole_fine_tune, 0.001)) + " €"
	# batch_inference_cost (this conversation)
	var batch_inference_cost_this_conversation = (tokens_this_conversation["input"] * (costs["batch_inference"][chosen_model]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["batch_inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4oThisConversation.text = str(snapped(batch_inference_cost_this_conversation, 0.001)) + " €"
	# batch_inference_cost (whole fine tune)
	var batch_inference_cost_whole_fine_tune = (tokens_all_conversations["input"] * (costs["batch_inference"][chosen_model]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["batch_inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4oWholeFineTune.text = str(snapped(batch_inference_cost_whole_fine_tune, 0.001)) + " €"
	# Number of images
	$MetaMessageContainer/InfoLabelsGridContainer/NumberOfImagesThisConversation.text = str(ft_node.get_number_of_images_for_conversation(my_convo_ix))
	$MetaMessageContainer/InfoLabelsGridContainer/NumberOfImagesWholeFineTune.text = str(ft_node.get_number_of_images_total())

func _do_token_calculation_update() -> void:
	var output = []
	var ft_node = _get_fine_tune_node()
	if ft_node == null:
		return
	var own_savefile_path = ft_node.RUNTIME["filepath"]
	var token_counter_path = ft_node.SETTINGS.get("tokenCounterPath", "")
	if token_counter_path == "" or own_savefile_path == "":
		return
	var arguments_list = [token_counter_path, own_savefile_path]
	var exit_code = OS.execute("python", arguments_list, output)
	if exit_code != 0:
		push_warning("Token counter failed with exit code %s" % str(exit_code))
		return
	if output.size() == 0:
		push_warning("Token counter returned no output")
		return
	var outputstring = str(output[0]).strip_edges()
	if outputstring == "":
		push_warning("Token counter returned empty output")
		return
	var conversation_token_counts = JSON.parse_string(outputstring)
	if typeof(conversation_token_counts) != TYPE_DICTIONARY:
		push_warning("Token counter returned invalid JSON output")
		return
	var my_convo_ix = ft_node.CURRENT_EDITED_CONVO_IX
	if not conversation_token_counts.has(my_convo_ix):
		push_warning("Token counter result has no data for conversation %s" % str(my_convo_ix))
		return
	$MetaMessageContainer/InfoLabelsGridContainer/ThisConversationTotalTokens.text = str(int(conversation_token_counts[my_convo_ix]["total"]))
	var all_tokens = 0
	for convoKey in conversation_token_counts:
		var convo_data = conversation_token_counts[convoKey]
		if typeof(convo_data) == TYPE_DICTIONARY and convo_data.has("total"):
			all_tokens += int(convo_data["total"])
	$MetaMessageContainer/InfoLabelsGridContainer/WholeFineTuneTotalTokens.text = str(int(all_tokens))
	var token_count_holder = ft_node.get_node_or_null("Conversation/Settings/ConversationSettings/VBoxContainer/TokenCountPathContainer/TokenCountValueHolder")
	if token_count_holder != null:
		token_count_holder.text = str(conversation_token_counts)
	update_token_costs(conversation_token_counts)




func _on_meta_message_toggle_cost_estimation_button_pressed() -> void:
	$MetaMessageContainer/ConversationReadyContainer.visible = not $MetaMessageContainer/ConversationReadyContainer.visible
	$MetaMessageContainer/ConversationNotesEdit.visible = not $MetaMessageContainer/ConversationNotesEdit.visible
	$MetaMessageContainer/ConversationNameContainer.visible = not $MetaMessageContainer/ConversationNameContainer.visible
	$MetaMessageContainer/InfoLabelsGridContainer.visible = not $MetaMessageContainer/InfoLabelsGridContainer.visible
	if $MetaMessageContainer/InfoLabelsGridContainer.visible:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.text = tr("MESSAGE_META_HIDE_META_MESSAGE")
	else:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.text = tr("MESSAGE_META_SHOW_META_MESSAGE")

func _on_show_meta_message_toggle_button_pressed() -> void:
	$MetaMessageContainer/ConversationReadyContainer.visible = not $MetaMessageContainer/ConversationReadyContainer.visible
	$MetaMessageContainer/ConversationNotesEdit.visible = not $MetaMessageContainer/ConversationNotesEdit.visible
	$MetaMessageContainer/ConversationNameContainer.visible = not $MetaMessageContainer/ConversationNameContainer.visible
	$MetaMessageContainer/InfoLabelsGridContainer.visible = not $MetaMessageContainer/InfoLabelsGridContainer.visible
	if $MetaMessageContainer/InfoLabelsGridContainer.visible:
		$MetaMessageContainer/ShowMetaMessageToggleButton.text = tr("MESSAGE_META_HIDE_META_MESSAGE")
	else:
		$MetaMessageContainer/ShowMetaMessageToggleButton.text = tr("MESSAGE_META_SHOW_META_MESSAGE")


func _on_audio_message_load_file_button_pressed() -> void:
	$AudioMessageContainer/AudioLoaderFileDialog.visible = true
	


func _on_audio_loader_file_dialog_file_selected(path: String) -> void:
	# Load the audio into the AudioStramPlayer
	# We need to do things differently depending if we chose an mp3 or wav
	if path.ends_with(".mp3"):
		$AudioMessageContainer/AudioStreamPlayer.stream = AudioStreamMP3.load_from_file(path)
		$AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text = "mp3"
	elif path.ends_with(".wav"):
		$AudioMessageContainer/AudioStreamPlayer.stream = AudioStreamWAV.load_from_file(path)
		$AudioMessageContainer/AudioMediaPlayerContainer/FileTypeLabel.text = "wav"
	else:
		print("Invalid file chosen")
		return
	# Load the file into the base64 representation
	var bin = FileAccess.get_file_as_bytes(path)
	var base_64_data = Marshalls.raw_to_base64(bin)
	$AudioMessageContainer/Base64AudioEdit.text = base_64_data
	



func _on_audio_message_content_play_pause_button_pressed() -> void:
	if $AudioMessageContainer/Base64AudioEdit.text == "":
		return
	if $AudioMessageContainer/AudioStreamPlayer.playing:
		$AudioMessageContainer/AudioMediaPlayerContainer/AudioMessageContentPlayPauseButton.icon = load("res://icons/audio_play.png")
		$AudioMessageContainer/AudioStreamPlayer.stream_paused = true
	else:
		$AudioMessageContainer/AudioStreamPlayer.play()
		$AudioMessageContainer/AudioMediaPlayerContainer/AudioMessageContentPlayPauseButton.icon = load("res://icons/audio_pause.png")
		
func _on_audio_stream_player_finished() -> void:
		$AudioMessageContainer/AudioMediaPlayerContainer/AudioMessageContentPlayPauseButton.icon = load("res://icons/audio_play.png")
		$AudioMessageContainer/AudioMediaPlayerContainer/PlayHeadSlider.value = 0

func getBasePath(path: String) -> String:
	# returns only the file name
	return path.split("/")[len(path.split("/")) - 1]

func _on_file_message_load_file_dialog_file_selected(path: String) -> void:
	if path.ends_with(".pdf"):
		var bin = FileAccess.get_file_as_bytes(path)
		var base_64_data = Marshalls.raw_to_base64(bin)
		$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileDataBase64Edit.text = base_64_data
		$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileNameEdit.text = getBasePath(path)
		$FileMessageContainer/FileSelectorContainer/FileTypeSymbolTextureRect.texture = load("res://icons/file-pdf.png")
	else:
		$FileMessageContainer/FileSelectorContainer/FileTypeSymbolTextureRect.texture = load("res://icons/file-question-small.png")
		$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileDataBase64Edit.text = ""
		$FileMessageContainer/FileSelectorContainer/NameAndContentContainer/FileNameEdit.text = ""

func _on_load_pdf_file_button_pressed() -> void:
	$FileMessageContainer/FileMessageLoadFileDialog.visible = true
func to_openai_message():
	var msg = to_var()
	if msg["type"] == "Text":
		var result = {"role": msg["role"], "content": msg["textContent"]}
		if msg.get("userName", "") != "":
			result["name"] = msg["userName"]
		return result
	elif msg["type"] == "Image":
		var image_content = msg["imageContent"]
		var image_url_data = ""
		if isImageURL(image_content) or image_content.begins_with("http://") or image_content.begins_with("https://"):
			image_url_data = image_content
		else:
			var ext = get_ext_from_base64(image_content)
			image_url_data = "data:image/%s;base64,%s" % [ext, image_content]
		var image_detail_map = {0: "high", 1: "low", 2: "auto"}
		return {
			"role": msg["role"],
			"content": [{
				"type": "image_url",
				"image_url": {
					"url": image_url_data,
					"detail": image_detail_map.get(int(msg.get("imageDetail", 0)), "high")
				}
			}]
		}
	return {}
func from_openai_message(oai_msg: Dictionary):
	var role = oai_msg.get("role", "user")
	var user_name = oai_msg.get("name", "")
	var content = oai_msg.get("content", "")
	var msg_type := ""
	var text_content := ""
	var image_content := ""
	var image_detail_idx := 0
	var image_detail_map = {"high":0, "low":1, "auto":2}
	if typeof(content) == TYPE_STRING:
		msg_type = "Text"
		text_content = content
	elif typeof(content) == TYPE_ARRAY:
		for piece in content:
			if piece is Dictionary:
				if piece.get("type", "") == "text":
					msg_type = "Text"
					text_content += piece.get("text", "")
				elif piece.get("type", "") == "image_url":
					msg_type = "Image"
					image_content = piece["image_url"].get("url", "")
					image_detail_idx = image_detail_map.get(piece["image_url"].get("detail", "high"), 0)
	else:
		return {}
	if msg_type == "Text":
		$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Text"))
		_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
		$TextMessageContainer/Message.text = text_content
	elif msg_type == "Image":
		$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, "Image"))
		_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
		$ImageMessageContainer/Base64ImageEdit.text = image_content
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(image_detail_idx)
		if image_content != "":
			if isImageURL(image_content) or image_content.begins_with("http://") or image_content.begins_with("https://"):
				load_image_container_from_url(image_content)
			else:
				base64_to_image($ImageMessageContainer/TextureRect, image_content)
	else:
		return {}
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, role))
	$MessageSettingsContainer/UserNameEdit.text = user_name
	return to_var()

## RFT helper functions
func get_parameter_values_from_function_parameter_dict(fpdict):
	var parametersAndValues = {}
	for fp in fpdict:
		if fp.get("parameterValueChoice", "") != "":
			parametersAndValues[fp["name"]] = fp["parameterValueChoice"]
		elif fp.get("parameterValueText", "") != "":
			parametersAndValues[fp["name"]] = fp["parameterValueText"]
		else:
			parametersAndValues[fp["name"]] = fp.get("parameterValueNumber", 0)
	return parametersAndValues

func to_rft_reference_item():
	var last_message = to_var()
	var item = {
		"ideal_function_call_data": {},
		"do_function_call": false
	}
	if last_message.get("role", "") != "assistant":
		return item
	if last_message.get("type", "") == "JSON":
		item["reference_json"] = JSON.parse_string(last_message.get("jsonSchemaValue", "{}"))
	elif last_message.get("type", "") == "Function Call":
		item["do_function_call"] = true
		item["ideal_function_call_data"] = {
					"name": last_message.get("functionName", ""),
					"arguments": get_parameter_values_from_function_parameter_dict(last_message.get("functionParameters", [])),
					"functionUsePreText": last_message.get("functionUsePreText", "")
			}
	elif last_message.get("type", "") == "Text":
			item["reference_answer"] = last_message.get("textContent", "")
	return item

func to_model_output_sample():
	var msg = to_var()
	var sample = {"output_tools": []}
	var text := ""
	match msg.get("type", ""):
		"Text":
			text = msg.get("textContent", "")
		"Function Call":
			text = msg.get("functionUsePreText", "")
			var args = get_parameter_values_from_function_parameter_dict(msg.get("functionParameters", []))
			sample["output_tools"].append({
				"id": "call_0",
				"type": "function",
				"function": {
					"name": msg.get("functionName", ""),
					"arguments": JSON.stringify(args)
				}
			})
		"JSON":
			text = msg.get("jsonSchemaValue", "")
		_:
			text = msg.get("textContent", "")
	sample["output_text"] = text
	var trimmed_text = text.strip_edges()
	if trimmed_text.begins_with("{") or trimmed_text.begins_with("["):
		var parsed = JSON.parse_string(trimmed_text)
		if parsed != null and (parsed is Dictionary or parsed is Array):
			sample["output_json"] = parsed
	return sample

func _on_button_pressed() -> void:
	print(to_rft_reference_item())
