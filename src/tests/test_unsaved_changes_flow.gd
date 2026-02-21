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

func _write_text_file(path: String, text: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()

func _create_load_target_file(scene, path: String, conversation_name: String) -> void:
	var target_project = {
		"functions": [],
		"conversations": {
			"L0AD": [
				scene._make_meta_message(conversation_name),
				scene._make_text_message("user", "load_target_text")
			]
		},
		"settings": scene.SETTINGS.duplicate(true),
		"graders": [],
		"schemas": []
	}
	_write_text_file(path, JSON.stringify(target_project, "\t", false))

func _make_dirty(scene) -> void:
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var global_message_edit = settings_ui.get_node("VBoxContainer/HBoxContainer/GlobalSystemMessageContainer/GlobalSystemMessageTextEdit")
	global_message_edit.text = str(global_message_edit.text) + " unsaved_change"
	scene.update_settings_internal()
	await process_frame

func _test_dirty_new_fine_tune_dont_save() -> void:
	_clear_last_project_files()
	var scene = await _create_scene()
	await _make_dirty(scene)
	_check(scene._has_unsaved_changes(), "project should be dirty before new fine tune action")
	scene._set_test_unsaved_choice_override(scene.UNSAVED_CHOICE_DONT_SAVE)
	await scene._on_new_fine_tune_btn_pressed()
	_check(not scene._has_unsaved_changes(), "new fine tune should end in clean state after don't save")
	var state = _read_last_project_state()
	_assert_eq(str(state.get("source", "")), "none", "new fine tune should clear last project marker")
	_check(scene.CONVERSATIONS.size() == 1, "new fine tune should rebuild one fresh conversation")
	await _destroy_scene(scene)

func _test_dirty_load_cancel_keeps_current_project() -> void:
	_clear_last_project_files()
	var scene = await _create_scene()
	var load_target_path = "user://unsaved_cancel_load_target.json"
	_create_load_target_file(scene, load_target_path, "cancel_target")
	await _make_dirty(scene)
	var before_json = scene._capture_current_project_snapshot_json()
	scene._set_test_unsaved_choice_override(scene.UNSAVED_CHOICE_CANCEL)
	await scene.request_load_project_from_path_with_unsaved_guard(load_target_path)
	await process_frame
	var after_json = scene._capture_current_project_snapshot_json()
	_assert_eq(after_json, before_json, "canceling unsaved prompt should keep current project unchanged")
	_assert_eq(str(scene.RUNTIME.get("filepath", "")), "", "canceling load should not set filepath")
	await _destroy_scene(scene)

func _test_dirty_save_then_cancel_save_dialog_keeps_project() -> void:
	_clear_last_project_files()
	var scene = await _create_scene()
	var load_target_path = "user://unsaved_save_cancel_target.json"
	_create_load_target_file(scene, load_target_path, "save_cancel_target")
	await _make_dirty(scene)
	var before_json = scene._capture_current_project_snapshot_json()
	scene._set_test_unsaved_choice_override(scene.UNSAVED_CHOICE_SAVE)
	await scene.request_load_project_from_path_with_unsaved_guard(load_target_path)
	await process_frame
	var save_dialog = scene.get_node("VBoxContainer/SaveControls/SaveBtn/SaveFileDialog")
	_check(save_dialog.visible, "save choice without filepath should open save dialog")
	scene._on_save_file_dialog_canceled()
	await process_frame
	var after_json = scene._capture_current_project_snapshot_json()
	_assert_eq(after_json, before_json, "canceling save dialog should abort pending destructive action")
	_assert_eq(str(scene.RUNTIME.get("filepath", "")), "", "save dialog cancel should keep filepath unset")
	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_dirty_new_fine_tune_dont_save()
	await _test_dirty_load_cancel_keeps_current_project()
	await _test_dirty_save_then_cancel_save_dialog_keeps_project()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
