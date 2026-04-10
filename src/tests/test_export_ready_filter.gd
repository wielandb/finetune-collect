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

func _build_conversation(display_name: String, is_ready: bool, user_text: String, assistant_text: String) -> Array:
	return [
		{
			"role": "meta",
			"type": "meta",
			"metaData": {
				"ready": is_ready,
				"conversationName": display_name,
				"notes": ""
			}
		},
		{
			"role": "user",
			"type": "Text",
			"textContent": user_text
		},
		{
			"role": "assistant",
			"type": "Text",
			"textContent": assistant_text
		}
	]

func _jsonl_lines(jsonl: String) -> Array:
	var lines = []
	for raw_line in jsonl.split("\n"):
		var line = str(raw_line).strip_edges()
		if line != "":
			lines.append(line)
	return lines

func _has_assistant_content(entry: Dictionary, marker: String) -> bool:
	var messages = entry.get("messages", [])
	if not (messages is Array):
		return false
	for msg in messages:
		if msg is Dictionary and str(msg.get("role", "")) == "assistant":
			if str(msg.get("content", "")).find(marker) != -1:
				return true
	return false

func _test_export_only_ready_conversations() -> void:
	var scene = await _create_scene()
	scene.CONVERSATIONS = {}
	scene.CONVERSATION_ORDER = []
	scene.CURRENT_EDITED_CONVO_IX = ""
	scene.create_new_conversation(_build_conversation("Nur fertig", true, "READY_USER", "READY_MARKER"))
	scene.create_new_conversation(_build_conversation("Nicht fertig", false, "DRAFT_USER", "DRAFT_MARKER"))
	scene.SETTINGS["exportConvos"] = 1
	scene.SETTINGS["finetuneType"] = 0

	var jsonl = await scene.create_jsonl_data_for_file()
	var lines = _jsonl_lines(jsonl)
	_assert_eq(lines.size(), 1, "Nur fertige should export exactly one conversation")
	if lines.size() == 1:
		var parsed = JSON.parse_string(lines[0])
		_assert_true(parsed is Dictionary, "Export line should parse as dictionary")
		if parsed is Dictionary:
			_assert_true(_has_assistant_content(parsed, "READY_MARKER"), "Ready conversation must be exported")
			_assert_true(not _has_assistant_content(parsed, "DRAFT_MARKER"), "Not-ready conversation must not be exported")

	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_export_only_ready_conversations()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
