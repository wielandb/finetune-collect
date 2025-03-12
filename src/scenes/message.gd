extends HBoxContainer
@onready var result_parameters_scene = preload("res://scenes/function_call_results_parameter.tscn")
@onready var function_use_parameters_scene = preload("res://scenes/function_use_parameter.tscn")
@onready var imageTexture = $ImageMessageContainer/TextureRect

var image_access_web = FileAccessWeb.new()
var token = "" # The token for the schema editor for this message
var edit_message_url = ""

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func to_var():
	var me = {}
	me["role"] = $MessageSettingsContainer/Role.get_item_text($MessageSettingsContainer/Role.selected)
	me["type"] = $MessageSettingsContainer/MessageType.get_item_text($MessageSettingsContainer/MessageType.selected)
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
	me["jsonSchemaValue"] = $SchemaMessageContainer/SchemaEdit.text
	if $MetaMessageContainer.visible:
		me["metaData"] = {}
		me["metaData"]["ready"] = $MetaMessageContainer/ConversationReadyContainer/ConversationReadyCheckBox.button_pressed
		me["metaData"]["conversationName"] = $MetaMessageContainer/ConversationNameContainer/ConversationNameEdit.text
		me["metaData"]["notes"] = $MetaMessageContainer/ConversationNotesEdit.text
		me["role"] = "meta"
		me["type"] = "meta"
	return me

func from_var(data):
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	var useUserNames = get_node("/root/FineTune").SETTINGS.get("useUserNames", false)
	print("Building from var")
	print(data)
	if data.get("role", "user") == "meta" and data.get("type", "Text") == "meta":
		$MessageSettingsContainer.visible = false
		$MetaMessageContainer.visible = true
		var metaData = data.get("metaData", {})
		$MetaMessageContainer/ConversationReadyContainer/ConversationReadyCheckBox.button_pressed = metaData.get("ready", false)
		$MetaMessageContainer/ConversationNameContainer/ConversationNameEdit.text = metaData.get("conversationName", "")
		$MetaMessageContainer/ConversationNotesEdit.text = metaData.get("notes", "")
		return
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, data.get("role", "user")))
	_on_role_item_selected($MessageSettingsContainer/Role.selected)
	$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, data.get("type", "Text")))
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
			base64_to_image(imageTexture, $ImageMessageContainer/Base64ImageEdit.text)
	if data.has("imageDetail"):
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(data["imageDetail"])
	else: # TODO: Add option what the standard quality should be
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(0)
	# Now everything regarding functions
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data.get("functionName", "")))
	#if data["functionName"] != "":
	#	_on_function_name_choice_button_item_selected(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	for d in data.get("functionParameters", []):
		var parameterInstance = function_use_parameters_scene.instantiate()
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
	# JSON Schema
	$SchemaMessageContainer/SchemaEdit.text = data.get("jsonSchemaValue", "{}")
	# Check if it is a meta message
	
	#for d in data["functionResults"]:
	#	var resultInstance = result_parameters_scene.instantiate()
	#	$FunctionMessageContainer.add_child(resultInstance)
	#	var resultsSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel2.get_index()
	#	$FunctionMessageContainer.move_child(resultInstance, resultsSectionLabelIx)
	#	resultInstance.from_var(d)
		
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Init Message object")
	for item in get_node("/root/FineTune").get_available_function_names():
		$FunctionMessageContainer/function/FunctionNameChoiceButton.add_item(item)
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(-1)
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		# DPO: Only User and assistant messages are available, only text
		$MessageSettingsContainer/MessageType.set_item_disabled(1, true)
		$MessageSettingsContainer/MessageType.set_item_disabled(2, true)
		$MessageSettingsContainer/Role.set_item_disabled(0, true)
	_on_check_what_text_message_should_be_visisble()
	image_access_web.loaded.connect(_on_file_loaded)
	image_access_web.progress.connect(_on_progress)
	var token_counter_path =  get_node("/root/FineTune").SETTINGS.get("tokenCounterPath", "")
	if token_counter_path == "":
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.disabled = true
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_TOKEN_COUNTER_PATH")
	else:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.tooltip_text = ""
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.disabled = false

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
	match index:
		0:
			$TextMessageContainer.visible = true
		1:
			$ImageMessageContainer.visible = true
		2:
			$FunctionMessageContainer.visible = true
		3:
			$SchemaMessageContainer.visible = true


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
	$ImageMessageContainer/Base64ImageEdit.text = base_64_data

func base64_to_image(textureRectNode, b64Data):
	var img = Image.new()
	img.load_jpg_from_buffer(
		Marshalls.base64_to_raw(b64Data)
	)
	textureRectNode.texture = ImageTexture.create_from_image(img)
	
func _on_load_image_button_pressed() -> void:
	match OS.get_name():
		"Web":
			image_access_web.open(".jpg, .jpeg")
		_:
			$ImageMessageContainer/FileDialog.visible = true


func _on_delete_button_pressed() -> void:
	queue_free()


func _on_add_result_button_pressed() -> void:
	var newResultParameter = result_parameters_scene.instantiate()
	$FunctionMessageContainer.add_child(newResultParameter)
	var addResultButton = $FunctionMessageContainer/AddResultButton
	$FunctionMessageContainer.move_child(addResultButton, -1)



func _on_role_item_selected(index: int) -> void:
	# Change what message types are enabled depending on what role was selected
	$MessageSettingsContainer/MessageType.set_item_disabled(0, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(1, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(2, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(3, true)
	$MessageSettingsContainer/MessageType.set_item_tooltip(0, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(1, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(2, "")
	$MessageSettingsContainer/MessageType.set_item_tooltip(3, "")
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	match finetunetype:
		0:
			match index:
				0:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_SYSTEM_USER_CANT_DO_THAT"))
				1:
					$MessageSettingsContainer/MessageType.set_item_disabled(1, false)
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_ONLY_ASSISTANT_CAN_USE_FUNCTIONS"))
					$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_ONLY_ASSISTANT_CAN_RESPOND_IN_SCHEMA"))
				2:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_ASSISTANT_CANT_SEND_IMAGES"))
					# Only make functions available if there are any
					if len(get_node("/root/FineTune").get_available_function_names()) > 0:
						$MessageSettingsContainer/MessageType.set_item_disabled(2, false)
					else:
						$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_NEEDS_AT_LEAST_ONE_FUNCTION"))
					# Only enable JSON schema if the Schema in the Settings is... well not valid, but at least a valid JSON (so not empty etc.)
					if get_node("/root/FineTune/Conversation/Settings/ConversationSettings").update_valid_json_for_schema_checker():
						$MessageSettingsContainer/MessageType.set_item_disabled(3, false)
					else:
						$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_NEEDS_VALID_JSON_IN_SETTINGS"))
		1:
			# In DPO, there is only text messages
			$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
			$MessageSettingsContainer/MessageType.set_item_tooltip(1, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
			$MessageSettingsContainer/MessageType.set_item_tooltip(2, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
			$MessageSettingsContainer/MessageType.set_item_tooltip(3, tr("DISABLED_EXPLANATION_DPO_ONLY_SUPPORTS_TEXT"))
		2:
			pass
			
func _on_function_name_choice_button_item_selected(index: int) -> void:
	# Die parameter abrufen, die es für diese Funktion gibt
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var pn = get_node("/root/FineTune").get_available_parameter_names_for_function(my_function_name)
	print("Parameter names for that selected function:")
	print(pn)
	# Alle Parameter Dinger löschen
	for parameter in $FunctionMessageContainer.get_children():
		if parameter.is_in_group("function_use_parameter"):
			parameter.queue_free()
	# den Index des Parameter-Labels finden
	var pix = $FunctionMessageContainer/ParamterSectionLabel.get_index()
	for p in pn:
		var my_parameter_def = get_node("/root/FineTune").get_parameter_def(my_function_name, p)
		print("Adding " + p)
		var newScene = function_use_parameters_scene.instantiate()
		$FunctionMessageContainer.add_child(newScene)
		newScene.get_node("ParameterName").text = p
		$FunctionMessageContainer.move_child(newScene, pix + 1)
		# Falls der Paramter required ist, checkbox auf ja setzen und disablen
		if get_node("/root/FineTune").is_function_parameter_required($FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected), p):
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
			if get_node("/root/FineTune").is_function_parameter_enum(my_function_name, p):
				newScene.get_node("FunctionUseParameterChoice").visible = true
				newScene.get_node("FunctionUseParameterChoice").clear()
				for pv in get_node("/root/FineTune").get_function_parameter_enums(my_function_name, p):
					newScene.get_node("FunctionUseParameterChoice").add_item(pv)
			else:
				newScene.get_node("FunctionUseParameterEdit").visible = true
	check_if_function_button_should_be_visible_or_disabled()
	print("-------------------")

## Funktionen, die den nachrichtenverlauf speichern wenn etwas passiert

func update_messages_global():
	get_node("/root/FineTune").save_current_conversation()
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
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
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

	# Remove any query parameters or fragment identifiers.
	var cleaned_url = lower_url.split("?")[0].split("#")[0]

	# Finally, check if the cleaned URL ends with a valid image extension.
	return cleaned_url.ends_with(".png") or cleaned_url.ends_with(".jpg")

# This function uses the above isJpgOrPngURL() to check if the URL is valid,
# and if so, returns "png" if the URL ends with .png or "jpg" if it ends with .jpg.
# Otherwise, it returns an empty string.
func getImageType(url: String) -> String:
	# Use our helper function to ensure the URL is valid.
	if not isImageURL(url):
		return ""
	
	# Convert to lowercase and remove any query or fragment parts.
	var lower_url = url.to_lower()
	var base_url = lower_url.split("?")[0].split("#")[0]
	
	if base_url.ends_with(".png"):
		return "png"
	elif base_url.ends_with(".jpg"):
		return "jpg"
	else:
		return ""


func _on_schema_edit_button_pressed() -> void:
	# POST the Schema and The Data we already have to the editor URL to retrieve a token
	var json_schema_string = get_node("/root/FineTune").SETTINGS.get("jsonSchema", "")
	var editor_url = get_node("/root/FineTune").SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")
	var existing_json_data = $SchemaMessageContainer/SchemaEdit.text
	var data_to_send = {"json_data": existing_json_data, "json_schema": json_schema_string}
	print("Sending data:")
	print(data_to_send)
	var json_to_send = JSON.stringify(data_to_send)
	var custom_headers := PackedStringArray()
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
		var editor_url = get_node("/root/FineTune").SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")
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
		$SchemaMessageContainer/SchemaEdit.visible = false
		$SchemaMessageContainer/SchemaEditButtonsContainer.visible = false
	else:
		print("Es kam kein 200 zurück")

func _on_polling_timer_timeout() -> void:
	var editor_url = get_node("/root/FineTune").SETTINGS.get("schemaEditorURL", "https://www.haukauntrie.de/online/api/schema-editor/")
	# Start a HTTP Request to Poll for completion of the edit from users side
	$SchemaMessageContainer/PollForCompletion.request(editor_url + "?poll=1&token=" + token, [], HTTPClient.METHOD_GET, "")

func _on_poll_for_completion_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json_data = JSON.parse_string(body.get_string_from_utf8())
		if json_data["ready"] == false:
			return
		elif json_data["ready"] == true:
			$SchemaMessageContainer/SchemaEdit.text = json_data["json_data"]
			$SchemaMessageContainer/PollingTimer.stop()
			$SchemaMessageContainer/SchemaMessagePolling.visible = false
			$SchemaMessageContainer/SchemaEdit.visible = true
			$SchemaMessageContainer/SchemaEditButtonsContainer.visible = true


func _on_schema_message_polling_reopen_browser_btn_pressed() -> void:
	OS.shell_open(edit_message_url)

## Function Execution
func get_current_function_parameter_names():
	# returns a list of names of the parameters of the function currently chosen
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	return get_node("/root/FineTune").get_available_parameter_names_for_function(my_function_name)

func get_current_value_for_function_parameter_name(parametername):
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var fdefdict = get_function_defintion_dict(my_function_name)
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
	var allfunctiondefs = get_node("/root/FineTune").FUNCTIONS
	for fdef in allfunctiondefs:
		if fdef["name"] == fname:
			return fdef

func _on_function_execution_button_pressed() -> void:
	var my_function_name = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var fdefdict = get_function_defintion_dict(my_function_name)
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
	var cost_json = FileAccess.get_file_as_string("res://assets/openai_costs.json").strip_edges()
	#print(cost_json)
	var costs = JSON.parse_string(cost_json)
	var my_convo_ix = get_node("/root/FineTune").CURRENT_EDITED_CONVO_IX
	var tokens_this_conversation = conversation_token_counts[my_convo_ix]
	var tokens_all_conversations = {"total": 0, "input": 0, "output": 0}
	for convoIx in conversation_token_counts:
		tokens_all_conversations["total"] += conversation_token_counts[convoIx]["total"]
		tokens_all_conversations["input"] += conversation_token_counts[convoIx]["input"]
		tokens_all_conversations["output"] += conversation_token_counts[convoIx]["output"]
	# Get the dollar to currency multiplier
	var dollar_to_currency_multiplier = costs.get("dollar_to_currency_muliplier", 1)
	# Training cost 4o (this conversation)
	var training_cost_4o_this_conversation = (tokens_this_conversation["total"] * (costs["training"]["gpt-4o"] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4oThisConversation.text = str(snapped(training_cost_4o_this_conversation, 0.001)) + " €"
	# Training cost 4o (whole fine tune)
	var training_cost_4o_whole_fine_tune = (tokens_all_conversations["total"] * (costs["training"]["gpt-4o"] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4oWholeFineTune.text = str(snapped(training_cost_4o_whole_fine_tune, 0.001)) + " €"
	# Training cost 4o-mini (this conversation)
	var training_cost_4o_mini_this_conversation = (tokens_this_conversation["total"] * (costs["training"]["gpt-4o-mini"] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4ominiThisConversation.text = str(snapped(training_cost_4o_mini_this_conversation, 0.001)) + " €"
	# Training cost 4o-mini (whole fine tune)
	var training_cost_4o_mini_whole_fine_tune = (tokens_all_conversations["total"] * (costs["training"]["gpt-4o-mini"] / 1_000_000)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/TrainingCost4ominiWholeFineTune.text = str(snapped(training_cost_4o_mini_whole_fine_tune, 0.001)) + " €"
	# Inference cost 4o (this conversation)
	## Inference cost = input tokens * input token price + output tokens * output token price (here and below)
	var inferecence_cost_4o_this_conversation = (tokens_this_conversation["input"] * (costs["inference"]["gpt-4o"]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4oThisConversation.text = str(snapped(inferecence_cost_4o_this_conversation, 0.001)) + " €"
	# Inference cost 4o (whole fine tune)
	var inferecence_cost_4o_whole_fine_tune = (tokens_all_conversations["input"] * (costs["inference"]["gpt-4o"]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4oWholeFineTune.text = str(snapped(inferecence_cost_4o_whole_fine_tune, 0.001)) + " €"
	# Inference cost 4o-mini (this conversation)
	var inferecence_cost_4o_mini_this_conversation = (tokens_this_conversation["input"] * (costs["inference"]["gpt-4o-mini"]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["inference"]["gpt-4o-mini"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4ominiThisConversation.text = str(snapped(inferecence_cost_4o_mini_this_conversation, 0.001)) + " €"
	# Inference cost 4o-mini (whole fine tune)
	var inferecence_cost_4o_mini_whole_fine_tune = (tokens_all_conversations["input"] * (costs["inference"]["gpt-4o-mini"]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["inference"]["gpt-4o-mini"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/InferenceCost4ominiWholeFineTune.text = str(snapped(inferecence_cost_4o_mini_whole_fine_tune, 0.001)) + " €"
	# batch_inference_cost_4o (this conversation)
	var batch_inference_cost_4o_this_conversation = (tokens_this_conversation["input"] * (costs["batch_inference"]["gpt-4o"]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["batch_inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4oThisConversation.text = str(snapped(batch_inference_cost_4o_this_conversation, 0.001)) + " €"
	# batch_inference_cost_4o (whole fine tune)
	var batch_inference_cost_4o_whole_fine_tune = (tokens_all_conversations["input"] * (costs["batch_inference"]["gpt-4o"]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["batch_inference"]["gpt-4o"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4oWholeFineTune.text = str(snapped(batch_inference_cost_4o_whole_fine_tune, 0.001)) + " €"
	# batch_inference_cost_4o-mini (this conversation)
	var batch_inference_cost_4o_mini_this_conversation = (tokens_this_conversation["input"] * (costs["batch_inference"]["gpt-4o-mini"]["input"] / 1_000_000) + tokens_this_conversation["output"] * (costs["batch_inference"]["gpt-4o-mini"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4ominiThisConversation.text = str(snapped(batch_inference_cost_4o_mini_this_conversation, 0.001)) + " €"
	# batch_inference_cost_4o-mini (whole fine tune)
	var batch_inference_cost_4o_mini_whole_fine_tune = (tokens_all_conversations["input"] * (costs["batch_inference"]["gpt-4o-mini"]["input"] / 1_000_000) + tokens_all_conversations["output"] * (costs["batch_inference"]["gpt-4o-mini"]["output"] / 1_000_00)) * dollar_to_currency_multiplier
	$MetaMessageContainer/InfoLabelsGridContainer/BatchInferenceCost4oMiniWholeFineTune.text = str(snapped(batch_inference_cost_4o_mini_whole_fine_tune, 0.001)) + " €"
	# Number of images
	$MetaMessageContainer/InfoLabelsGridContainer/NumberOfImagesThisConversation.text = str(get_node("/root/FineTune").get_number_of_images_for_conversation(my_convo_ix))
	$MetaMessageContainer/InfoLabelsGridContainer/NumberOfImagesWholeFineTune.text = str(get_node("/root/FineTune").get_number_of_images_total())

func _do_token_calculation_update() -> void:
	var output = []
	var own_savefile_path = get_node("/root/FineTune").RUNTIME["filepath"]
	var token_counter_path =  get_node("/root/FineTune").SETTINGS.get("tokenCounterPath", "")
	if token_counter_path == "" or own_savefile_path == "":
		return
	var arguments_list = [token_counter_path, own_savefile_path]
	var exit_code = OS.execute("python", arguments_list, output)
	var outputstring = output[0].strip_edges()
	print(outputstring)
	var conversation_token_counts = JSON.parse_string(outputstring)
	var my_convo_ix = get_node("/root/FineTune").CURRENT_EDITED_CONVO_IX
	$MetaMessageContainer/InfoLabelsGridContainer/ThisConversationTotalTokens.text = str(int(conversation_token_counts[my_convo_ix]["total"]))
	var all_tokens = 0
	for convoKey in conversation_token_counts:
		all_tokens += conversation_token_counts[convoKey]["total"]
	$MetaMessageContainer/InfoLabelsGridContainer/WholeFineTuneTotalTokens.text = str(int(all_tokens))
	update_token_costs(conversation_token_counts)


func _on_meta_message_toggle_cost_estimation_button_pressed() -> void:
	$MetaMessageContainer/InfoLabelsGridContainer.visible = not $MetaMessageContainer/InfoLabelsGridContainer.visible
	if $MetaMessageContainer/InfoLabelsGridContainer.visible:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.text = tr("MESSAGE_META_HIDE_TOKEN_CALCS")
	else:
		$MetaMessageContainer/MetaMessageToggleCostEstimationButton.text = tr("MESSAGE_META_SHOW_TOKEN_CALCS")
