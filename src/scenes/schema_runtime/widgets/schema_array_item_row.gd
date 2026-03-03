extends VBoxContainer

signal move_up_requested(index: int)
signal move_down_requested(index: int)
signal duplicate_requested(index: int)
signal delete_requested(index: int)

const MOVE_UP_ICON = "res://icons/chevron-double-up.png"
const MOVE_DOWN_ICON = "res://icons/chevron-double-down.png"
const DUPLICATE_ICON = "res://icons/content-duplicate-custom.png"
const DELETE_ICON_CLOSED_SMALL = "res://icons/trashcan_small.png"
const DELETE_ICON_OPEN_SMALL = "res://icons/trashcanOpen_small.png"

var item_index = 0
var _actions_initialized = false

func _ready() -> void:
	_initialize_actions()

func set_action_states(can_move_up: bool, can_move_down: bool, can_duplicate: bool, can_delete: bool) -> void:
	_initialize_actions()
	$Header/MoveUpButton.disabled = not can_move_up
	$Header/MoveDownButton.disabled = not can_move_down
	$Header/DuplicateButton.disabled = not can_duplicate
	$Header/DeleteButton.disabled = not can_delete

func set_index(index: int) -> void:
	item_index = index
	$Header/ItemLabel.text = tr("MESSAGES_JSON_SCHEMA_FORM_ITEM") + " " + str(index + 1)

func get_content_container() -> VBoxContainer:
	return $ContentContainer

func _initialize_actions() -> void:
	if _actions_initialized:
		return
	_actions_initialized = true
	_insert_action_button("MoveUpButton", MOVE_UP_ICON, Callable(self, "_on_move_up_pressed"))
	_insert_action_button("MoveDownButton", MOVE_DOWN_ICON, Callable(self, "_on_move_down_pressed"))
	_insert_action_button("DuplicateButton", DUPLICATE_ICON, Callable(self, "_on_duplicate_pressed"))
	$Header/DeleteButton.text = ""
	_configure_action_button($Header/DeleteButton)
	$Header/DeleteButton.pressed.connect(_on_delete_pressed)
	$Header/DeleteButton.mouse_entered.connect(_on_delete_button_mouse_entered)
	$Header/DeleteButton.mouse_exited.connect(_on_delete_button_mouse_exited)

func _insert_action_button(button_name: String, icon_path: String, on_pressed: Callable) -> void:
	var button = Button.new()
	button.name = button_name
	button.text = ""
	button.icon = load(icon_path)
	_configure_action_button(button)
	button.pressed.connect(on_pressed)
	$Header.add_child(button)
	$Header.move_child(button, $Header/DeleteButton.get_index())

func _configure_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(36, 0)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER

func _on_move_up_pressed() -> void:
	move_up_requested.emit(item_index)

func _on_move_down_pressed() -> void:
	move_down_requested.emit(item_index)

func _on_duplicate_pressed() -> void:
	duplicate_requested.emit(item_index)

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
