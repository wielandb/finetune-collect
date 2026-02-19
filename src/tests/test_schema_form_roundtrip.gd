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
	controller.set_value_at_path(["active"], true, false)
	var parsed2 = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(parsed2.get("active", false) == true, "set_value_at_path updates value")
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
