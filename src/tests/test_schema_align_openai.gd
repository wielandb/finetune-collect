extends SceneTree

var tests_run = 0
var tests_failed = 0

func assert_eq(a, b, name = ""):
	tests_run += 1
	if a != b:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(b), str(a)])

func assert_has_error_code(errors: Array, code: String, name = "") -> void:
	tests_run += 1
	for entry in errors:
		if entry is Dictionary and str(entry.get("code", "")) == code:
			return
	tests_failed += 1
	push_error("Assertion failed %s: missing error code %s in %s" % [name, code, JSON.stringify(errors)])

func test_sanitize():
	var align = load("res://scenes/schemas/schema_align_openai.gd")
	var schema = {
		"title": "Person",
		"type": "object",
		"properties": {
			"name": {"type": "string", "minLength": 1}
		},
		"additionalProperties": true,
		"allOf": [],
		"required": []
	}
	var report = align.sanitize_envelope_or_schema_with_report(schema)
	assert_eq(report["ok"], true, "report ok")
	var out = report["result"]
	assert_eq(out["name"], "Person", "name extracted")
	var s = out["schema"]
	assert_eq(s["additionalProperties"], false, "additionalProperties")
	assert_eq(s["required"][0], "name", "required filled")
	assert_eq(s.has("allOf"), false, "allOf removed")
	assert_eq(s["properties"]["name"].has("minLength"), false, "minLength removed")

func test_too_many_enums():
	var align = load("res://scenes/schemas/schema_align_openai.gd")
	var enum_values = []
	for i in range(1001):
		enum_values.append("v%d" % i)
	var schema = {
		"type": "object",
		"properties": {
			"choice": {
				"type": "string",
				"enum": enum_values
			}
		}
	}
	var report = align.sanitize_envelope_or_schema_with_report(schema)
	assert_eq(report["ok"], false, "too many enum values invalid")
	assert_has_error_code(report["errors"], "too_many_enum_values", "too many enum values code")

func _init():
	test_sanitize()
	test_too_many_enums()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
