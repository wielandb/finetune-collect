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
	var union_schema = {
		"oneOf": [
			{"type": "string"},
			{"type": "number"}
		]
	}
	controller.load_schema(union_schema)
	controller.set_value_from_json("\"hello\"")
	var union_descriptor = controller._descriptor
	var active_ix = controller.get_union_branch_index([], union_descriptor)
	assert_true(active_ix == 0, "union selects string branch")
	controller._on_union_branch_selected(1, [], union_descriptor)
	var switched = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(switched is float or switched is int, "union branch switch resets to number value")

	var fallback_schema = {
		"type": "object",
		"properties": {
			"meta": {
				"type": "object",
				"patternProperties": {
					"^x-": {"type": "string"}
				}
			}
		}
	}
	controller.load_schema(fallback_schema)
	assert_true(controller.has_partial_fallback(), "unsupported keyword triggers partial fallback")
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
