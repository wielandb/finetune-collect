extends VBoxContainer

signal delete_requested(index: int)

var item_index = 0

func _ready() -> void:
	$Header/DeleteButton.text = tr("MESSAGES_JSON_SCHEMA_FORM_DELETE_ITEM")
	$Header/DeleteButton.pressed.connect(_on_delete_pressed)

func set_index(index: int) -> void:
	item_index = index
	$Header/ItemLabel.text = tr("MESSAGES_JSON_SCHEMA_FORM_ITEM") + " " + str(index + 1)

func get_content_container() -> VBoxContainer:
	return $ContentContainer

func _on_delete_pressed() -> void:
	delete_requested.emit(item_index)
