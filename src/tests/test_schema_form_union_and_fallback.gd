extends SceneTree

var tests_run = 0
var tests_failed = 0

func assert_true(condition: bool, name: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error("Assertion failed: " + name)

func _get_object_property_descriptor(object_descriptor: Dictionary, property_name: String) -> Dictionary:
	var properties = object_descriptor.get("properties", [])
	if not (properties is Array):
		return {}
	for property_data in properties:
		if not (property_data is Dictionary):
			continue
		if str(property_data.get("name", "")) != property_name:
			continue
		var descriptor = property_data.get("descriptor", {})
		if descriptor is Dictionary:
			return descriptor
		return {}
	return {}

func _count_option_buttons(node: Node) -> int:
	var count = 0
	if node is OptionButton:
		count += 1
	for child in node.get_children():
		if child is Node:
			count += _count_option_buttons(child)
	return count

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

	var nullable_any_of_schema = {
		"type": "object",
		"required": ["duration", "arrow_color"],
		"properties": {
			"duration": {
				"anyOf": [
					{
						"type": "object",
						"required": ["amount", "unit"],
						"properties": {
							"amount": {"type": "number", "minimum": 0.0},
							"unit": {"type": "string", "enum": ["minute", "hour"]}
						},
						"additionalProperties": false
					},
					{"type": "null"}
				]
			},
			"arrow_color": {
				"anyOf": [
					{"type": "string", "enum": ["red", "blue"]},
					{"type": "null"}
				]
			}
		},
		"additionalProperties": false
	}
	controller.load_schema(nullable_any_of_schema)
	var nullable_root_descriptor = controller._descriptor
	var duration_descriptor = _get_object_property_descriptor(nullable_root_descriptor, "duration")
	var arrow_color_descriptor = _get_object_property_descriptor(nullable_root_descriptor, "arrow_color")
	assert_true(str(duration_descriptor.get("kind", "")) == "union", "duration remains union kind")
	assert_true(bool(duration_descriptor.get("nullable", false)), "duration union marked nullable")
	assert_true(bool(duration_descriptor.get("null_branch_optional", false)), "duration union uses include-style null toggle")
	assert_true(duration_descriptor.get("branches", []).size() == 1, "duration union removes explicit null branch")
	assert_true(str(arrow_color_descriptor.get("kind", "")) == "union", "arrow_color remains union kind")
	assert_true(bool(arrow_color_descriptor.get("nullable", false)), "arrow_color union marked nullable")
	assert_true(bool(arrow_color_descriptor.get("null_branch_optional", false)), "arrow_color union uses include-style null toggle")
	assert_true(arrow_color_descriptor.get("branches", []).size() == 1, "arrow_color union removes explicit null branch")
	var nullable_result = controller.set_value_from_json("{\"duration\":null,\"arrow_color\":null}")
	assert_true(nullable_result.get("ok", false), "nullable anyOf JSON parses")
	var nullable_parsed = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(nullable_parsed is Dictionary, "nullable anyOf parsed object")
	assert_true(nullable_parsed.has("duration") and nullable_parsed["duration"] == null, "duration keeps null value")
	assert_true(nullable_parsed.has("arrow_color") and nullable_parsed["arrow_color"] == null, "arrow_color keeps null value")
	assert_true(controller.get_validation_errors().is_empty(), "nullable anyOf values pass form validation")

	var multi_nullable_union_schema = {
		"type": "object",
		"required": ["value"],
		"properties": {
			"value": {
				"oneOf": [
					{"type": "null"},
					{"type": "string"},
					{"type": "number"}
				]
			}
		},
		"additionalProperties": false
	}
	controller.load_schema(multi_nullable_union_schema)
	var multi_root_descriptor = controller._descriptor
	var value_descriptor = _get_object_property_descriptor(multi_root_descriptor, "value")
	assert_true(str(value_descriptor.get("kind", "")) == "union", "multi oneOf stays union")
	assert_true(bool(value_descriptor.get("nullable", false)), "multi oneOf marked nullable")
	assert_true(bool(value_descriptor.get("null_branch_optional", false)), "multi oneOf uses include-style null toggle")
	assert_true(value_descriptor.get("branches", []).size() == 2, "multi oneOf keeps only non-null branches")
	var branch_kinds = []
	for branch in value_descriptor.get("branches", []):
		if branch is Dictionary:
			branch_kinds.append(str(branch.get("kind", "")))
	assert_true(branch_kinds.has("string") and branch_kinds.has("number"), "multi oneOf branch selector excludes null kind")
	controller.set_value_from_json("{\"value\":null}")
	assert_true(controller.get_validation_errors().is_empty(), "multi oneOf accepts null while include is off")
	controller._on_nullable_include_toggled(true, ["value"], value_descriptor)
	var include_enabled_value = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(include_enabled_value is Dictionary and include_enabled_value.get("value", null) != null, "include toggle on sets non-null branch default")
	controller._on_nullable_include_toggled(false, ["value"], value_descriptor)
	var include_disabled_value = JSON.parse_string(controller.get_value_as_json(false))
	assert_true(include_disabled_value is Dictionary and include_disabled_value.has("value") and include_disabled_value["value"] == null, "include toggle off sets value back to null")

	var single_non_null_branch_schema = {
		"type": "object",
		"required": ["value"],
		"properties": {
			"value": {
				"anyOf": [
					{"type": "null"},
					{"type": "string"}
				]
			}
		}
	}
	controller.load_schema(single_non_null_branch_schema)
	controller.set_value_from_json("{\"value\":\"hello\"}")
	await process_frame
	assert_true(_count_option_buttons(root) == 0, "single non-null branch union does not render branch selector")

	var multi_non_null_branch_schema = {
		"type": "object",
		"required": ["value"],
		"properties": {
			"value": {
				"anyOf": [
					{"type": "null"},
					{"type": "string"},
					{"type": "number"}
				]
			}
		}
	}
	controller.load_schema(multi_non_null_branch_schema)
	controller.set_value_from_json("{\"value\":\"hello\"}")
	await process_frame
	assert_true(_count_option_buttons(root) >= 1, "multi non-null branch union renders branch selector")

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
