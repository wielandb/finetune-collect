extends ScrollContainer

@onready var MESSAGE_SCENE = preload("res://scenes/message.tscn")
# Called when the node enters the scene tree for the first time.
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	$MessagesListContainer/AddButtonsContainer.vertical = enabled
	for child in $MessagesListContainer.get_children():
		if child.is_in_group("message") and child.has_method("set_compact_layout"):
			child.set_compact_layout(enabled)

func _apply_compact_layout_to_message(message_instance) -> void:
	if message_instance != null and message_instance.has_method("set_compact_layout"):
		message_instance.set_compact_layout(_compact_layout_enabled)

func to_var():
	var me = []
	for message in $MessagesListContainer.get_children():
		if message.is_in_group("message"):
			me.append(message.to_var())
	return me


func from_var(data):
	# data -> CONVERSATIONS[ix] ([] von messages
	for m in data:
		var MessageInstance = MESSAGE_SCENE.instantiate()
		#var addButton = $MessagesListContainer/AddMessageButton
		var buttonsContainer = $MessagesListContainer/AddButtonsContainer
		$MessagesListContainer.add_child(MessageInstance)
		_apply_compact_layout_to_message(MessageInstance)
		MessageInstance.from_var(m)
		#$MessagesListContainer.move_child(addButton, -1)
		$MessagesListContainer.move_child(buttonsContainer, -1)	

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	clip_contents = true
	openai.connect("gpt_response_completed", gpt_response_completed)
	openai.connect("models_received", models_received)
	openai.get_models()
	get_viewport().files_dropped.connect(on_dropped_files)
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_released("new_msg"):
		_on_add_message_button_pressed()


func update_conversation():
	var my_conversation_id = get_tree().get_root().get_node("FineTune").CURRENT_EDITED_CONVO_IX
	get_tree().get_root().get_node("FineTune").CONVERSATIONS[my_conversation_id] = to_var()

func get_last_message_role():
	update_conversation()
	var my_conversation_id = get_tree().get_root().get_node("FineTune").CURRENT_EDITED_CONVO_IX
	var my_conversation = get_tree().get_root().get_node("FineTune").CONVERSATIONS[my_conversation_id]
	var last_message_role = ""
	for msg in my_conversation:
		last_message_role = msg["role"]
	return last_message_role
	

func _on_add_message_button_pressed() -> void:
	var isGlobalSystemMessageEnabled = get_tree().get_root().get_node("FineTune").SETTINGS.get("useGlobalSystemMessage", false)
	# Add a new message to the MessagesListContainer
	var MessageInstance = MESSAGE_SCENE.instantiate()
	#var addButton = $MessagesListContainer/AddMessageButton
	#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	var last_message_role = get_last_message_role()
	var buttonsContainer = $MessagesListContainer/AddButtonsContainer
	$MessagesListContainer.add_child(MessageInstance)
	_apply_compact_layout_to_message(MessageInstance)
	#$MessagesListContainer.move_child(addAIButton, -1)
	#$MessagesListContainer.move_child(addButton, -1)
	$MessagesListContainer.move_child(buttonsContainer, -1)
	match last_message_role:
		"meta":
			if isGlobalSystemMessageEnabled:
				MessageInstance.from_var(
					{
					"role": "user",
					"type": "Text"
					}
				)
			else:
				MessageInstance.from_var(
					{
					"role": "system",
					"type": "Text"
					}
				)
		"none":
			MessageInstance.from_var(
				{
				"role": "system",
				"type": "Text"
				}
			)
		"system":
			MessageInstance.from_var(
				{
				"role": "user",
				"type": "Text"
				}
			)
		"user":
			MessageInstance.from_var(
				{
				"role": "assistant",
				"type": "Text"
				}
			)
		"assistant":
			MessageInstance.from_var(
				{
				"role": "user",
				"type": "Text"
				}
			)
	print("Aktueller Konversationszustand nach hinzugefügter Nachricht:")
	print(self.to_var())
	

	
func delete_all_messages_from_UI():
	for message in $MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()

func models_received(models: Array[String]):
	print(models)

func gpt_response_completed(message: Message, response:Dictionary):
	printt(message.get_as_dict())
	# Add a new message to the MessagesListContainer
	var MessageInstance = MESSAGE_SCENE.instantiate()
	#var addButton = $MessagesListContainer/AddMessageButton
	#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	var buttonsContainer = $MessagesListContainer/AddButtonsContainer
	$MessagesListContainer.add_child(MessageInstance)
	_apply_compact_layout_to_message(MessageInstance)
	$MessagesListContainer.move_child(buttonsContainer, -1)	
	# Populate the message with the received data
	## We need to check if its a text response or a tool call response
	var RecvMsgVar
	if len(message["tool_calls"]) > 0:
		# This is a tool call message from the assistant
		## Get the preFunctionMessage
		var preFunctionText = ""
		if message["content"]:
			preFunctionText = message["content"]
		## Unpack the parameters
		var parametersFromAssistantDict = JSON.parse_string(message["tool_calls"][0]["function"]["arguments"])
		var parametersForFTC = []
		for parameterFromToolCallKey in parametersFromAssistantDict:
			var k = parameterFromToolCallKey
			var parameterFromToolCallValue = parametersFromAssistantDict[parameterFromToolCallKey]
			var parameterType = get_tree().get_root().get_node("FineTune").get_function_parameter_type(message["tool_calls"][0]["function"]["name"], parameterFromToolCallKey)
			var isParameterEnum = get_tree().get_root().get_node("FineTune").is_function_parameter_enum(message["tool_calls"][0]["function"]["name"], parameterFromToolCallKey)
			if parameterType == "String":
				if isParameterEnum:
					parametersForFTC.append({"name": parameterFromToolCallKey, "isUsed": true,"parameterValueChoice" : parameterFromToolCallValue, "parameterValueText": "", "parameterValueNumber": 0})					
				else:
					# If it's a String, then the answer needs to be in parameterValueText, and the others need to be blank
					parametersForFTC.append({"name": parameterFromToolCallKey, "isUsed": true, "parameterValueText": parameterFromToolCallValue, "parameterValueChoice": "", "parameterValueNumber": 0})
			elif parameterType == "Number":
				parametersForFTC.append({"name": parameterFromToolCallKey, "isUsed": true, "parameterValueText": "", "parameterValueChoice": "", "parameterValueNumber": parameterFromToolCallValue})
		RecvMsgVar = {
			"role": "assistant",
			"type": "Function Call",
			"textContent": "",
			"unpreferredTextContent": "",
			"preferredTextContent": "",
			"imageContent": "",
			"functionName": message["tool_calls"][0]["function"]["name"],
			"functionParameters": parametersForFTC,
			"functionResults": "",
			"functionUsePreText": preFunctionText
		}	
	else:
		RecvMsgVar = {
			"role": "assistant",
			"type": "Text",
			"textContent": message["content"],
			"unpreferredTextContent": message["content"],
			"preferredTextContent": "",
			"imageContent": "",
			"functionName": "",
			"functionParameters": [],
			"functionResults": "",
			"functionUsePreText": ""
		}
	MessageInstance.from_var(RecvMsgVar)
	
func messages_to_openai_format():
	var ftc_messages = self.to_var()
	var openai_messages = []
	for m in ftc_messages:
		var nm = Message.new()
		nm.set_role(m["role"])
		nm.set_content(m["textContent"])
		openai_messages.append(nm)
	return openai_messages
		
func _on_add_message_completion_button_pressed() -> void:
	#var messages:Array[Message] = [Message.new()]
	#messages[0].set_content("say hi!")
	var image_detail_map = {
		0: "high",
		1: "low",
		2: "auto"
	}
	var settings = get_tree().get_root().get_node("FineTune").SETTINGS
	var my_conversation_id = get_tree().get_root().get_node("FineTune").CURRENT_EDITED_CONVO_IX
	var ftc_messages = self.to_var()
	# Remove the meta message if anywhere
	var new_ftc_messages = []
	for msg in ftc_messages:
		if msg["type"] == "meta" or msg["role"] == "meta":
			continue
		else:
			new_ftc_messages.append(msg)
	ftc_messages = new_ftc_messages
	var openai_messages:Array[Message] = []
	# Check if a global system message needs to be used, and if so, add it before working with the message list
	if settings["useGlobalSystemMessage"]:
		var gsm = Message.new()
		gsm.set_role("system")
		gsm.set_content(settings["globalSystemMessage"])
		openai_messages.append(gsm)
	var current_msg_ix = 0
	for m in ftc_messages:
		var nm = Message.new()
		nm.set_role(m["role"])
		if settings.get("useUserNames", false):
			nm.set_user_name(settings.get("useUserNames", ""))
		match m["type"]:
			"Text":
				nm.set_content(m["textContent"])
				openai_messages.append(nm)
			"Image":
				nm.add_image_content(m["imageContent"], image_detail_map[m.get("imageDetail", 0)])
				openai_messages.append(nm)
			"Audio":
				nm.add_audio_content(m["audioData"], m["audioFiletype"])
				openai_messages.append(nm)
			"PDF File":
				nm.add_pdf_content(m["fileMessageData"], m["fileMessageName"])
				openai_messages.append(nm)
			"Function Call":
				# A "function call" for us when part of the messages list is two messages for openai, one the assistant calling the tool, and then the response
				# However, when we receive a tool call as an answer from the model, its only one message
				var call_id = str(my_conversation_id) + "-" + str(current_msg_ix)
				var tool_call_message = Message.new()
				tool_call_message.set_role("assistant")
				var thisFunctionCallParameters = {}
				for param in m["functionParameters"]:
					# We don't know what kind of value this param is representing from the data we receive,
					# but we know that the number value will always be set, but Text and Choice are "" if the are not used
					# there may be some bizzare edge cases though, so we just decide that Text takes precendence over Choice, and both take precende over Number
					if param["isUsed"]:
						var paramValue = ""
						if param["parameterValueText"] != "":
							paramValue = param["parameterValueText"]
						elif param["parameterValueChoice"] != "":
							paramValue = param["parameterValueChoice"]
						else:
							paramValue = param["parameterValueNumber"]
						thisFunctionCallParameters[param["name"]] = paramValue
				tool_call_message.add_function_call(call_id, m["functionName"], thisFunctionCallParameters)
				if m["functionUsePreText"] != "":
					tool_call_message.add_text_content(m["functionUsePreText"])
				var tool_response_message = Message.new()
				tool_response_message.create_tool_response(call_id, m["functionResults"])
				openai_messages.append(tool_call_message)
				openai_messages.append(tool_response_message)
		current_msg_ix += 1
	var model = settings["modelChoice"]
	print(model)
	for m in openai_messages:
		print(m.content)
	var toolsforopenAI = get_tree().get_root().get_node("FineTune/Conversation/Functions/FunctionsList").functions_list_to_gpt_available_tools_list()
	openai.prompt_gpt(openai_messages, model, "https://api.openai.com/v1/chat/completions", toolsforopenAI)

func check_autocomplete_disabled_status():
	if get_tree().get_root().get_node("FineTune").SETTINGS["apikey"] == "":
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_OPENAI_API_KEY")
		return true
	if len(self.to_var()) < 1:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_AT_LEAST_ONE_MESSAGE")
		return true
	if get_tree().get_root().get_node("FineTune").exists_function_without_name():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_WITHOUT_NAME_EXISTS")
		return true
	if get_tree().get_root().get_node("FineTune").exists_function_without_description():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_WITHOUT_DESCRIPTION_EXISTS")
		return true
	if get_tree().get_root().get_node("FineTune").exists_parameter_without_name():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_PARAMETER_WITHOUT_NAME_EXISTS")
		return true
	if get_tree().get_root().get_node("FineTune").exists_parameter_without_description():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_PARAMETER_WITTHOUT_DESCRIPTION_EXISTS")
		return true
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("MESSAGE_LIST_ASK_OPENAI_API_FOR_ANSWER")
	return false

func check_add_message_disabled_status():
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		if $MessagesListContainer.get_child_count() >= 3:
			$MessagesListContainer/AddButtonsContainer/AddMessageButton.tooltip_text = tr("DISABLED_EXPLANATION_DPO_ONLY_ALLOWS_ONE_USER_AND_ONE_ASSISTANT_MESSAGE")
			# DPO only allows for one user and one assistant message
			return true
	$MessagesListContainer/AddButtonsContainer/AddMessageButton.tooltip_text = ""
	return false

func _on_something_happened_to_check_enabled_status() -> void:
	if check_add_message_disabled_status():
		$MessagesListContainer/AddButtonsContainer/AddMessageButton.disabled = true
	else:
		$MessagesListContainer/AddButtonsContainer/AddMessageButton.disabled = false

func _on_add_message_completion_button_mouse_entered() -> void:
	_on_something_happened_to_check_enabled_status()
	if check_autocomplete_disabled_status():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = true
	else:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = false

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
	return cleaned_url.ends_with(".png") or cleaned_url.ends_with(".jpg") or cleaned_url.ends_with(".jpeg")

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
	elif base_url.ends_with(".jpeg"):
		return "jpeg"
	else:
		return ""
		
func on_dropped_files(files):
	for file in files:
		if file.to_lower().ends_with(".jpg") or file.to_lower().ends_with(".jpeg") or file.to_lower().ends_with(".png"):
			# Add a new message to the MessagesListContainer
			var MessageInstance = MESSAGE_SCENE.instantiate()
			#var addButton = $MessagesListContainer/AddMessageButton
			#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
			var buttonsContainer = $MessagesListContainer/AddButtonsContainer
			$MessagesListContainer.add_child(MessageInstance)
			_apply_compact_layout_to_message(MessageInstance)
			#$MessagesListContainer.move_child(addAIButton, -1)
			#$MessagesListContainer.move_child(addButton, -1)
			$MessagesListContainer.move_child(buttonsContainer, -1)	
			MessageInstance.from_var(
				{
				"role": "user",
				"type": "Image"
				}
			)
			MessageInstance._on_file_dialog_file_selected(file)
		elif file.to_lower().ends_with(".ftproj") or file.to_lower().ends_with(".json"):
				var ft_node = get_tree().get_root().get_node("FineTune")
				if file.to_lower().ends_with(".ftproj"):
					ft_node.load_from_binary(file)
					ft_node.RUNTIME["filepath"] = file
					ft_node.save_last_project_path(file)
				else:
					var json_text = FileAccess.get_file_as_string(file)
					var parsed = JSON.parse_string(json_text)
					if parsed is Dictionary and parsed.has("functions") and parsed.has("conversations") and parsed.has("settings"):
						ft_node.load_from_json_data(json_text)
						ft_node.RUNTIME["filepath"] = file
						ft_node.save_last_project_path(file)
					else:
						var ftcmsglist = ft_node.conversation_from_openai_message_json(json_text)
						for ftmsg in ftcmsglist:
							add_message(ftmsg)
		elif file.to_lower().ends_with(".jsonl"):
			var ft_node = get_tree().get_root().get_node("FineTune")
			if ft_node != null and ft_node.has_method("import_finetune_jsonl_file"):
				ft_node.import_finetune_jsonl_file(file)

func add_message(message_obj):
			# Add a new message to the MessagesListContainer
			var MessageInstance = MESSAGE_SCENE.instantiate()
			#var addButton = $MessagesListContainer/AddMessageButton
			#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
			var buttonsContainer = $MessagesListContainer/AddButtonsContainer
			$MessagesListContainer.add_child(MessageInstance)
			_apply_compact_layout_to_message(MessageInstance)
			#$MessagesListContainer.move_child(addAIButton, -1)
			#$MessagesListContainer.move_child(addButton, -1)
			$MessagesListContainer.move_child(buttonsContainer, -1)	
			MessageInstance.from_var(message_obj)
