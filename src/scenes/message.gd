extends HBoxContainer
@onready var result_parameters_scene = preload("res://scenes/function_call_results_parameter.tscn")
@onready var function_use_parameters_scene = preload("res://scenes/function_use_parameter.tscn")
@onready var imageTexture = $ImageMessageContainer/TextureRect

var image_access_web = FileAccessWeb.new()

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
	return me

func from_var(data):
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	print("Building from var")
	print(data)
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, data["role"]))
	_on_role_item_selected($MessageSettingsContainer/Role.selected)
	$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, data["type"]))
	_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
	$TextMessageContainer/Message.text = data["textContent"]
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
	$ImageMessageContainer/Base64ImageEdit.text = data["imageContent"]
	# If not empty, create the image from the base64
	if $ImageMessageContainer/Base64ImageEdit.text != "":
		base64_to_image(imageTexture, $ImageMessageContainer/Base64ImageEdit.text)
	if data.has("imageDetail"):
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(data["imageDetail"])
	else: # TODO: Add option what the standard quality should be
		$ImageMessageContainer/HBoxContainer/ImageDetailOptionButton.select(0)
	# Now everything regarding functions
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	#if data["functionName"] != "":
	#	_on_function_name_choice_button_item_selected(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	for d in data["functionParameters"]:
		var parameterInstance = function_use_parameters_scene.instantiate()
		$FunctionMessageContainer.add_child(parameterInstance)
		var parameterSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel.get_index()
		$FunctionMessageContainer.move_child(parameterInstance, parameterSectionLabelIx)
		parameterInstance.from_var(d)
	$FunctionMessageContainer/FunctionUseResultText.text = str(data["functionResults"])
	$FunctionMessageContainer/preFunctionCallTextContainer/preFunctionCallTextEdit.text = str(data.get("functionUsePreText", ""))
	_on_check_what_text_message_should_be_visisble()
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
	match index:
		0:
			$TextMessageContainer.visible = true
		1:
			$ImageMessageContainer.visible = true
		2:
			$FunctionMessageContainer.visible = true


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
	var finetunetype = get_node("/root/FineTune").SETTINGS.get("finetuneType", 0)
	match finetunetype:
		0:
			match index:
				0:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
				1:
					$MessageSettingsContainer/MessageType.set_item_disabled(1, false)
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
				2:
					$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
					# Only make functions available if there are any
					if len(get_node("/root/FineTune").get_available_function_names()) > 0:
						$MessageSettingsContainer/MessageType.set_item_disabled(2, false)
		1:
			# In DPO, there is only text messages
			$MessageSettingsContainer/MessageType.set_item_disabled(0, false)
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
