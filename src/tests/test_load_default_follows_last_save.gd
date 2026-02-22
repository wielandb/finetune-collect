extends SceneTree

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _assert_eq(actual, expected, message: String) -> void:
	_check(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

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

func _write_local_autoload_snapshot(snapshot_json: String) -> void:
	var last_project_file = FileAccess.open("user://last_project.txt", FileAccess.WRITE)
	if last_project_file:
		last_project_file.store_string("")
		last_project_file.close()
	var last_project_data_file = FileAccess.open("user://last_project_data.json", FileAccess.WRITE)
	if last_project_data_file:
		last_project_data_file.store_string(snapshot_json)
		last_project_data_file.close()
	var state = {
		"source": "local",
		"path": "",
		"cloudURL": "",
		"cloudKey": "",
		"cloudName": ""
	}
	var last_project_state_file = FileAccess.open("user://last_project_state.json", FileAccess.WRITE)
	if last_project_state_file:
		last_project_state_file.store_string(JSON.stringify(state))
		last_project_state_file.close()

func _create_scene():
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.3).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = await _create_scene()
	scene._save_success_icon_feedback_duration_seconds = 0.05
	var save_btn = scene.get_node("VBoxContainer/SaveControls/SaveBtn")
	_assert_eq(scene._get_default_load_action(), scene.LOAD_ACTION_FROM_FILE, "startup should default to file load")
	_assert_eq(scene.get_node("VBoxContainer/LoadControls/LoadBtn").text, scene.tr("FINETUNE_LOAD"), "startup load button should use file text")
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/save.png", "save button should start with save icon")

	scene._apply_cloud_target_settings("https://cloud.example/project-storage.php", "cloud_key", "cloud_project")
	scene._queue_test_cloud_request_response({"ok": true, "http_code": 200})
	var cloud_save_success = await scene._run_selected_save_action(scene.SAVE_ACTION_SAVE_CLOUD)
	_check(cloud_save_success, "cloud save should succeed with queued response")
	_assert_eq(int(scene.SETTINGS.get("projectStorageMode", -1)), scene.PROJECT_STORAGE_MODE_CLOUD, "cloud save should switch storage mode to cloud")
	_assert_eq(scene._get_default_load_action(), scene.LOAD_ACTION_FROM_CLOUD, "cloud save should switch default load action to cloud")
	_assert_eq(scene.get_node("VBoxContainer/LoadControls/LoadBtn").text, scene.tr("FINETUNE_LOAD_CLOUD"), "cloud save should switch load button text to cloud")
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/content-save-check-custom.png", "cloud save should show success icon")
	await create_timer(0.08).timeout
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/save.png", "success icon should reset to save icon after cloud save")

	var cloud_snapshot = scene.make_save_json_data()
	var cloud_restored_scene = await _create_scene()
	cloud_restored_scene.load_from_json_data(cloud_snapshot)
	_assert_eq(cloud_restored_scene._get_default_load_action(), cloud_restored_scene.LOAD_ACTION_FROM_CLOUD, "cloud storage mode should persist in saved project data")
	await _destroy_scene(cloud_restored_scene)

	_write_local_autoload_snapshot(cloud_snapshot)
	var startup_local_restored_scene = await _create_scene()
	_assert_eq(startup_local_restored_scene._get_default_load_action(), startup_local_restored_scene.LOAD_ACTION_FROM_FILE, "startup local auto-load should default to file load even with cloud snapshot")
	_assert_eq(startup_local_restored_scene.get_node("VBoxContainer/LoadControls/LoadBtn").text, startup_local_restored_scene.tr("FINETUNE_LOAD"), "startup local auto-load should keep local load button text")
	await _destroy_scene(startup_local_restored_scene)
	_clear_last_project_files()

	scene.RUNTIME["filepath"] = "user://default_load_local_save.json"
	var local_save_success = await scene._run_selected_save_action(scene.SAVE_ACTION_SAVE_LOCAL)
	_check(local_save_success, "local save should succeed when filepath is set")
	_assert_eq(int(scene.SETTINGS.get("projectStorageMode", -1)), scene.PROJECT_STORAGE_MODE_LOCAL, "local save should switch storage mode to local")
	_assert_eq(scene._get_default_load_action(), scene.LOAD_ACTION_FROM_FILE, "local save should switch default load action to file")
	_assert_eq(scene.get_node("VBoxContainer/LoadControls/LoadBtn").text, scene.tr("FINETUNE_LOAD"), "local save should switch load button text to file")
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/content-save-check-custom.png", "local save should show success icon")
	await create_timer(0.08).timeout
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/save.png", "success icon should reset to save icon after local save")

	scene.SETTINGS["autoSaveMode"] = scene.AUTO_SAVE_MODE_EVERY_5_MIN
	scene.RUNTIME["filepath"] = "user://default_load_local_autosave.json"
	await scene._run_autosave("timer")
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/content-save-check-custom.png", "autosave should show success icon")
	await create_timer(0.08).timeout
	_assert_eq(str(save_btn.icon.resource_path), "res://icons/save.png", "success icon should reset to save icon after autosave")

	var local_snapshot = scene.make_save_json_data()
	var local_restored_scene = await _create_scene()
	local_restored_scene.load_from_json_data(local_snapshot)
	_assert_eq(local_restored_scene._get_default_load_action(), local_restored_scene.LOAD_ACTION_FROM_FILE, "local storage mode should persist in saved project data")
	await _destroy_scene(local_restored_scene)

	await _destroy_scene(scene)
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
