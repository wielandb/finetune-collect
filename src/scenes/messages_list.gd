extends ScrollContainer

@onready var MESSAGE_SCENE = preload("res://scenes/message.tscn")
# Called when the node enters the scene tree for the first time.
@onready var openai = get_tree().get_root().get_node("FineTune/OpenAi")
const JsonSchemaValidator = preload("res://json_schema_validator.gd")
const SchemaAlignOpenAI = preload("res://scenes/schemas/schema_align_openai.gd")
var _compact_layout_enabled = false
var _schema_completion_options = []
var _pending_completion_contexts = []

func _apply_completion_controls_layout() -> void:
	var add_message_btn = $MessagesListContainer/AddButtonsContainer/AddMessageButton
	var add_completion_btn = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton
	var completion_mode_btn = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn
	add_message_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_message_btn.size_flags_stretch_ratio = 19.0
	add_message_btn.clip_text = true
	add_completion_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_completion_btn.size_flags_stretch_ratio = 19.0
	add_completion_btn.clip_text = true
	completion_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	completion_mode_btn.size_flags_stretch_ratio = 2.0
	completion_mode_btn.fit_to_longest_item = false
	completion_mode_btn.clip_text = true
	completion_mode_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	$MessagesListContainer/AddButtonsContainer.vertical = enabled
	_apply_completion_controls_layout()
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
	_apply_completion_controls_layout()
	openai.connect("gpt_response_completed", gpt_response_completed)
	if openai.has_signal("gpt_response_failed") and not openai.is_connected("gpt_response_failed", Callable(self, "_on_gpt_response_failed")):
		openai.connect("gpt_response_failed", _on_gpt_response_failed)
	openai.connect("models_received", models_received)
	openai.get_models()
	get_viewport().files_dropped.connect(on_dropped_files)
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)
	_refresh_schema_completion_mode_options()
	_on_something_happened_to_check_enabled_status()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_released("new_msg") and _is_new_message_shortcut_allowed():
		_on_add_message_button_pressed()

func _is_new_message_shortcut_allowed() -> bool:
	var conversation_tabs = get_tree().get_root().get_node_or_null("FineTune/Conversation")
	if conversation_tabs is TabContainer and conversation_tabs.current_tab != 0:
		return false
	var add_message_btn = $MessagesListContainer/AddButtonsContainer/AddMessageButton
	if add_message_btn.disabled:
		return false
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return false
	return true


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
	if check_add_message_disabled_status():
		_on_something_happened_to_check_enabled_status()
		return
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

func _message_content_to_text(content) -> String:
	if content is String:
		return content
	if content is Array:
		var parts = []
		for part in content:
			if part is Dictionary:
				var part_type = str(part.get("type", ""))
				if part_type == "text" or part_type == "output_text":
					parts.append(str(part.get("text", "")))
			elif part is String:
				parts.append(part)
		return "".join(parts)
	return str(content)

func _completion_schema_name_to_api_name(schema_name: String) -> String:
	var cleaned = ""
	for i in range(schema_name.length()):
		var ch = schema_name.substr(i, 1)
		var is_letter = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")
		var is_digit = ch >= "0" and ch <= "9"
		if is_letter or is_digit or ch == "_" or ch == "-":
			cleaned += ch
		else:
			cleaned += "_"
	if cleaned == "":
		cleaned = "schema"
	if cleaned.length() > 64:
		cleaned = cleaned.substr(0, 64)
	return cleaned

func _looks_like_json_schema(value) -> bool:
	if not (value is Dictionary):
		return false
	for key in ["type", "properties", "required", "items", "enum", "anyOf", "allOf", "oneOf", "$ref", "$defs", "definitions", "additionalProperties", "const"]:
		if value.has(key):
			return true
	return false

func _unwrap_schema_envelope(candidate):
	var current = candidate
	for i in range(8):
		if not (current is Dictionary):
			return current
		if _looks_like_json_schema(current):
			return current
		if not current.has("schema"):
			return current
		var nested = current.get("schema", null)
		if not (nested is Dictionary):
			return current
		current = nested
	return current

func _build_response_format_from_schema_entry(schema_entry: Dictionary) -> Dictionary:
	var schema_name = str(schema_entry.get("name", "")).strip_edges()
	if schema_name == "":
		return {}
	var schema_source = null
	if schema_entry.get("sanitizedSchema", null) is Dictionary:
		schema_source = schema_entry.get("sanitizedSchema", null)
	elif schema_entry.get("resolvedSchema", null) is Dictionary:
		schema_source = schema_entry.get("resolvedSchema", null)
	elif schema_entry.get("schema", null) is Dictionary:
		schema_source = schema_entry.get("schema", null)
	if not (schema_source is Dictionary):
		return {}
	schema_source = _unwrap_schema_envelope(schema_source)
	if not (schema_source is Dictionary):
		return {}
	var sanitize_report = SchemaAlignOpenAI.sanitize_envelope_or_schema_with_report(schema_source)
	if not bool(sanitize_report.get("ok", false)):
		return {}
	var schema_envelope = sanitize_report.get("result", {})
	if not (schema_envelope is Dictionary):
		return {}
	var sanitized_schema = schema_envelope.get("schema", null)
	if not (sanitized_schema is Dictionary):
		return {}
	sanitized_schema = _unwrap_schema_envelope(sanitized_schema)
	if not (sanitized_schema is Dictionary):
		return {}
	var validation_result = JsonSchemaValidator.validate_schema(sanitized_schema)
	if not bool(validation_result.get("ok", false)):
		return {}
	return {
		"type": "json_schema",
		"json_schema": {
			"name": _completion_schema_name_to_api_name(schema_name),
			"strict": true,
			"schema": sanitized_schema
		}
	}

func _get_openai_valid_schema_options() -> Array:
	var output = []
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node == null:
		return output
	var schemas = ft_node.get("SCHEMAS")
	if schemas == null:
		schemas = []
	if not (schemas is Array):
		return output
	for schema_entry in schemas:
		if not (schema_entry is Dictionary):
			continue
		var schema_name = str(schema_entry.get("name", "")).strip_edges()
		if schema_name == "":
			continue
		var response_format = _build_response_format_from_schema_entry(schema_entry)
		if response_format.size() == 0:
			continue
		output.append({
			"schema_name": schema_name,
			"response_format": response_format
		})
	return output

func _refresh_schema_completion_mode_options() -> void:
	var mode_btn = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn
	_apply_completion_controls_layout()
	mode_btn.clear()
	_schema_completion_options = _get_openai_valid_schema_options()
	for i in range(_schema_completion_options.size()):
		var schema_name = str(_schema_completion_options[i].get("schema_name", ""))
		mode_btn.add_item("Mit " + schema_name + " Auto-Vervollständigen", i)
	mode_btn.select(-1)

func _pop_pending_completion_context() -> Dictionary:
	if _pending_completion_contexts.size() == 0:
		return {}
	var context = _pending_completion_contexts[0]
	_pending_completion_contexts.remove_at(0)
	if context is Dictionary:
		return context
	return {}

func _make_received_json_message(schema_name: String, json_text: String) -> Dictionary:
	return {
		"role": "assistant",
		"type": "JSON",
		"textContent": "",
		"unpreferredTextContent": "",
		"preferredTextContent": "",
		"imageContent": "",
		"functionName": "",
		"functionParameters": [],
		"functionResults": "",
		"functionUsePreText": "",
		"jsonSchemaValue": json_text,
		"jsonSchemaName": schema_name
	}

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
	var completion_context = _pop_pending_completion_context()
	var forced_schema_name = str(completion_context.get("schema_name", "")).strip_edges()
	if forced_schema_name != "":
		var forced_json_content = _message_content_to_text(message["content"])
		RecvMsgVar = _make_received_json_message(forced_schema_name, forced_json_content)
	elif message["tool_calls"] is Array and len(message["tool_calls"]) > 0:
		# This is a tool call message from the assistant
		## Get the preFunctionMessage
		var preFunctionText = ""
		if message["content"]:
			preFunctionText = _message_content_to_text(message["content"])
		## Unpack the parameters
		var parametersFromAssistantDict = JSON.parse_string(message["tool_calls"][0]["function"]["arguments"])
		if not (parametersFromAssistantDict is Dictionary):
			parametersFromAssistantDict = {}
		var parametersForFTC = []
		for parameterFromToolCallKey in parametersFromAssistantDict:
			var parameterFromToolCallValue = parametersFromAssistantDict[parameterFromToolCallKey]
			var parameterType = get_tree().get_root().get_node("FineTune").get_function_parameter_type(message["tool_calls"][0]["function"]["name"], parameterFromToolCallKey)
			var isParameterEnum = get_tree().get_root().get_node("FineTune").is_function_parameter_enum(message["tool_calls"][0]["function"]["name"], parameterFromToolCallKey)
			if parameterType == "String":
				if isParameterEnum:
					parametersForFTC.append({"name": parameterFromToolCallKey, "isUsed": true, "parameterValueChoice": parameterFromToolCallValue, "parameterValueText": "", "parameterValueNumber": 0})
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
		var text_content = _message_content_to_text(message["content"])
		RecvMsgVar = {
			"role": "assistant",
			"type": "Text",
			"textContent": text_content,
			"unpreferredTextContent": text_content,
			"preferredTextContent": "",
			"imageContent": "",
			"functionName": "",
			"functionParameters": [],
			"functionResults": "",
			"functionUsePreText": ""
		}
	MessageInstance.from_var(RecvMsgVar)
	_on_something_happened_to_check_enabled_status()

func _extract_openai_error_message(response: Dictionary) -> String:
	var error_data = response.get("error", {})
	if error_data is Dictionary:
		var explicit_message = str(error_data.get("message", "")).strip_edges()
		if explicit_message != "":
			return explicit_message
	var response_code = int(response.get("response_code", 0))
	if response_code <= 0:
		response_code = int(response.get("http_code", 0))
	if response_code > 0:
		return "OpenAI completion failed (HTTP " + str(response_code) + ")."
	return "OpenAI completion failed."

func _on_gpt_response_failed(response: Dictionary) -> void:
	if _pending_completion_contexts.size() > 0:
		_pending_completion_contexts.remove_at(0)
	push_error(_extract_openai_error_message(response))
	_on_something_happened_to_check_enabled_status()

func messages_to_openai_format():
	var ftc_messages = self.to_var()
	var openai_messages = []
	for m in ftc_messages:
		var nm = Message.new()
		nm.set_role(m["role"])
		nm.set_content(m["textContent"])
		openai_messages.append(nm)
	return openai_messages

func _build_completion_message_payload() -> Dictionary:
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
		new_ftc_messages.append(msg)
	ftc_messages = new_ftc_messages
	var openai_messages:Array[Message] = []
	# Check if a global system message needs to be used, and if so, add it before working with the message list
	if settings.get("useGlobalSystemMessage", false):
		var global_system_message = settings.get("globalSystemMessage", "")
		if global_system_message == null:
			global_system_message = ""
		var gsm = Message.new()
		gsm.set_role("system")
		gsm.set_content(str(global_system_message))
		openai_messages.append(gsm)
	var current_msg_ix = 0
	for m in ftc_messages:
		var nm = Message.new()
		nm.set_role(m["role"])
		if settings.get("useUserNames", false) and str(m.get("role", "")) == "user":
			var user_name = str(m.get("userName", "")).strip_edges()
			if user_name != "":
				nm.set_user_name(user_name)
		match m["type"]:
			"Text":
				var text_content = m.get("textContent", "")
				if text_content == null:
					text_content = ""
				nm.set_content(str(text_content))
				openai_messages.append(nm)
			"Image":
				nm.add_image_content(str(m.get("imageContent", "")), image_detail_map[m.get("imageDetail", 0)])
				openai_messages.append(nm)
			"Audio":
				nm.add_audio_content(str(m.get("audioData", "")), str(m.get("audioFiletype", "")))
				openai_messages.append(nm)
			"PDF File":
				nm.add_pdf_content(str(m.get("fileMessageData", "")), str(m.get("fileMessageName", "")))
				openai_messages.append(nm)
			"JSON", "JSON Schema":
				var json_content = m.get("jsonSchemaValue", "")
				if json_content == null:
					json_content = ""
				nm.set_content(str(json_content))
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
				var function_pre_text = str(m.get("functionUsePreText", ""))
				if function_pre_text != "":
					tool_call_message.add_text_content(function_pre_text)
				var tool_response_message = Message.new()
				tool_response_message.create_tool_response(call_id, str(m.get("functionResults", "")))
				openai_messages.append(tool_call_message)
				openai_messages.append(tool_response_message)
		current_msg_ix += 1
	var toolsforopenAI = []
	var functions_list_node = get_tree().get_root().get_node_or_null("FineTune/Conversation/Functions/FunctionsList")
	if functions_list_node != null and functions_list_node.has_method("functions_list_to_gpt_available_tools_list"):
		toolsforopenAI = functions_list_node.functions_list_to_gpt_available_tools_list()
	return {
		"messages": openai_messages,
		"model": settings.get("modelChoice", "gpt-4o-mini"),
		"tools": toolsforopenAI
	}

func _request_completion(schema_name: String = "", response_format_override: Dictionary = {}) -> void:
	var completion_payload = _build_completion_message_payload()
	var openai_messages = completion_payload.get("messages", [])
	var model = str(completion_payload.get("model", "gpt-4o-mini"))
	var toolsforopenAI = completion_payload.get("tools", [])
	var response_format = response_format_override
	if schema_name != "" and response_format.size() == 0:
		_refresh_schema_completion_mode_options()
		for option in _schema_completion_options:
			if str(option.get("schema_name", "")) == schema_name:
				var option_response_format = option.get("response_format", {})
				if option_response_format is Dictionary:
					response_format = option_response_format
				break
	if schema_name != "" and response_format.size() == 0:
		push_error("Schema-basierte Vervollständigung nicht möglich, da das Schema nicht OpenAI-valide ist: " + schema_name)
		return
	_pending_completion_contexts.append({"schema_name": schema_name})
	print(model)
	for m in openai_messages:
		print(m.content)
	openai.prompt_gpt(openai_messages, model, "", toolsforopenAI, response_format)

func _on_add_message_completion_button_pressed() -> void:
	if check_autocomplete_disabled_status():
		_on_something_happened_to_check_enabled_status()
		return
	_request_completion()

func check_autocomplete_disabled_status():
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node == null:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_OPENAI_API_KEY")
		return true
	var settings = ft_node.get("SETTINGS")
	if not (settings is Dictionary):
		settings = {}
	if str(settings.get("apikey", "")) == "":
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_OPENAI_API_KEY")
		return true
	if len(self.to_var()) < 1:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_NEEDS_AT_LEAST_ONE_MESSAGE")
		return true
	if ft_node.has_method("exists_function_without_name") and ft_node.exists_function_without_name():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_WITHOUT_NAME_EXISTS")
		return true
	if ft_node.has_method("exists_function_without_description") and ft_node.exists_function_without_description():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_WITHOUT_DESCRIPTION_EXISTS")
		return true
	if ft_node.has_method("exists_parameter_without_name") and ft_node.exists_parameter_without_name():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_PARAMETER_WITHOUT_NAME_EXISTS")
		return true
	if ft_node.has_method("exists_parameter_without_description") and ft_node.exists_parameter_without_description():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("DISABLED_EXPLANATION_DISABLED_AS_LONG_AS_FUNCTION_PARAMETER_WITTHOUT_DESCRIPTION_EXISTS")
		return true
	$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text = tr("MESSAGE_LIST_ASK_OPENAI_API_FOR_ANSWER")
	return false

func check_schema_autocomplete_disabled_status():
	var mode_btn = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn
	if check_autocomplete_disabled_status():
		mode_btn.tooltip_text = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.tooltip_text
		return true
	_refresh_schema_completion_mode_options()
	if _schema_completion_options.size() == 0:
		mode_btn.tooltip_text = "Keine OpenAI-validen Schemas verfügbar"
		return true
	mode_btn.tooltip_text = "Schema-basierte Auto-Vervollständigung"
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
	if check_autocomplete_disabled_status():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = true
	else:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionButton.disabled = false
	if check_schema_autocomplete_disabled_status():
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn.disabled = true
	else:
		$MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn.disabled = false

func _on_add_message_completion_button_mouse_entered() -> void:
	_on_something_happened_to_check_enabled_status()

func _on_add_message_completion_mode_btn_pressed() -> void:
	_on_something_happened_to_check_enabled_status()

func _on_add_message_completion_mode_btn_item_selected(index: int) -> void:
	var mode_btn = $MessagesListContainer/AddButtonsContainer/AddMessageCompletionModeBtn
	if index < 0:
		return
	var selected_option_id = mode_btn.get_item_id(index)
	mode_btn.select(-1)
	if selected_option_id < 0 or selected_option_id >= _schema_completion_options.size():
		return
	var selected_option = _schema_completion_options[selected_option_id]
	var schema_name = str(selected_option.get("schema_name", "")).strip_edges()
	var response_format = selected_option.get("response_format", {})
	if schema_name == "":
		return
	if not (response_format is Dictionary):
		return
	if response_format.size() == 0:
		return
	_request_completion(schema_name, response_format)

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
				await ft_node.request_load_project_from_path_with_unsaved_guard(file)
			else:
				var json_text = FileAccess.get_file_as_string(file)
				var parsed = JSON.parse_string(json_text)
				if parsed is Dictionary and parsed.has("functions") and parsed.has("conversations") and parsed.has("settings"):
					await ft_node.request_load_project_from_path_with_unsaved_guard(file)
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
