extends HBoxContainer

var FINETUNEDATA = {}
var FUNCTIONS = []
var CONVERSATIONS = {}
var SETTINGS = []

var CURRENT_EDITED_CONVO_IX = 0
# FINETUNEDATA = 
# { functions: [],
#   settings: {
#     "use_global_system_message": true,
#     "global_system_message": "You are a helpful assistant!",
#
#	},
#   conversations: [CONVERSATION1],

# CONVERSATION1 = { 


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
	$VBoxContainer/ConversationsList.select(CURRENT_EDITED_CONVO_IX)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("save"):
		print("Würde jetzt speichern...")
		save_current_conversation()
		update_functions_internal()
		update_settings_internal()
		save_to_json("test3.json")
	if Input.is_action_just_released("load"):
		load_from_json("test3.json")
		



func _on_save_btn_pressed() -> void:
	var packed_scene = PackedScene.new()
	packed_scene.pack(get_tree().root.get_child(0))
	ResourceSaver.save(packed_scene, "res://savegame.tscn")

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
	CURRENT_EDITED_CONVO_IX = index
	# Create conversation if it does not exist
	if CURRENT_EDITED_CONVO_IX > len(CONVERSATIONS) - 1:
		CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = []
	print("IX:")
	print(CURRENT_EDITED_CONVO_IX)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
	


func save_current_conversation_to_conversations_at_index(ix: int):
	# THERE SHOULD BE NO REASON TO USE THIS FUNCTION
	CONVERSATIONS[ix] = $Conversation/Messages/MessagesList.to_var()

func save_current_conversation():
	CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = $Conversation/Messages/MessagesList.to_var()

func _on_load_btn_pressed() -> void:
	$VBoxContainer/LoadBtn/FileDialog.visible = true

func is_function_parameter_required(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					if parameter["isRequired"]:
						return true
					else:
						return false
	print("is_function_parameter_required could not find parameter " + str(parameter_name) + " for function " + function_name + ". I mean, I will be returning false, but are you sure everythings alright?")
	return false

func _on_file_dialog_file_selected(path: String) -> void:
	$VBoxContainer/ItemList.clear()
	var filetext = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(filetext)
	FINETUNEDATA = data
		

func refresh_conversations_list():
	$VBoxContainer/ConversationsList.clear()
	for i in range(len(CONVERSATIONS)):
		$VBoxContainer/ConversationsList.add_item("Conversation " + str(i))


func _on_conversation_tab_changed(tab: int) -> void:
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()


func _on_button_pressed() -> void:
	CURRENT_EDITED_CONVO_IX = len(CONVERSATIONS)
	# Create conversation if it does not exist
	CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = []
	refresh_conversations_list()

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
		CURRENT_EDITED_CONVO_IX = len(CONVERSATIONS) - 1
		$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
		$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
		$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
		refresh_conversations_list()
		$VBoxContainer/ConversationsList.select(CURRENT_EDITED_CONVO_IX)
	else:
		print("file not found")
	
func save_to_json(filename):
	var jsonstr = JSON.stringify(FINETUNEDATA, "\t")
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	file.store_string(jsonstr)
	file.close()
	
func load_from_json(filename):
	var json_as_text = FileAccess.get_file_as_string("user://" + filename)
	var json_as_dict = JSON.parse_string(json_as_text)
	FINETUNEDATA = json_as_dict
	FUNCTIONS = FINETUNEDATA["functions"]
	CONVERSATIONS = FINETUNEDATA["conversations"]
	SETTINGS = FINETUNEDATA["settings"]
	CURRENT_EDITED_CONVO_IX = len(CONVERSATIONS) - 1
	$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
	refresh_conversations_list()
	$VBoxContainer/ConversationsList.select(CURRENT_EDITED_CONVO_IX)