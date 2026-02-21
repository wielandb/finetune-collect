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

func _write_text_file(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()

func _read_last_project_state() -> Dictionary:
	if not FileAccess.file_exists("user://last_project_state.json"):
		return {}
	var state_text = FileAccess.get_file_as_string("user://last_project_state.json").strip_edges()
	if state_text == "":
		return {}
	var parsed = JSON.parse_string(state_text)
	if parsed is Dictionary:
		return parsed
	return {}

func _create_scene():
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.35).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame

func _test_local_path_restore() -> void:
	_clear_last_project_files()
	var first_scene = await _create_scene()
	var project_path = "user://restore_local_project.json"
	var snapshot = first_scene.make_save_json_data()
	_write_text_file(project_path, snapshot)
	first_scene._remember_last_open_local(project_path, snapshot)
	await _destroy_scene(first_scene)

	var restored_scene = await _create_scene()
	_assert_eq(str(restored_scene.RUNTIME.get("filepath", "")), project_path, "startup should restore local project path")
	_check(restored_scene.CONVERSATIONS.size() > 0, "restored local project should contain conversations")
	await _destroy_scene(restored_scene)

func _test_local_missing_path_falls_back_to_snapshot() -> void:
	_clear_last_project_files()
	var first_scene = await _create_scene()
	var missing_path = "user://missing_project_for_restore.json"
	var abs_missing_path = ProjectSettings.globalize_path(missing_path)
	if FileAccess.file_exists(missing_path):
		DirAccess.remove_absolute(abs_missing_path)
	var snapshot = first_scene.make_save_json_data()
	first_scene._remember_last_open_local(missing_path, snapshot)
	await _destroy_scene(first_scene)

	var restored_scene = await _create_scene()
	_assert_eq(str(restored_scene.RUNTIME.get("filepath", "")), "", "missing local path should restore snapshot without filepath")
	_check(restored_scene.CONVERSATIONS.size() > 0, "snapshot fallback should restore project data")
	var restored_state = _read_last_project_state()
	_assert_eq(str(restored_state.get("source", "")), "local", "local marker should stay after snapshot fallback")
	await _destroy_scene(restored_scene)

func _test_cloud_restore_failure_falls_back_to_empty_project_and_keeps_marker() -> void:
	_clear_last_project_files()
	var cloud_state = {
		"source": "cloud",
		"path": "",
		"cloudURL": "http://127.0.0.1:59999/project-storage.php",
		"cloudKey": "invalid_key",
		"cloudName": "cloud_restore_test"
	}
	_write_text_file("user://last_project_state.json", JSON.stringify(cloud_state))

	var scene = await _create_scene()
	_check(scene.CONVERSATIONS.size() > 0, "cloud failure fallback should create an empty default project")
	_assert_eq(str(scene.RUNTIME.get("filepath", "")), "", "cloud fallback project should not have a local filepath")
	var state_after_failure = _read_last_project_state()
	_assert_eq(str(state_after_failure.get("source", "")), "cloud", "cloud marker should remain after failed cloud startup load")
	_assert_eq(str(state_after_failure.get("cloudName", "")), "cloud_restore_test", "cloud marker fields should remain unchanged")
	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_local_path_restore()
	await _test_local_missing_path_falls_back_to_snapshot()
	await _test_cloud_restore_failure_falls_back_to_empty_project_and_keeps_marker()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
