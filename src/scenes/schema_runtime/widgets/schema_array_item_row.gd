extends VBoxContainer

signal delete_requested(index: int)

const DELETE_ICON_CLOSED_SMALL = "res://icons/trashcan_small.png"
const DELETE_ICON_OPEN_SMALL = "res://icons/trashcanOpen_small.png"

var item_index = 0

func _ready() -> void:
	$Header/DeleteButton.text = tr("MESSAGES_JSON_SCHEMA_FORM_DELETE_ITEM")
	$Header/DeleteButton.pressed.connect(_on_delete_pressed)
	$Header/DeleteButton.mouse_entered.connect(_on_delete_button_mouse_entered)
	$Header/DeleteButton.mouse_exited.connect(_on_delete_button_mouse_exited)

func set_index(index: int) -> void:
	item_index = index
	$Header/ItemLabel.text = tr("MESSAGES_JSON_SCHEMA_FORM_ITEM") + " " + str(index + 1)

func get_content_container() -> VBoxContainer:
	return $ContentContainer

func _on_delete_pressed() -> void:
	delete_requested.emit(item_index)

func _on_delete_button_mouse_entered() -> void:
	if $Header/DeleteButton.disabled:
		return
	$Header/DeleteButton.icon = load(DELETE_ICON_OPEN_SMALL)

func _on_delete_button_mouse_exited() -> void:
	if $Header/DeleteButton.disabled:
		return
	$Header/DeleteButton.icon = load(DELETE_ICON_CLOSED_SMALL)
