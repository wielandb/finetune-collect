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
		var addButton = $MessagesListContainer/AddMessageButton
		$MessagesListContainer.add_child(MessageInstance)
		MessageInstance.from_var(m)
		$MessagesListContainer.move_child(addButton, -1)

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
	var addButton = $MessagesListContainer/AddMessageButton
	var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	$MessagesListContainer.add_child(MessageInstance)
	$MessagesListContainer.move_child(addAIButton, -1)
	$MessagesListContainer.move_child(addButton, -1)
	#
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
	var addButton = $MessagesListContainer/AddMessageButton
	var addAIButton = $MessagesListContainer/AddMessageCompletionButton
	$MessagesListContainer.add_child(MessageInstance)
	$MessagesListContainer.move_child(addAIButton, -1)
	$MessagesListContainer.move_child(addButton, -1)	
	# Populate the message with the received data
	var RecvMsgVar = {
		"role": "assistant",
		"type": "Text",
		"textContent": message["content"],
		"imageContent": "",
		"functionName": "",
		"functionParameters": [],
		"functionResults": []
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
	var ftc_messages = self.to_var()
	var openai_messages:Array[Message] = []
	for m in ftc_messages:
		var nm = Message.new()
		nm.set_role(m["role"])
		nm.set_content(m["textContent"])
		openai_messages.append(nm)
	openai.prompt_gpt(openai_messages, "gpt-4o")
