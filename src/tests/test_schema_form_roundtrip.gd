extends SceneTree

var tests_run = 0
var tests_failed = 0

func assert_true(condition: bool, name: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error("Assertion failed: " + name)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root = VBoxContainer.new()
	get_root().add_child(root)
	var controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	controller.bind_form_root(root)
	var schema = {
		"type": "object",
		"required": ["name", "count"],
		"properties": {
			"name": {"type": "string", "default": "unknown"},
			"count": {"type": "integer", "minimum": 1, "default": 1},
			"active": {"type": "boolean", "default": false}
		},
		"additionalProperties": false
	}
	controller.load_schema(schema)
	var result = controller.set_value_from_json("{\"name\":\"Alice\"}")
	assert_true(result.get("ok", false), "set_value_from_json ok")
	var parsed = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed is Dictionary, "parsed is dictionary")
	assert_true(parsed.get("name", "") == "Alice", "name roundtrip")
	assert_true(parsed.get("count", -1) == 1, "required default for count")
	await process_frame
	var spin_boxes = root.find_children("*", "SpinBox", true, false)
	assert_true(spin_boxes.size() == 1, "one numeric field rendered")
	if spin_boxes.size() == 1:
		var count_spin = spin_boxes[0]
		assert_true(abs(float(count_spin.min_value) - 1.0) < 0.001, "numeric field keeps schema minimum")
		count_spin.value = 1000.0
		count_spin.emit_signal("value_changed", count_spin.value)
		var parsed_after_spin = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_spin.get("count", -1) == 1000, "numeric field does not impose default maximum")
	controller.set_value_at_path(["active"], true, false)
	var parsed2 = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed2.get("active", false) == true, "set_value_at_path updates value")
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
