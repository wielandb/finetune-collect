extends HBoxContainer

var FINETUNEDATA = {}
var FUNCTIONS = []
var CONVERSATIONS = {}
var SETTINGS = {
	"apikey": "",
	"useGlobalSystemMessage": false,
	"globalSystemMessage": "",
	"modelChoice": "gpt-4o",
	"availableModels": []
	}

var RUNTIME = {"filepath": ""}

var CURRENT_EDITED_CONVO_IX = "FtC1"

var file_access_web = FileAccessWeb.new()
# FINETUNEDATA = 
# { functions: [],
#   settings: {
#     "use_global_system_message": true,
#     "global_system_message": "You are a helpful assistant!",
#
#	},
#   conversations: [CONVERSATION1],

# CONVERSATION1 = { 

func getRandomConvoID(length: int) -> String:
	var ascii_letters_and_digits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	while true:
		var result = ""
		for i in range(length):
			result += ascii_letters_and_digits[randi() % ascii_letters_and_digits.length()]
		if result not in CONVERSATIONS:
			return result
	return "----" # We will never get here but Godot needs it to be happy

func selectionStringToIndex(node, string):
	# takes a node (OptionButton) and a String that is one of the options and returns its index
	# TODO: Check if OptionButton
	for i in range(node.item_count):
		if node.get_item_text(i) == string:
			return i
	return -1

func getallnodes(node):
	var nodeCollection = []
	for N in node.get_children():
		if N.get_child_count() > 0:
			print("["+N.get_name()+"]")
			getallnodes(N)
		else:
			nodeCollection.append(N)
	return nodeCollection

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_button_pressed()
	refresh_conversations_list()
	_on_item_list_item_selected(0)
	delete_conversation("FtC1") # A janky workaround for the startup sequence
	refresh_conversations_list()
	_on_item_list_item_selected(0)
	file_access_web.loaded.connect(_on_file_loaded)
	file_access_web.progress.connect(_on_upload_progress)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("save"):
		print("Würde jetzt speichern...")
		save_current_conversation()
		update_functions_internal()
		update_settings_internal()
		if RUNTIME["filepath"] == "":
			$VBoxContainer/SaveBtn/SaveFileDialog.visible = true
		else:
			save_as_appropriate_from_path(RUNTIME["filepath"])
			var first_message_container = $Conversation/Messages/MessagesList/MessagesListContainer.get_child(0)
			if first_message_container.is_in_group("message") and SETTINGS.get("countTokensWhen") == 0:
				first_message_container._do_token_calculation_update()
		refresh_conversations_list()
	if Input.is_action_just_released("load"):
		$VBoxContainer/LoadBtn/FileDialog.visible = true
	#	if RUNTIME["filepath"] == "":
	#		$VBoxContainer/SaveBtn/SaveFileDialog.visible = true
	#	else:
	#		save_as_appropriate_from_path(RUNTIME["filepath"])


func _on_save_btn_pressed() -> void:
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			$VBoxContainer/SaveBtn/SaveFileDialog.visible = true
		"Web":
			var json_save_data =  make_save_json_data()
			var byte_array = json_save_data.to_utf8_buffer()
			JavaScriptBridge.download_buffer(byte_array, "fine_tune_project.json", "text/plain")

func update_functions_internal():
	FUNCTIONS = $Conversation/Functions/FunctionsList.to_var()

func update_settings_internal():
	SETTINGS = $Conversation/Settings/ConversationSettings.to_var()
	print("Settings: ")
	print(SETTINGS)
func get_available_function_names():
	var tmpNames = []
	for f in FUNCTIONS:
		tmpNames.append(f["name"])
	return tmpNames
	
func get_available_parameter_names_for_function(fname: String):
	update_functions_internal()
	var tmpParameterNames = []
	for f in FUNCTIONS:
		if f["name"] == fname:
			for p in f["parameters"]:
				tmpParameterNames.append(p["name"])
	return tmpParameterNames

func update_available_functions_in_UI_global():
	print("Updating UI...")
	for node in get_tree().get_nodes_in_group("UI_needs_function_list"):
		print("Found a UI element that needs Updating")
		node.clear()
		for f in get_available_function_names():
			node.add_item(f)


func _on_item_list_item_selected(index: int) -> void:
	update_functions_internal()
	print("Available Function Names:")
	print(get_available_function_names())
	print("Functions: ")
	print(FUNCTIONS)
	update_available_functions_in_UI_global()
	save_current_conversation()
	# Alle Nachrichten löschen
	for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()	
	# Und die neuen aus der Convo laden
	CURRENT_EDITED_CONVO_IX = $VBoxContainer/ConversationsList.get_item_tooltip(index)
	# Create conversation if it does not exist
	print("IX:")
	print(CURRENT_EDITED_CONVO_IX)
	DisplayServer.window_set_title("finetune-collect - Current conversation: " + CURRENT_EDITED_CONVO_IX)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[str(CURRENT_EDITED_CONVO_IX)])
	


func save_current_conversation_to_conversations_at_index(ix: int):
	# THERE SHOULD BE NO REASON TO USE THIS FUNCTION
	CONVERSATIONS[ix] = $Conversation/Messages/MessagesList.to_var()

func save_current_conversation():
	CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = $Conversation/Messages/MessagesList.to_var()

func _on_load_btn_pressed() -> void:
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			$VBoxContainer/LoadBtn/FileDialog.visible = true
		"Web":
			file_access_web.open(".json")

func _on_file_loaded(file_name: String, file_type: String, base64_data: String) -> void:
	# A finetune project file was loaded via web
	var json_text_data = Marshalls.base64_to_utf8(base64_data)
	load_from_json_data(json_text_data)
	
	
func _on_upload_progress(current_bytes: int, total_bytes: int) -> void:
	pass

func is_function_parameter_required(function_name, parameter_name):
	print("Performing parameter required check!")
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					print("Paramter required check:")
					print(parameter)
					return parameter["isRequired"]
	print("is_function_parameter_required could not find parameter " + str(parameter_name) + " for function " + function_name + ". I mean, I will be returning false, but are you sure everythings alright?")
	return false

func is_function_parameter_enum(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					if parameter["isEnum"]:
						return true
	return false
	
func get_function_parameter_enums(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					if parameter["isEnum"]:
						return str(parameter["enumOptions"]).split(",", false)
	return []

func get_function_parameter_type(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					return parameter["type"]
	return "None"

func get_function_definition(function_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			return function
	return {}

func get_parameter_def(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					return parameter
	return {}

## Functions to check if invalid definitions exist

func exists_function_without_name():
	for function in FUNCTIONS:
		if function["name"] == "":
			return true
	return false

func exists_function_without_description():
	for function in FUNCTIONS:
		if function["description"] == "":
			return true
	return false

func exists_parameter_without_name():
	for function in FUNCTIONS:
			for parameter in function["parameters"]:
				if parameter["name"] == "":
					return true

func exists_parameter_without_description():
	for function in FUNCTIONS:
			for parameter in function["parameters"]:
				if parameter["description"] == "":
					return true

## -- End of functions to check if invalid definitions exist

func check_is_conversation_problematic(idx: String):
	var thisconvo = CONVERSATIONS[idx]
	var finetunetype = SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		# DPO: First message user, second message assistant (with meta message 3 messages)
		var metamessageoffset = 0
		if thisconvo[0]["role"] == "meta" or thisconvo[0]["type"] == "meta":
			metamessageoffset = 1
		if len(thisconvo) != 2 + metamessageoffset:
			return true
		if len(thisconvo) >= 1 + metamessageoffset:
			if thisconvo[0 + metamessageoffset]["role"] != "user":
				return true
		if len(thisconvo) >= 2 + metamessageoffset:
			if thisconvo[1 + metamessageoffset]["role"] != "assistant":
				return true
		if thisconvo[0 + metamessageoffset]["textContent"] == "":
			return true
		if thisconvo[1 + metamessageoffset]["preferredTextContent"] == "" or thisconvo[1 + metamessageoffset]["unpreferredTextContent"] == "":
			return true
		return false
	elif finetunetype == 2:
		# Check that the last message is assistant and JSON Schema or Function Call
		if thisconvo[-1]["role"] != "assistant":
			return true
		if thisconvo[-1]["type"] != "Function Call" and thisconvo[-1]["type"] != "JSON Schema":
			return true
	# Check if at least two messages exist
	if len(thisconvo) < 2:
		return true
	# Check if all text messages contain non-empty text content
	for m in thisconvo:
		if m["type"] == "Text" and m["textContent"] == "":
			return true
	# Check if all image messages contain non-empty image content
	for m in thisconvo:
		if m["type"] == "Image" and m["imageContent"] == "":
			return true
	# Check if all function call messages contain non-empty functionNames
	for m in thisconvo:
		if m["type"] == "Function Call" and m["functionName"] == "":
			return true
	# Check if at least one message is from the assistant
	var hasAssistantMessage = false
	for m in thisconvo:
		if m["role"] == "assistant":
			hasAssistantMessage = true
	if not hasAssistantMessage:
		return true
	return false
	
func check_is_conversation_ready(idx: String) -> bool:
	var thisconvo = CONVERSATIONS[idx]
	for m in thisconvo:
		if m["type"] == "meta" and m.get("metaData", {}).get("ready", false) == true:
			return true
	return false

func _on_file_dialog_file_selected(path: String) -> void:
	if path.ends_with(".json"):
		load_from_json(path)
	elif path.ends_with(".ftproj"):
		load_from_binary(path)
	RUNTIME["filepath"] = path
	


func get_conversation_name_or_false(idx):
	var this_convo = CONVERSATIONS[idx]
	for msg in this_convo:
		if msg.get("type", "Text") == "meta":
			if msg.get("metaData", {}).get("conversationName", "") != "":
				return msg.get("metaData", {}).get("conversationName", "")
	return false

func refresh_conversations_list():
	$VBoxContainer/ConversationsList.clear()
	var numberIx = -1
	for i in CONVERSATIONS.keys():
		numberIx += 1
		var conversation_name = i
		if get_conversation_name_or_false(i):
			conversation_name = get_conversation_name_or_false(i)
		if check_is_conversation_problematic(i):
			$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-remove-custom.png"))
		else:
			if check_is_conversation_ready(i):
				$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-check.png"))
			else:
				$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-custom.png"))
		$VBoxContainer/ConversationsList.set_item_tooltip(numberIx, i)

func _on_conversation_tab_changed(tab: int) -> void:
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()


func create_new_conversation(msgs=[]):
	# Generate a new ConvoID
	var newID = getRandomConvoID(4)
	CONVERSATIONS[newID] = msgs
	# Update everything that needs to be updated
	refresh_conversations_list()

func append_to_conversation(convoid, msg={}):
	if convoid in CONVERSATIONS:
		CONVERSATIONS[convoid].append(msg)
	else:
		print("Error: No such conversation" + str(convoid))

func _on_button_pressed() -> void:
	# Create conversation if it does not exist
	var finetunetype = SETTINGS.get("finetuneType", 0)
	if finetunetype == 0:
		create_new_conversation(
			[
				{"role": "meta", "type": "meta"}
			]
		)
	elif finetunetype == 1:
		# DPO: There is only one kind of conversation we can have here, so we can also just poulate it
		create_new_conversation([
			{ "role": "user", "type": "Text", "textContent": "", "unpreferredTextContent": "", "preferredTextContent": "", "imageContent": "", "imageDetail": 0, "functionName": "", "functionParameters": [], "functionResults": "", "functionUsePreText": ""},
			{ "role": "assistant", "type": "Text", "textContent": "", "unpreferredTextContent": "", "preferredTextContent": "", "imageContent": "", "imageDetail": 0, "functionName": "", "functionParameters": [], "functionResults": "", "functionUsePreText": ""}
			]
		)
	elif finetunetype == 2:
		create_new_conversation(
			[
				{"role": "meta", "type": "meta"}
			]
		)
	print(CONVERSATIONS)
	

func save_to_binary(filename):
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["settings"] = SETTINGS
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_var(FINETUNEDATA)
		file.close()
	else:
		print("file open failed")
	
func load_from_binary(filename):
	if FileAccess.file_exists(filename):
		print("save file found")
		var file = FileAccess.open(filename, FileAccess.READ)
		FINETUNEDATA = file.get_var()
		file.close()
		FUNCTIONS = FINETUNEDATA["functions"]
		CONVERSATIONS = FINETUNEDATA["conversations"]
		SETTINGS = FINETUNEDATA["settings"]
		for i in CONVERSATIONS.keys():
			CURRENT_EDITED_CONVO_IX = str(i)
		$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
		$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
		$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
		$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
		$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
		refresh_conversations_list()
		$VBoxContainer/ConversationsList.select(selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX))
	else:
		print("file not found")

func load_from_json_data(jsondata: String):
	var json_as_dict = JSON.parse_string(jsondata)
	print(json_as_dict)
	# Unload all UI
	$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
	$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
	FINETUNEDATA = json_as_dict
	FUNCTIONS = FINETUNEDATA["functions"]
	CONVERSATIONS = FINETUNEDATA["conversations"]
	SETTINGS = FINETUNEDATA["settings"]
	for i in CONVERSATIONS.keys():
		CURRENT_EDITED_CONVO_IX = str(i)
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
	refresh_conversations_list()
	$VBoxContainer/ConversationsList.select(selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX))

func make_save_json_data():
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["settings"] = SETTINGS
	var jsonstr = JSON.stringify(FINETUNEDATA, "\t", false)
	return jsonstr

func save_to_json(filename):
	var file = FileAccess.open(filename, FileAccess.WRITE)
	var jsonstr = make_save_json_data()
	file.store_string(jsonstr)
	file.close()
	
func load_from_json(filename):
	# loads from a given file name
	var json_as_text = FileAccess.get_file_as_string(filename)
	load_from_json_data(json_as_text)

func save_as_appropriate_from_path(path):
	if path.ends_with(".json"):
		save_to_json(path)
	elif path.ends_with(".ftproj"):
		save_to_binary(path)
	else:
		print("Konnte nicht speichern, da unbekanntes format")

func load_from_appropriate_from_path(path):
	if path.ends_with(".json"):
		load_from_json(path)
	elif path.ends_with(".ftproj"):
		load_from_binary(path)
	else:
		print("Konnte nicht laden, da unbekanntes format")


func _on_save_file_dialog_file_selected(path: String) -> void:
	if path.ends_with(".json"):
		save_to_json(path)
	elif path.ends_with(".ftproj"):
		save_to_binary(path)
	RUNTIME["filepath"] = path

func delete_conversation(ixStr: String):
	CONVERSATIONS.erase(ixStr)
	# If we were currently editing this conversation, unload it
	if CURRENT_EDITED_CONVO_IX == ixStr:
		for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
			if message.is_in_group("message"):
				message.queue_free()
		# Select a random conversation that we will now be editing
		for c in CONVERSATIONS.keys():
			CURRENT_EDITED_CONVO_IX = c
			$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
			refresh_conversations_list()
			$VBoxContainer/ConversationsList.select(selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX))
			break
	refresh_conversations_list()
	print(CONVERSATIONS)

func get_ItemList_selected_Item_index(node: ItemList) -> int:
	for i in range(node.item_count):
		if node.is_selected(i):
			return i
	return -1

func _on_conversations_list_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == 4194312:
			# Go through every entry and check if it is selected
			for i in range($VBoxContainer/ConversationsList.item_count):
				if $VBoxContainer/ConversationsList.is_selected(i):
					delete_conversation($VBoxContainer/ConversationsList.get_item_tooltip(get_ItemList_selected_Item_index($VBoxContainer/ConversationsList)))
		if event.pressed and Input.is_key_pressed(KEY_CTRL) and event.keycode == KEY_D:
			for i in range($VBoxContainer/ConversationsList.item_count):
				if $VBoxContainer/ConversationsList.is_selected(i):
					var newConvoID = getRandomConvoID(4)
					var origConvoID = $VBoxContainer/ConversationsList.get_item_text(get_ItemList_selected_Item_index($VBoxContainer/ConversationsList))
					CONVERSATIONS[newConvoID] = CONVERSATIONS[origConvoID]
					refresh_conversations_list()
					

func _on_collapse_burger_btn_pressed() -> void:
	$VBoxContainer.visible = false
	$CollapsedMenu.visible = true

func _on_expand_burger_btn_pressed() -> void:
	$VBoxContainer.visible = true
	$CollapsedMenu.visible = false

func create_jsonl_data_for_file():
	var EFINETUNEDATA = {} # EFINETUNEDATA -> ExportFinetuneData (so that we don't remove anything from the save file on export)
	EFINETUNEDATA["functions"] = FUNCTIONS.duplicate(true)
	var allconversations = CONVERSATIONS.duplicate(true)
	var unproblematicconversations = {}
	# Check all conversations and only add unproblematic ones
	# Check what the settings say about what to export
	var whatToExport = SETTINGS.get("exportConvo", 0)
	# 0 -> only unproblematic, 1 -> only ready, 2 -> all
	for convokey in allconversations:
		if whatToExport == 0:
			if not check_is_conversation_problematic(convokey):
				unproblematicconversations[convokey] = CONVERSATIONS[convokey]
		elif whatToExport == 1:
			if not check_is_conversation_problematic(convokey) and check_is_conversation_ready(convokey):
				unproblematicconversations[convokey] = CONVERSATIONS[convokey]
		elif whatToExport == 2:
			unproblematicconversations[convokey] = CONVERSATIONS[convokey]
	EFINETUNEDATA["conversations"] = unproblematicconversations
	EFINETUNEDATA["settings"] = SETTINGS.duplicate(true)
	var complete_jsonl_string = ""
	match SETTINGS.get("finetuneType", 0):
		0:
			complete_jsonl_string = await $Exporter.convert_fine_tuning_data(EFINETUNEDATA)
		1:
			complete_jsonl_string = $Exporter.convert_dpo_data(EFINETUNEDATA)
		2:
			complete_jsonl_string = $Exporter.convert_rft_data(EFINETUNEDATA)
	return complete_jsonl_string


func _on_export_btn_pressed() -> void:
	# If we are on the web, different things need to happen
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			$VBoxContainer/ExportBtn/ExportFileDialog.visible = true
		"Web":
			# When we are on web, we need to download the file directly
			var complete_jsonl_string = await create_jsonl_data_for_file()
			var byte_array = complete_jsonl_string.to_utf8_buffer()
			JavaScriptBridge.download_buffer(byte_array, "fine_tune.jsonl", "text/plain")
	

func _on_export_file_dialog_file_selected(path: String) -> void:
	var complete_jsonl_string = await create_jsonl_data_for_file()
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(complete_jsonl_string)
	file.close()


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


func get_number_of_images_for_conversation(convoIx):
	var image_count = 0
	for message in CONVERSATIONS[convoIx]:
		if message["type"] == "Image":
			image_count += 1
	return image_count

func get_number_of_images_total():
        var image_count = 0
        for convoIx in CONVERSATIONS:
                image_count += get_number_of_images_for_conversation(convoIx)
        return image_count

# Helper to create a Finetune-Collect function call message and ensure the
# function definition exists in the global FUNCTIONS array.
func _create_ft_function_call_msg(function_name: String, arguments_dict: Dictionary, function_result: String, pretext: String) -> Dictionary:
       var param_list := []
       for arg_name in arguments_dict.keys():
               var val = arguments_dict[arg_name]
               var entry = {
                       "name": str(arg_name),
                       "isUsed": true,
                       "parameterValueText": "",
                       "parameterValueChoice": "",
                       "parameterValueNumber": 0
               }
               match typeof(val):
                       TYPE_INT, TYPE_FLOAT:
                               entry["parameterValueNumber"] = val
                       _:
                               entry["parameterValueText"] = str(val)
               param_list.append(entry)

       var fn_exists = false
       for f in FUNCTIONS:
               if f.get("name", "") == function_name:
                       fn_exists = true
                       break
       if !fn_exists:
               var param_defs := []
               for arg_name in arguments_dict.keys():
                       var v = arguments_dict[arg_name]
                       var p_type = (typeof(v) in [TYPE_INT, TYPE_FLOAT]) ? "Number" : "String"
                       param_defs.append({
                               "type": p_type,
                               "name": str(arg_name),
                               "description": "",
                               "minimum": 0,
                               "maximum": 0,
                               "isEnum": false,
                               "hasLimits": false,
                               "enumOptions": "",
                               "isRequired": true
                       })
               FUNCTIONS.append({
                       "name": function_name,
                       "description": "",
                       "parameters": param_defs,
                       "functionExecutionEnabled": false,
                       "functionExecutionExecutable": "",
                       "functionExecutionArgumentsString": ""
               })

       return {
               "role": "assistant",
               "type": "Function Call",
               "textContent": "",
               "unpreferredTextContent": "",
               "preferredTextContent": "",
               "imageContent": "",
               "imageDetail": 0,
               "functionName": function_name,
               "functionParameters": param_list,
               "functionResults": function_result,
               "functionUsePreText": pretext
       }

# Extract text content from an OpenAI message which may contain either a string
# or an array with text parts.
func _extract_text_from_msg(msg: Dictionary) -> String:
       var text := ""
       if msg.has("content"):
               if msg["content"] is String:
                       text = msg["content"]
               elif msg["content"] is Array:
                       for p in msg["content"]:
                               if p.get("type", "") == "text":
                                       text += p.get("text", "")
       return text

# Simple JSON validity check used when importing OpenAI messages
func _validate_is_json(testtext) -> bool:
       if testtext == "":
               return false
       var json = JSON.new()
       var err = json.parse(testtext)
       if err == OK:
               return true
       return false
	
	
func conversation_from_openai_message_json(oaimsgjson):
       # Accept both a JSON string or an already parsed array
       if typeof(oaimsgjson) == TYPE_STRING:
               var parsed = JSON.parse_string(oaimsgjson)
               if parsed is Dictionary and parsed.has("messages"):
                       oaimsgjson = parsed["messages"]
               else:
                       oaimsgjson = parsed
       if typeof(oaimsgjson) != TYPE_ARRAY:
               return []

       var NEWCONVO = []
       var image_detail_map = {"high": 0, "low": 1, "auto": 2}
       var i := 0
       while i < oaimsgjson.size():
               var msg = oaimsgjson[i]
               var role = msg.get("role", "")
               var msg_type = msg.get("type", "")

               if role == "system" or role == "developer":
                       NEWCONVO.append({
                               "role": "assistant",
                               "type": "Text",
                               "textContent": msg.get("content", ""),
                               "unpreferredTextContent": "",
                               "preferredTextContent": "",
                               "imageContent": "",
                               "imageDetail": 0,
                               "functionName": "",
                               "functionParameters": [],
                               "functionResults": "",
                               "functionUsePreText": ""
                       })
               elif role == "user":
                       var content = msg.get("content")
                       if content is Array:
                               for piece in content:
                                       if piece.get("type", "") == "text":
                                               NEWCONVO.append({
                                                       "role": "user",
                                                       "type": "Text",
                                                       "textContent": piece.get("text", ""),
                                                       "unpreferredTextContent": "",
                                                       "preferredTextContent": "",
                                                       "imageContent": "",
                                                       "imageDetail": 0,
                                                       "functionName": "",
                                                       "functionParameters": [],
                                                       "functionResults": "",
                                                       "functionUsePreText": "",
                                                       "userName": msg.get("name", "")
                                               })
                                       elif piece.get("type", "") == "image_url":
                                               var url = piece["image_url"].get("url", "")
                                               var detail = image_detail_map.get(piece["image_url"].get("detail", "high"), 0)
                                               if url.begins_with("data:image/jpeg;base64,"):
                                                       url = url.replace("data:image/jpeg;base64,", "")
                                               NEWCONVO.append({
                                                       "role": "user",
                                                       "type": "Image",
                                                       "textContent": "",
                                                       "unpreferredTextContent": "",
                                                       "preferredTextContent": "",
                                                       "imageContent": url,
                                                       "imageDetail": detail,
                                                       "functionName": "",
                                                       "functionParameters": [],
                                                       "functionResults": "",
                                                       "functionUsePreText": "",
                                                       "userName": msg.get("name", "")
                                               })
                       else:
                               NEWCONVO.append({
                                       "role": "user",
                                       "type": "Text",
                                       "textContent": msg.get("content", ""),
                                       "unpreferredTextContent": "",
                                       "preferredTextContent": "",
                                       "imageContent": "",
                                       "imageDetail": 0,
                                       "functionName": "",
                                       "functionParameters": [],
                                       "functionResults": "",
                                       "functionUsePreText": "",
                                       "userName": msg.get("name", "")
                               })
               elif msg_type == "function_call":
                       var call_id = msg.get("call_id", msg.get("id", ""))
                       var function_name = msg.get("name", "")
                       var arguments_json = msg.get("arguments", "{}")
                       var arguments_dict = JSON.parse_string(arguments_json)
                       if arguments_dict == null:
                               arguments_dict = {}

                       var function_result = ""
                       if i + 1 < oaimsgjson.size():
                               var next_msg = oaimsgjson[i + 1]
                               if next_msg.get("type", "") == "function_call_output" and next_msg.get("call_id", "") == call_id:
                                       function_result = next_msg.get("output", "")
                                       i += 1

                       var pretext := ""
                       if NEWCONVO.size() > 0:
                               var last_msg = NEWCONVO[-1]
                               if last_msg.get("role", "") == "assistant" and last_msg.get("type", "") == "Text":
                                       pretext = last_msg.get("textContent", "")
                                       NEWCONVO.pop_back()

                       NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))

               elif role == "assistant":
                       if msg.has("tool_calls") and msg["tool_calls"].size() > 0:
                               var call = msg["tool_calls"][0]
                               var call_id = call.get("id", "")
                               var function_name = call["function"].get("name", "")
                               var arguments_json = call["function"].get("arguments", "{}")
                               var arguments_dict = JSON.parse_string(arguments_json)
                               if arguments_dict == null:
                                       arguments_dict = {}

                               var function_result = ""
                               if i + 1 < oaimsgjson.size():
                                       var nxt = oaimsgjson[i + 1]
                                       if nxt.get("role", "") == "tool" and nxt.get("tool_call_id", "") == call_id:
                                               function_result = nxt.get("content", "")
                                               i += 1

                               var pretext := _extract_text_from_msg(msg)
                               NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
                       elif msg.has("function_call"):
                               var fc = msg["function_call"]
                               var function_name = fc.get("name", "")
                               var arguments_json = fc.get("arguments", "{}")
                               var arguments_dict = JSON.parse_string(arguments_json)
                               if arguments_dict == null:
                                       arguments_dict = {}

                               var function_result = ""
                               if i + 1 < oaimsgjson.size():
                                       var nxt2 = oaimsgjson[i + 1]
                                       if nxt2.get("role", "") in ["function", "tool"] and nxt2.get("name", "") == function_name:
                                               function_result = nxt2.get("content", "")
                                               i += 1

                               var pretext := _extract_text_from_msg(msg)
                               NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
                       elif i + 1 < oaimsgjson.size() and oaimsgjson[i + 1].get("type", "") == "function_call":
                               var fcmsg = oaimsgjson[i + 1]
                               var call_id2 = fcmsg.get("call_id", fcmsg.get("id", ""))
                               var fname2 = fcmsg.get("name", "")
                               var ajson2 = fcmsg.get("arguments", "{}")
                               var adict2 = JSON.parse_string(ajson2)
                               if adict2 == null:
                                       adict2 = {}

                               var result2 = ""
                               if i + 2 < oaimsgjson.size():
                                       var outm = oaimsgjson[i + 2]
                                       if outm.get("type", "") == "function_call_output" and outm.get("call_id", "") == call_id2:
                                               result2 = outm.get("output", "")
                                               i += 1
                                               i += 1
                                       else:
                                               i += 1
                               else:
                                       i += 1

                               var pretext2 := _extract_text_from_msg(msg)
                               NEWCONVO.append(_create_ft_function_call_msg(fname2, adict2, result2, pretext2))
                               i += 1
                               continue
                       else:
                               var a_text := _extract_text_from_msg(msg)
                               if _validate_is_json(a_text):
                                       NEWCONVO.append({
                                               "role": "assistant",
                                               "type": "JSON Schema",
                                               "textContent": "",
                                               "unpreferredTextContent": "",
                                               "preferredTextContent": "",
                                               "imageContent": "",
                                               "imageDetail": 0,
                                               "functionName": "",
                                               "functionParameters": [],
                                               "functionResults": "",
                                               "functionUsePreText": "",
                                               "jsonSchemaValue": a_text
                                       })
                               else:
                                       NEWCONVO.append({
                                               "role": "assistant",
                                               "type": "Text",
                                               "textContent": a_text,
                                               "unpreferredTextContent": "",
                                               "preferredTextContent": "",
                                               "imageContent": "",
                                               "imageDetail": 0,
                                               "functionName": "",
                                               "functionParameters": [],
                                               "functionResults": "",
                                               "functionUsePreText": ""
                                       })
               i += 1

       return NEWCONVO

