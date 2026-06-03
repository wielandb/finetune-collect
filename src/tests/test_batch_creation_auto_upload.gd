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

func _assert_true(condition: bool, message: String) -> void:
	_check(condition, message)

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
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.3).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame

func _create_temp_png(file_name: String, fill_color: Color) -> String:
	var image = Image.create(8, 5, false, Image.FORMAT_RGBA8)
	image.fill(fill_color)
	var path = "user://%s" % file_name
	var save_result = image.save_png(path)
	_assert_eq(save_result, OK, "Saving temporary PNG should succeed")
	return path

func _create_temp_text_file(file_name: String, content: String) -> String:
	var path = "user://%s" % file_name
	var file = FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "Opening temporary text file should succeed")
	if file != null:
		file.store_string(content)
		file.close()
	return path

func _delete_temp_file(path: String) -> void:
	if path == "":
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _get_new_conversation_ids(scene, before_order: Array) -> Array:
	var new_ids = []
	for convo_id in scene.CONVERSATION_ORDER:
		if not before_order.has(convo_id):
			new_ids.append(str(convo_id))
	return new_ids

func _get_first_image_content(scene, convo_id: String) -> String:
	if not scene.CONVERSATIONS.has(convo_id):
		return ""
	var convo = scene.CONVERSATIONS[convo_id]
	if not (convo is Array):
		return ""
	for msg in convo:
		if msg is Dictionary and str(msg.get("type", "")) == "Image":
			return str(msg.get("imageContent", ""))
	return ""

func _get_conversation(scene, convo_id: String) -> Array:
	if not scene.CONVERSATIONS.has(convo_id):
		return []
	var convo = scene.CONVERSATIONS[convo_id]
	if not (convo is Array):
		return []
	return convo

func _make_object_schema(title: String, property_name: String, property_type: String) -> Dictionary:
	return {
		"title": title,
		"type": "object",
		"properties": {
			property_name: {
				"type": property_type
			}
		},
		"required": [property_name],
		"additionalProperties": false
	}

func _make_schema_log_entry(schema_name: String, schema: Dictionary, response_content: String = "{\"ok\":true}") -> Dictionary:
	return {
		"request": {
			"messages": [
				{"role": "user", "content": "Bitte antworte als JSON"}
			],
			"response_format": {
				"type": "json_schema",
				"json_schema": {
					"name": schema_name,
					"strict": true,
					"schema": schema
				}
			}
		},
		"response": {
			"output_messages": [
				{"role": "assistant", "content": response_content}
			]
		}
	}

func _find_schema_by_name(scene, schema_name: String) -> Dictionary:
	for schema_entry in scene.SCHEMAS:
		if schema_entry is Dictionary and str(schema_entry.get("name", "")) == schema_name:
			return schema_entry
	return {}

func _configure_upload_settings(scene) -> void:
	scene.SETTINGS["imageUploadSetting"] = 1
	scene.SETTINGS["imageUploadServerURL"] = "https://upload.test/image-upload.php"
	scene.SETTINGS["imageUploadServerKey"] = "upload_key"

func _test_batch_creation_triggers_background_upload_and_button_state() -> void:
	var scene = await _create_scene()
	_configure_upload_settings(scene)
	scene._set_test_image_upload_delay_seconds(0.2)
	scene._queue_test_image_upload_response("https://upload.test/a.png")
	scene._queue_test_image_upload_response("https://upload.test/b.png")
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var batch_button = settings_ui.get_node("VBoxContainer/BatchCreatonContainer/BatchCreationButton")
	var default_button_text = str(batch_button.text)
	var order_before = scene.CONVERSATION_ORDER.duplicate()
	var temp_a = _create_temp_png("tmp_batch_upload_a.png", Color(1.0, 0.2, 0.2, 1.0))
	var temp_b = _create_temp_png("tmp_batch_upload_b.png", Color(0.2, 0.2, 1.0, 1.0))
	settings_ui._on_batch_creation_file_dialog_files_selected(PackedStringArray([temp_a, temp_b]))
	await process_frame
	_assert_true(batch_button.disabled, "Batch button should be disabled while batch image uploads run")
	_assert_true(str(batch_button.text) != default_button_text, "Batch button text should display upload progress while running")
	await scene.wait_for_batch_post_create_uploads()
	await process_frame
	_assert_true(not batch_button.disabled, "Batch button should be enabled after batch image uploads complete")
	_assert_eq(str(batch_button.text), default_button_text, "Batch button text should reset after uploads")
	var new_ids = _get_new_conversation_ids(scene, order_before)
	_assert_eq(new_ids.size(), 2, "Batch creation should create one conversation per image")
	for convo_id in new_ids:
		var image_content = _get_first_image_content(scene, convo_id)
		_assert_true(image_content.begins_with("https://upload.test/"), "New batch conversation image should be converted to URL immediately")
	_delete_temp_file(temp_a)
	_delete_temp_file(temp_b)
	await _destroy_scene(scene)

func _test_export_waits_for_running_batch_uploads() -> void:
	var scene = await _create_scene()
	_configure_upload_settings(scene)
	scene._set_test_image_upload_delay_seconds(0.35)
	scene._queue_test_image_upload_response("https://upload.test/export.png")
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var order_before = scene.CONVERSATION_ORDER.duplicate()
	var temp_export = _create_temp_png("tmp_batch_upload_export.png", Color(0.1, 0.7, 0.3, 1.0))
	settings_ui._on_batch_creation_file_dialog_files_selected(PackedStringArray([temp_export]))
	await process_frame
	await scene.create_jsonl_data_for_file()
	_assert_true(not scene.is_batch_post_create_upload_running(), "Export should wait for running batch post-create uploads")
	var new_ids = _get_new_conversation_ids(scene, order_before)
	_assert_eq(new_ids.size(), 1, "Single-file batch should create one conversation")
	if new_ids.size() > 0:
		var image_content = _get_first_image_content(scene, new_ids[0])
		_assert_true(image_content.begins_with("https://upload.test/"), "Export waitpoint should leave new batch image already uploaded")
	_delete_temp_file(temp_export)
	await _destroy_scene(scene)

func _test_cloud_save_waits_and_avoids_duplicate_uploads() -> void:
	var scene = await _create_scene()
	_configure_upload_settings(scene)
	scene.SETTINGS["projectCloudURL"] = "https://cloud.test/project-storage.php"
	scene.SETTINGS["projectCloudKey"] = "cloud_key"
	scene.SETTINGS["projectCloudName"] = "cloud_project"
	scene._queue_test_cloud_request_response({"ok": true, "http_code": 200})
	scene._set_test_image_upload_delay_seconds(0.35)
	scene._reset_test_image_upload_call_count()
	scene._queue_test_image_upload_response("https://upload.test/cloud_a.png")
	scene._queue_test_image_upload_response("https://upload.test/cloud_b.png")
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var order_before = scene.CONVERSATION_ORDER.duplicate()
	var temp_cloud = _create_temp_png("tmp_batch_upload_cloud.png", Color(0.8, 0.4, 0.1, 1.0))
	settings_ui._on_batch_creation_file_dialog_files_selected(PackedStringArray([temp_cloud]))
	await process_frame
	var save_ok = await scene._save_project_to_cloud()
	_assert_true(save_ok, "Cloud save should succeed when test cloud response reports success")
	_assert_true(not scene.is_batch_post_create_upload_running(), "Cloud save should wait for running batch post-create uploads")
	_assert_eq(scene._get_test_image_upload_call_count(), 1, "Cloud save should not trigger duplicate image upload while batch upload is already running")
	var new_ids = _get_new_conversation_ids(scene, order_before)
	_assert_eq(new_ids.size(), 1, "Cloud save test should create one batch conversation")
	if new_ids.size() > 0:
		var image_content = _get_first_image_content(scene, new_ids[0])
		_assert_true(image_content.begins_with("https://upload.test/"), "Cloud save waitpoint should keep uploaded image URL")
	_delete_temp_file(temp_cloud)
	await _destroy_scene(scene)

func _test_batch_creation_imports_supported_json_and_falls_back_to_text() -> void:
	var scene = await _create_scene()
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var order_before = scene.CONVERSATION_ORDER.duplicate()
	var import_json = JSON.stringify({"messages": [{"role": "user", "content": "Batch JSON import"}]})
	var fallback_json = JSON.stringify({"foo": "bar"})
	var invalid_json = "{invalid json"
	var temp_import = _create_temp_text_file("tmp_batch_import_messages.json", import_json)
	var temp_fallback = _create_temp_text_file("tmp_batch_fallback_object.json", fallback_json)
	var temp_invalid = _create_temp_text_file("tmp_batch_fallback_invalid.json", invalid_json)
	settings_ui._on_batch_creation_file_dialog_files_selected(PackedStringArray([temp_import, temp_fallback, temp_invalid]))
	await scene.wait_for_batch_post_create_uploads()
	await process_frame
	var new_ids = _get_new_conversation_ids(scene, order_before)
	_assert_eq(new_ids.size(), 3, "Batch JSON import should create one conversation per JSON file")
	if new_ids.size() >= 3:
		var imported_convo = _get_conversation(scene, new_ids[0])
		_assert_eq(imported_convo.size(), 2, "Supported JSON import conversation should contain meta plus imported message")
		if imported_convo.size() >= 2:
			_assert_eq(imported_convo[1].get("role", ""), "user", "Supported JSON import keeps user role")
			_assert_eq(imported_convo[1].get("type", ""), "Text", "Supported JSON import creates a text message")
			_assert_eq(imported_convo[1].get("textContent", ""), "Batch JSON import", "Supported JSON import uses message content")
			_assert_true(str(imported_convo[1].get("textContent", "")) != import_json, "Supported JSON import should not keep raw JSON as message text")
		var fallback_convo = _get_conversation(scene, new_ids[1])
		_assert_eq(fallback_convo.size(), 2, "Unsupported JSON fallback should contain meta plus text message")
		if fallback_convo.size() >= 2:
			_assert_eq(fallback_convo[1].get("type", ""), "Text", "Unsupported JSON fallback creates text message")
			_assert_eq(fallback_convo[1].get("textContent", ""), fallback_json, "Unsupported JSON fallback keeps raw JSON text")
		var invalid_convo = _get_conversation(scene, new_ids[2])
		_assert_eq(invalid_convo.size(), 2, "Invalid JSON fallback should contain meta plus text message")
		if invalid_convo.size() >= 2:
			_assert_eq(invalid_convo[1].get("type", ""), "Text", "Invalid JSON fallback creates text message")
			_assert_eq(invalid_convo[1].get("textContent", ""), invalid_json, "Invalid JSON fallback keeps raw file text")
	_delete_temp_file(temp_import)
	_delete_temp_file(temp_fallback)
	_delete_temp_file(temp_invalid)
	await _destroy_scene(scene)

func _test_batch_creation_imports_supported_json_schema_log() -> void:
	var scene = await _create_scene()
	scene.SCHEMAS = []
	var schemas_list = scene.get_node_or_null("Conversation/Schemas/SchemasList")
	if schemas_list != null and schemas_list.has_method("from_var"):
		schemas_list.from_var(scene.SCHEMAS)
	var settings_ui = scene.get_node("Conversation/Settings/ConversationSettings")
	var order_before = scene.CONVERSATION_ORDER.duplicate()
	var schema_name = "BatchSchemaImport"
	var log_json = JSON.stringify(_make_schema_log_entry(schema_name, _make_object_schema(schema_name, "ok", "boolean")))
	var temp_log = _create_temp_text_file("tmp_batch_schema_log.json", log_json)
	settings_ui._on_batch_creation_file_dialog_files_selected(PackedStringArray([temp_log]))
	await scene.wait_for_batch_post_create_uploads()
	await process_frame
	var new_ids = _get_new_conversation_ids(scene, order_before)
	_assert_eq(new_ids.size(), 1, "Batch schema log import should create one conversation")
	_assert_true(not _find_schema_by_name(scene, schema_name).is_empty(), "Batch schema log import should add imported schema")
	if new_ids.size() > 0:
		var imported_convo = _get_conversation(scene, new_ids[0])
		_assert_eq(imported_convo.size(), 3, "Batch schema log conversation should contain meta, request and response")
		if imported_convo.size() >= 3:
			_assert_eq(imported_convo[1].get("textContent", ""), "Bitte antworte als JSON", "Batch schema log imports request message")
			_assert_eq(imported_convo[2].get("type", ""), "JSON", "Batch schema log imports assistant response as JSON")
			_assert_eq(imported_convo[2].get("jsonSchemaName", ""), schema_name, "Batch schema log response selects imported schema")
	_delete_temp_file(temp_log)
	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_batch_creation_triggers_background_upload_and_button_state()
	await _test_export_waits_for_running_batch_uploads()
	await _test_cloud_save_waits_and_avoids_duplicate_uploads()
	await _test_batch_creation_imports_supported_json_and_falls_back_to_text()
	await _test_batch_creation_imports_supported_json_schema_log()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
