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
	var load_btn = scene.get_node("VBoxContainer/LoadBtn")
	var autosave_timer = scene.get_node("AutoSaveTimer")

	storage_mode.select(1)
	settings_ui._on_project_storage_mode_item_selected(1)
	scene.update_settings_internal()
	await process_frame
	_check(scene.SETTINGS.get("projectStorageMode", -1) == 1, "cloud mode should be stored in settings")
	_check(image_upload_mode.selected == 1, "cloud mode should force image upload setting to always")
	_check(image_upload_mode.disabled, "cloud mode should disable image upload mode selector")
	_check(save_mode_btn.item_count == 1, "cloud mode should only expose one save action")
	_check(save_btn.text == scene.tr("FINETUNE_SAVE_CLOUD"), "save button should show cloud text")
	_check(load_btn.text == scene.tr("FINETUNE_LOAD_CLOUD"), "load button should show cloud text")

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
	_check(save_mode_btn.item_count == 2, "local mode should expose save and save as")
	_check(save_btn.text == scene.tr("FINETUNE_SAVE"), "save button should show local text")
	_check(load_btn.text == scene.tr("FINETUNE_LOAD"), "load button should show local text")
	_check(autosave_timer.is_stopped(), "autosave off should stop timer")

	scene.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
