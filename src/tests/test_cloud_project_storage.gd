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

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.2).timeout

	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var storage_mode = settings_ui.get_node("VBoxContainer/ProjectStorageModeContainer/ProjectStorageModeOptionButton")
	var image_upload_mode = settings_ui.get_node("VBoxContainer/ImageUplaodSettingContainer/ImageUplaodSettingOptionButton")
	var autosave_mode = settings_ui.get_node("VBoxContainer/AutoSaveModeContainer/AutoSaveModeOptionButton")
	var save_mode_btn = scene.get_node("VBoxContainer/SaveControls/SaveModeBtn")
	var save_btn = scene.get_node("VBoxContainer/SaveControls/SaveBtn")
	var load_btn = scene.get_node("VBoxContainer/LoadControls/LoadBtn")
	var load_mode_btn = scene.get_node("VBoxContainer/LoadControls/LoadModeBtn")
	var new_fine_tune_btn = scene.get_node("VBoxContainer/NewFineTuneButton")
	var autosave_timer = scene.get_node("AutoSaveTimer")

	storage_mode.select(1)
	settings_ui._on_project_storage_mode_item_selected(1)
	scene.update_settings_internal()
	await process_frame
	_check(scene.SETTINGS.get("projectStorageMode", -1) == 1, "cloud mode should be stored in settings")
	_check(image_upload_mode.selected == 1, "cloud mode should force image upload setting to always")
	_check(image_upload_mode.disabled, "cloud mode should disable image upload mode selector")
	_check(save_mode_btn.item_count == 4, "save mode should expose local and cloud actions")
	_check(load_mode_btn.item_count == 2, "load mode should expose file and cloud actions")
	_check(save_btn.text == scene.tr("FINETUNE_SAVE_CLOUD"), "save button should show cloud text")
	_check(load_btn.text == scene.tr("FINETUNE_LOAD_CLOUD"), "load button should show cloud text")
	_check(scene._get_default_load_action() == scene.LOAD_ACTION_FROM_CLOUD, "cloud mode should default to cloud load")
	_check(new_fine_tune_btn.text == scene.tr("FINETUNE_NEW_FINE_TUNE") or new_fine_tune_btn.text == "FINETUNE_NEW_FINE_TUNE", "new fine tune button should be available")

	autosave_mode.select(1)
	settings_ui._on_auto_save_mode_option_button_item_selected(1)
	scene.update_settings_internal()
	await process_frame
	_check(scene.SETTINGS.get("autoSaveMode", -1) == 1, "autosave mode should be saved")
	_check(autosave_timer.is_stopped() == false, "5 minute autosave should start timer")
	_check(absf(autosave_timer.wait_time - 300.0) < 0.01, "autosave timer should use 300 seconds")

	storage_mode.select(0)
	settings_ui._on_project_storage_mode_item_selected(0)
	autosave_mode.select(0)
	settings_ui._on_auto_save_mode_option_button_item_selected(0)
	scene.update_settings_internal()
	await process_frame
	_check(scene.SETTINGS.get("projectStorageMode", -1) == 0, "local mode should be stored in settings")
	_check(image_upload_mode.disabled == false, "local mode should re-enable image upload selector")
	_check(save_mode_btn.item_count == 4, "save mode should stay fully available in local mode")
	_check(save_btn.text == scene.tr("FINETUNE_SAVE"), "save button should show local text")
	_check(load_btn.text == scene.tr("FINETUNE_LOAD"), "load button should show local text")
	_check(scene._get_default_load_action() == scene.LOAD_ACTION_FROM_FILE, "local mode should default to file load")
	_check(autosave_timer.is_stopped(), "autosave off should stop timer")

	var sidebar_test_conversation_id = scene.create_new_conversation([
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
	scene._select_conversation_by_id(sidebar_test_conversation_id)
	await process_frame

	var messages_container = scene.get_node("Conversation/Messages/MessagesList/MessagesListContainer")
	var meta_message = null
	for child in messages_container.get_children():
		if child.is_in_group("message"):
			var message_data = child.to_var()
			if str(message_data.get("type", "")) == "meta":
				meta_message = child
				break
	_check(meta_message != null, "meta message should exist to edit conversation name")
	if meta_message != null:
		var conversation_id = str(sidebar_test_conversation_id)
		var conversation_name_edit = meta_message.get_node("MetaMessageContainer/ConversationNameContainer/ConversationNameEdit")
		conversation_name_edit.text = "Sidebar Sync Test"
		meta_message._on_conversation_name_edit_text_changed(conversation_name_edit.text)
		await process_frame
		var conversations_list = scene.get_node("VBoxContainer/ConversationsList")
		var selected_index = scene.selectionStringToIndex(conversations_list, conversation_id)
		_check(selected_index >= 0, "current conversation should still be present after renaming")
		if selected_index >= 0:
			_check(conversations_list.get_item_text(selected_index) == "Sidebar Sync Test", "conversation list should update custom name immediately")

	scene.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
