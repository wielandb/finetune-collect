extends HBoxContainer
@onready var result_parameters_scene = preload("res://scenes/function_call_results_parameter.tscn")
@onready var function_use_parameters_scene = preload("res://scenes/function_use_parameter.tscn")
@onready var imageTexture = $ImageMessageContainer/TextureRect


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
	me["imageContent"] = $ImageMessageContainer/Base64ImageEdit.text
	me["functionName"] = ""
	if $FunctionMessageContainer/function/FunctionNameChoiceButton.selected != -1:
		me["functionName"] = $FunctionMessageContainer/function/FunctionNameChoiceButton.get_item_text($FunctionMessageContainer/function/FunctionNameChoiceButton.selected)
	var tmpFunctionParameters = []
	for parameter in $FunctionMessageContainer.get_children():
		if parameter.is_in_group("function_use_parameter"):
			tmpFunctionParameters.append(parameter.to_var())
	me["functionParameters"] = tmpFunctionParameters
	var tmpFunctionResults = []
	for result in $FunctionMessageContainer.get_children():
		print("Inspecting Function Message Container")
		if result.is_in_group("function_use_result"):
			print("It was a function use result")
			tmpFunctionResults.append(result.to_var())
	me["functionResults"] = tmpFunctionResults
	return me

func from_var(data):
	print("Building from var")
	print(data)
	$MessageSettingsContainer/Role.select(selectionStringToIndex($MessageSettingsContainer/Role, data["role"]))
	_on_role_item_selected($MessageSettingsContainer/Role.selected)
	$MessageSettingsContainer/MessageType.select(selectionStringToIndex($MessageSettingsContainer/MessageType, data["type"]))
	_on_message_type_item_selected($MessageSettingsContainer/MessageType.selected)
	$TextMessageContainer/Message.text = data["textContent"]
	$ImageMessageContainer/Base64ImageEdit.text = data["imageContent"]
	# If not empty, create the image from the base64
	if $ImageMessageContainer/Base64ImageEdit.text != "":
		base64_to_image(imageTexture, $ImageMessageContainer/Base64ImageEdit.text)
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	for d in data["functionParameters"]:
		var parameterInstance = function_use_parameters_scene.instantiate()
		$FunctionMessageContainer.add_child(parameterInstance)
		var parameterSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel.get_index()
		$FunctionMessageContainer.move_child(parameterInstance, parameterSectionLabelIx)
		parameterInstance.from_var(d)
	# Act as if the function select was pressed if its not empty
	if data["functionName"] != "":
		_on_function_name_choice_button_item_selected(selectionStringToIndex($FunctionMessageContainer/function/FunctionNameChoiceButton, data["functionName"]))
	for d in data["functionResults"]:
		var resultInstance = result_parameters_scene.instantiate()
		$FunctionMessageContainer.add_child(resultInstance)
		var resultsSectionLabelIx = $FunctionMessageContainer/ParamterSectionLabel2.get_index()
		$FunctionMessageContainer.move_child(resultInstance, resultsSectionLabelIx)
		resultInstance.from_var(d)
		
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Init Message object")
	for item in get_node("/root/FineTune").get_available_function_names():
		$FunctionMessageContainer/function/FunctionNameChoiceButton.add_item(item)
	$FunctionMessageContainer/function/FunctionNameChoiceButton.select(-1)


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
	$ImageMessageContainer/FileDialog.visible = true


func _on_delete_button_pressed() -> void:
	queue_free()


func _on_add_result_button_pressed() -> void:
	var newResultParameter = result_parameters_scene.instantiate()
	$FunctionMessageContainer.add_child(newResultParameter)
	var addResultButton = $FunctionMessageContainer/AddResultButton
	$FunctionMessageContainer.move_child(addResultButton, -1)



func _on_role_item_selected(index: int) -> void:
	$MessageSettingsContainer/MessageType.set_item_disabled(0, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(1, true)
	$MessageSettingsContainer/MessageType.set_item_disabled(2, true)
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
	
func _on_something_string_changed(new_text: String) -> void:
	update_messages_global()


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				$ImageMessageContainer/TextureRect.custom_minimum_size.y = 900
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				$ImageMessageContainer/TextureRect.custom_minimum_size.y = 0
