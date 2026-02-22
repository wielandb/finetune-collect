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

func _set_cloud_settings(scene, cloud_url: String, cloud_key: String, project_id: String) -> void:
	scene._apply_cloud_target_settings(cloud_url, cloud_key, project_id)
	await process_frame

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.3).timeout

	await _set_cloud_settings(scene, "https://old.example/project-storage.php", "old_key", "")
	scene._queue_test_cloud_dialog_response({
		"confirmed": true,
		"url": "https://save.example/project-storage.php",
		"key": "save_key",
		"project_id": "save_project"
	})
	scene._queue_test_cloud_request_response({"ok": true, "http_code": 200})
	var save_without_project_id = await scene._run_selected_save_action(scene.SAVE_ACTION_SAVE_CLOUD)
	_check(save_without_project_id, "cloud save with missing project id should proceed after dialog confirmation")
	_assert_eq(str(scene.SETTINGS.get("projectCloudURL", "")), "https://save.example/project-storage.php", "cloud save should apply dialog URL")
	_assert_eq(str(scene.SETTINGS.get("projectCloudKey", "")), "save_key", "cloud save should apply dialog key")
	_assert_eq(str(scene.SETTINGS.get("projectCloudName", "")), "save_project", "cloud save should apply dialog project id")

	await _set_cloud_settings(scene, "https://kept.example/project-storage.php", "kept_key", "kept_project")
	scene._queue_test_cloud_request_response({"ok": true, "http_code": 200})
	var save_with_existing_project_id = await scene._run_selected_save_action(scene.SAVE_ACTION_SAVE_CLOUD)
	_check(save_with_existing_project_id, "cloud save with existing project id should not require dialog")
	_assert_eq(str(scene.SETTINGS.get("projectCloudURL", "")), "https://kept.example/project-storage.php", "cloud save should keep URL when dialog is not needed")
	_assert_eq(str(scene.SETTINGS.get("projectCloudKey", "")), "kept_key", "cloud save should keep key when dialog is not needed")
	_assert_eq(str(scene.SETTINGS.get("projectCloudName", "")), "kept_project", "cloud save should keep project id when dialog is not needed")

	await _set_cloud_settings(scene, "https://before-as.example/project-storage.php", "before_as_key", "before_as_project")
	scene._queue_test_cloud_dialog_response({
		"confirmed": true,
		"url": "https://as.example/project-storage.php",
		"key": "as_key",
		"project_id": "as_project"
	})
	scene._queue_test_cloud_request_response({"ok": true, "http_code": 200})
	var save_as_cloud = await scene._run_selected_save_action(scene.SAVE_ACTION_SAVE_CLOUD_AS)
	_check(save_as_cloud, "cloud save-as should proceed after dialog confirmation")
	_assert_eq(str(scene.SETTINGS.get("projectCloudURL", "")), "https://as.example/project-storage.php", "cloud save-as should always apply dialog URL")
	_assert_eq(str(scene.SETTINGS.get("projectCloudKey", "")), "as_key", "cloud save-as should always apply dialog key")
	_assert_eq(str(scene.SETTINGS.get("projectCloudName", "")), "as_project", "cloud save-as should always apply dialog project id")

	await _set_cloud_settings(scene, "https://before-load.example/project-storage.php", "before_load_key", "before_load_project")
	scene._queue_test_cloud_dialog_response({
		"confirmed": true,
		"url": "https://load.example/project-storage.php",
		"key": "load_key",
		"project_id": "load_project"
	})
	scene._queue_test_cloud_request_response({"ok": false, "http_code": 500, "error": "forced"})
	await scene._run_selected_load_action(scene.LOAD_ACTION_FROM_CLOUD)
	_assert_eq(str(scene.SETTINGS.get("projectCloudURL", "")), "https://load.example/project-storage.php", "cloud load should apply dialog URL")
	_assert_eq(str(scene.SETTINGS.get("projectCloudKey", "")), "load_key", "cloud load should apply dialog key")
	_assert_eq(str(scene.SETTINGS.get("projectCloudName", "")), "load_project", "cloud load should apply dialog project id")

	scene.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
