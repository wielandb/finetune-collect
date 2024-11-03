extends ScrollContainer

@onready var MESSAGE_SCENE = preload("res://scenes/message.tscn")
# Called when the node enters the scene tree for the first time.

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
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_message_button_pressed() -> void:
	# Add a new message to the MessagesListContainer
	var MessageInstance = MESSAGE_SCENE.instantiate()
	var addButton = $MessagesListContainer/AddMessageButton
	$MessagesListContainer.add_child(MessageInstance)
	$MessagesListContainer.move_child(addButton, -1)
	#
	print(self.to_var())
	
func delete_all_messages_from_UI():
	for message in $MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()
