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

func _create_fine_tune_scene():
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.2).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame

func _test_sft_import() -> void:
	var scene = await _create_fine_tune_scene()
	var initial_count = scene.CONVERSATIONS.size()
	var sft_entry_1 = {
		"messages": [
			{"role": "user", "content": "Hello"},
			{"role": "assistant", "content": "Hi there"}
		]
	}
	var sft_entry_2 = {
		"messages": [
			{"role": "user", "content": "Weather in Berlin?"},
			{"role": "assistant", "content": "Cloudy"}
		],
		"tools": [
			{
				"type": "function",
				"function": {
					"name": "lookup_weather",
					"description": "Get weather",
					"parameters": {
						"type": "object",
						"properties": {
							"city": {"type": "string", "description": "City name"}
						},
						"required": ["city"]
					}
				}
			}
		]
	}
	var jsonl = JSON.stringify(sft_entry_1) + "\n" + JSON.stringify(sft_entry_2)
	var report = scene.import_finetune_jsonl_text(jsonl, "sft_train.jsonl")
	_assert_eq(report.get("detected_type", -1), 0, "SFT detected type")
	_assert_eq(report.get("imported", -1), 2, "SFT imported count")
	_assert_eq(report.get("skipped", -1), 0, "SFT skipped count")
	_assert_eq(scene.SETTINGS.get("finetuneType", -1), 0, "SFT switched finetuneType")
	_assert_eq(scene.CONVERSATIONS.size(), initial_count + 2, "SFT conversations appended")
	var created_ids = report.get("created_ids", [])
	_check(created_ids is Array and created_ids.size() == 2, "SFT created ids available")
	var first_convo = scene.CONVERSATIONS.get(created_ids[0], [])
	_check(first_convo.size() >= 3, "SFT first conversation has meta + messages")
	_assert_eq(first_convo[0].get("role", ""), "meta", "SFT first conversation starts with meta")
	_assert_eq(first_convo[0].get("metaData", {}).get("conversationName", ""), "sft_train.jsonl L1", "SFT meta conversation name")
	var imported_function = scene.get_function_definition("lookup_weather")
	_check(imported_function is Dictionary and imported_function.size() > 0, "SFT tools imported as function definition")
	await _destroy_scene(scene)

func _test_dpo_import() -> void:
	var scene = await _create_fine_tune_scene()
	var dpo_entry = {
		"input": {
			"messages": [
				{"role": "user", "content": "What is 2+2?"}
			]
		},
		"preferred_output": [
			{"role": "assistant", "content": "4"}
		],
		"non_preferred_output": [
			{"role": "assistant", "content": "5"}
		]
	}
	var report = scene.import_finetune_jsonl_text(JSON.stringify(dpo_entry), "dpo_train.jsonl")
	_assert_eq(report.get("detected_type", -1), 1, "DPO detected type")
	_assert_eq(report.get("imported", -1), 1, "DPO imported count")
	_assert_eq(scene.SETTINGS.get("finetuneType", -1), 1, "DPO switched finetuneType")
	var created_ids = report.get("created_ids", [])
	_check(created_ids is Array and created_ids.size() == 1, "DPO created ids available")
	var convo = scene.CONVERSATIONS.get(created_ids[0], [])
	_check(convo.size() >= 3, "DPO conversation has meta + converted messages")
	var assistant_found = false
	for msg in convo:
		if msg.get("role", "") == "assistant" and msg.get("type", "") == "Text":
			assistant_found = true
			_assert_eq(msg.get("preferredTextContent", ""), "4", "DPO preferred text")
			_assert_eq(msg.get("unpreferredTextContent", ""), "5", "DPO non preferred text")
			break
	_check(assistant_found, "DPO assistant training message exists")
	await _destroy_scene(scene)

func _test_rft_import_with_extra_fields() -> void:
	var scene = await _create_fine_tune_scene()
	var rft_entry = {
		"messages": [
			{"role": "user", "content": "Calculate 3+4"}
		],
		"tools": [
			{
				"type": "function",
				"function": {
					"name": "math_add",
					"description": "Adds two numbers",
					"parameters": {
						"type": "object",
						"properties": {
							"a": {"type": "number"},
							"b": {"type": "number"}
						},
						"required": ["a", "b"]
					}
				}
			}
		],
		"do_function_call": true,
		"ideal_function_call_data": {
			"name": "math_add",
			"arguments": {"a": 3, "b": 4},
			"functionUsePreText": "Let me calculate."
		},
		"reference_answer": "7",
		"reference_json": {"result": 7},
		"reward_signal": "high",
		"difficulty": "easy"
	}
	var report = scene.import_finetune_jsonl_text(JSON.stringify(rft_entry), "rft_train.jsonl")
	_assert_eq(report.get("detected_type", -1), 2, "RFT detected type")
	_assert_eq(report.get("imported", -1), 1, "RFT imported count")
	_assert_eq(scene.SETTINGS.get("finetuneType", -1), 2, "RFT switched finetuneType")
	var created_ids = report.get("created_ids", [])
	_check(created_ids is Array and created_ids.size() == 1, "RFT created ids available")
	var convo = scene.CONVERSATIONS.get(created_ids[0], [])
	var function_call_found = false
	for msg in convo:
		if msg.get("type", "") == "Function Call" and msg.get("functionName", "") == "math_add":
			function_call_found = true
			break
	_check(function_call_found, "RFT function call reference imported")
	_check(convo.size() >= 2, "RFT conversation has messages")
	var last_message = convo[convo.size() - 1]
	_assert_eq(last_message.get("type", ""), "JSON", "RFT extra fields appended as assistant JSON at end")
	var extra_data = JSON.parse_string(last_message.get("jsonSchemaValue", "{}"))
	_check(extra_data is Dictionary, "RFT extra fields JSON parseable")
	_assert_eq(extra_data.get("reward_signal", ""), "high", "RFT extra field reward_signal preserved")
	_assert_eq(extra_data.get("difficulty", ""), "easy", "RFT extra field difficulty preserved")
	await _destroy_scene(scene)

func _test_mixed_types_first_type_wins() -> void:
	var scene = await _create_fine_tune_scene()
	var sft_entry = {
		"messages": [
			{"role": "user", "content": "u"},
			{"role": "assistant", "content": "a"}
		]
	}
	var dpo_entry = {
		"input": {"messages": [{"role": "user", "content": "Question"}]},
		"preferred_output": [{"role": "assistant", "content": "Good"}],
		"non_preferred_output": [{"role": "assistant", "content": "Bad"}]
	}
	var jsonl = JSON.stringify(sft_entry) + "\n" + JSON.stringify(dpo_entry)
	var report = scene.import_finetune_jsonl_text(jsonl, "mixed_train.jsonl")
	_assert_eq(report.get("detected_type", -1), 0, "Mixed type detected from first valid line")
	_assert_eq(report.get("imported", -1), 1, "Mixed type imports only first type")
	_assert_eq(report.get("skipped", -1), 1, "Mixed type skips non matching line")
	await _destroy_scene(scene)

func _test_invalid_lines_partial_import() -> void:
	var scene = await _create_fine_tune_scene()
	var valid_entry = {
		"messages": [
			{"role": "user", "content": "Hello"},
			{"role": "assistant", "content": "Hi"}
		]
	}
	var jsonl = "{invalid json}\n{}\n" + JSON.stringify(valid_entry)
	var report = scene.import_finetune_jsonl_text(jsonl, "invalid_train.jsonl")
	_assert_eq(report.get("imported", -1), 1, "Invalid lines still allow partial import")
	_assert_eq(report.get("skipped", -1), 2, "Invalid lines counted as skipped")
	var errors = report.get("errors", [])
	_check(errors is Array and errors.size() >= 2, "Invalid lines report contains details")
	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_sft_import()
	await _test_dpo_import()
	await _test_rft_import_with_extra_fields()
	await _test_mixed_types_first_type_wins()
	await _test_invalid_lines_partial_import()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
