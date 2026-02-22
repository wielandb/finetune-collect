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

func _find_item_index_by_id(button: OptionButton, item_id: int) -> int:
	for i in range(button.item_count):
		if button.get_item_id(i) == item_id:
			return i
	return -1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.25).timeout

	var save_mode_btn = scene.get_node("VBoxContainer/SaveControls/SaveModeBtn")
	var load_mode_btn = scene.get_node("VBoxContainer/LoadControls/LoadModeBtn")
	var save_file_dialog = scene.get_node("VBoxContainer/SaveControls/SaveBtn/SaveFileDialog")
	var load_file_dialog = scene.get_node("VBoxContainer/LoadControls/LoadBtn/FileDialog")

	_check(save_mode_btn.item_count == 4, "save mode should contain four actions")
	_check(load_mode_btn.item_count == 2, "load mode should contain two actions")

	var save_local_index = _find_item_index_by_id(save_mode_btn, scene.SAVE_ACTION_SAVE_LOCAL)
	var save_local_as_index = _find_item_index_by_id(save_mode_btn, scene.SAVE_ACTION_SAVE_LOCAL_AS)
	var save_cloud_index = _find_item_index_by_id(save_mode_btn, scene.SAVE_ACTION_SAVE_CLOUD)
	var save_cloud_as_index = _find_item_index_by_id(save_mode_btn, scene.SAVE_ACTION_SAVE_CLOUD_AS)
	var load_file_index = _find_item_index_by_id(load_mode_btn, scene.LOAD_ACTION_FROM_FILE)
	var load_cloud_index = _find_item_index_by_id(load_mode_btn, scene.LOAD_ACTION_FROM_CLOUD)
	_check(save_local_index != -1, "local save action id should exist")
	_check(save_local_as_index != -1, "local save-as action id should exist")
	_check(save_cloud_index != -1, "cloud save action id should exist")
	_check(save_cloud_as_index != -1, "cloud save-as action id should exist")
	_check(load_file_index != -1, "file load action id should exist")
	_check(load_cloud_index != -1, "cloud load action id should exist")

	await scene._on_save_mode_btn_item_selected(save_local_as_index)
	_check(save_mode_btn.selected == -1, "save mode button should reset after action")
	_check(save_file_dialog.visible, "local save-as action should open save file dialog")
	save_file_dialog.visible = false

	await scene._on_load_mode_btn_item_selected(load_file_index)
	_check(load_mode_btn.selected == -1, "load mode button should reset after action")
	_check(load_file_dialog.visible, "file load action should open file dialog")
	load_file_dialog.visible = false

	scene._queue_test_cloud_dialog_response({"confirmed": false})
	await scene._on_load_mode_btn_item_selected(load_cloud_index)
	_check(load_mode_btn.selected == -1, "load mode button should reset after canceled cloud load dialog")
	_check(not load_file_dialog.visible, "cloud load action should not open the local file dialog")

	scene.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
