extends ScrollContainer

@onready var MESSAGE_SCENE = preload("res://scenes/message.tscn")
# Called when the node enters the scene tree for the first time.
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")

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
		MessageInstance.from_var(m)
		#$MessagesListContainer.move_child(addButton, -1)
		$MessagesListContainer.move_child(buttonsContainer, -1)	

func _ready() -> void:
	openai.connect("gpt_response_completed", gpt_response_completed)
	openai.connect("models_received", models_received)
	openai.get_models()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_message_button_pressed() -> void:
	# Add a new message to the MessagesListContainer
	var MessageInstance = MESSAGE_SCENE.instantiate()
	#var addButton = $MessagesListContainer/AddMessageButton
	#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	var buttonsContainer = $MessagesListContainer/AddButtonsContainer
	$MessagesListContainer.add_child(MessageInstance)
	#$MessagesListContainer.move_child(addAIButton, -1)
	#$MessagesListContainer.move_child(addButton, -1)
	$MessagesListContainer.move_child(buttonsContainer, -1)	
	print(self.to_var())
	

	
func delete_all_messages_from_UI():
	for message in $MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()

func models_received(models: Array[String]):
	print(models)

func gpt_response_completed(message:Message, response:Dictionary):
	printt(message.get_as_dict())
	# Add a new message to the MessagesListContainer
	var MessageInstance = MESSAGE_SCENE.instantiate()
	#var addButton = $MessagesListContainer/AddMessageButton
	#var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	var buttonsContainer = $MessagesListContainer/AddButtonsContainer
	$MessagesListContainer.add_child(MessageInstance)
	$MessagesListContainer.move_child(buttonsContainer, -1)	
	# Populate the message with the received data
	## We need to check if its a text response or a tool call response
	var RecvMsgVar
	if len(message["tool_calls"]) > 0:
		# This is a tool call message from the assistant
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
			"imageContent": "",
			"functionName": message["tool_calls"][0]["function"]["name"],
			"functionParameters": parametersForFTC,
			"functionResults": ""
		}	
	else:
		RecvMsgVar = {
			"role": "assistant",
			"type": "Text",
			"textContent": message["content"],
			"imageContent": "",
			"functionName": "",
			"functionParameters": [],
			"functionResults": ""
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
	var settings = get_tree().get_root().get_node("FineTune").SETTINGS
	var my_conversation_id = get_tree().get_root().get_node("FineTune").CURRENT_EDITED_CONVO_IX
	var ftc_messages = self.to_var()
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
		match m["type"]:
			"Text":
				nm.set_content(m["textContent"])
				openai_messages.append(nm)
			"Image":
				nm.add_image_content(m["imageContent"])
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
				var tool_response_message = Message.new()
				tool_response_message.create_tool_response(call_id, m["functionResults"])
				openai_messages.append(tool_call_message)
				openai_messages.append(tool_response_message)
		current_msg_ix += 1
	var model = settings["modelChoice"]
	print(model)
	var toolsforopenAI = get_tree().get_root().get_node("FineTune/Conversation/Functions/FunctionsList").functions_list_to_gpt_available_tools_list()
	openai.prompt_gpt(openai_messages, model, "https://api.openai.com/v1/chat/completions", toolsforopenAI)

func _on_add_message_completion_button_mouse_entered() -> void:
	if get_tree().get_root().get_node("FineTune").SETTINGS["apikey"] == "":
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = true
	else:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = false
