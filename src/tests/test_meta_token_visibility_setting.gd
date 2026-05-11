extends SceneTree

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _clear_last_project_files() -> void:
	var last_project_file = FileAccess.open("user://last_project.txt", FileAccess.WRITE)
	if last_project_file:
		last_project_file.store_string("")
		last_project_file.close()
	var last_project_data_file = FileAccess.open("user://last_project_data.json", FileAccess.WRITE)
	if last_project_data_file:
		last_project_data_file.store_string("")
		last_project_data_file.close()
	var last_project_state_file = FileAccess.open("user://last_project_state.json", FileAccess.WRITE)
	if last_project_state_file:
		last_project_state_file.store_string("")
		last_project_state_file.close()

func _find_meta_message(messages_container: Node) -> Node:
	for child in messages_container.get_children():
		if child.is_in_group("message"):
			var message_data = child.to_var()
			if str(message_data.get("type", "")) == "meta":
				return child
	return null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.2).timeout

	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var visibility_option = settings_ui.get_node("VBoxContainer/ShowMetaTokenValuesContainer/ShowMetaTokenValuesOptionButton")
	_check(int(visibility_option.selected) == 1, "new projects should default to hidden meta token values")
	_check(bool(scene.SETTINGS.get("showMetaTokenValues", true)) == false, "new project settings should store hidden meta token values")

	var messages_container = scene.get_node("Conversation/Messages/MessagesList/MessagesListContainer")
	var meta_message = _find_meta_message(messages_container)
	if meta_message == null:
		var convo_id = scene.create_new_conversation([
			{
				"role": "meta",
				"type": "meta",
				"metaData": {
					"ready": false,
					"conversationName": "",
					"notes": ""
				}
			}
		])
		scene._select_conversation_by_id(convo_id)
		await process_frame
		await process_frame
		meta_message = _find_meta_message(messages_container)
	_check(meta_message != null, "meta message should exist")
	if meta_message == null:
		scene.queue_free()
		await process_frame
		print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
		quit(tests_failed)
		return

	meta_message._on_show_meta_message_toggle_button_pressed()
	await process_frame
	var show_button = meta_message.get_node("MetaMessageContainer/ShowMetaMessageToggleButton")
	var toggle_cost_button = meta_message.get_node("MetaMessageContainer/MetaMessageToggleCostEstimationButton")
	var conversation_name_container = meta_message.get_node("MetaMessageContainer/ConversationNameContainer")
	var info_grid = meta_message.get_node("MetaMessageContainer/InfoLabelsGridContainer")
	_check(conversation_name_container.visible, "meta details should open when toggled")
	_check(not info_grid.visible, "info grid should stay hidden while setting hides token values")
	_check(show_button.text == meta_message.tr("MESSAGE_META_HIDE_META_MESSAGE"), "show/hide toggle text should reflect open details")
	_check(toggle_cost_button.text == meta_message.tr("MESSAGE_META_HIDE_META_MESSAGE"), "cost toggle text should match open details")

	visibility_option.select(0)
	settings_ui._on_something_int_needs_update_global(0)
	await process_frame
	await process_frame
	_check(bool(scene.SETTINGS.get("showMetaTokenValues", false)) == true, "settings should store visible meta token values after switching to show")
	_check(info_grid.visible, "info grid should become visible without conversation switch")

	visibility_option.select(1)
	settings_ui._on_something_int_needs_update_global(1)
	await process_frame
	await process_frame
	_check(bool(scene.SETTINGS.get("showMetaTokenValues", true)) == false, "settings should store hidden meta token values after switching to hide")
	_check(conversation_name_container.visible, "meta details should remain open when token values are hidden")
	_check(not info_grid.visible, "info grid should hide immediately after setting change")
	_check(show_button.text == meta_message.tr("MESSAGE_META_HIDE_META_MESSAGE"), "toggle text should still indicate open details")

	meta_message._on_show_meta_message_toggle_button_pressed()
	await process_frame
	_check(not conversation_name_container.visible, "meta details should close when toggled again")
	_check(not info_grid.visible, "info grid should remain hidden when details are closed")
	_check(show_button.text == meta_message.tr("MESSAGE_META_SHOW_META_MESSAGE"), "toggle text should indicate closed details")
	_check(toggle_cost_button.text == meta_message.tr("MESSAGE_META_SHOW_META_MESSAGE"), "cost toggle text should indicate closed details")

	scene.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
