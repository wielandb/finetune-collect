extends SceneTree

var tests_run := 0
var tests_failed := 0

func assert_eq(a, b, name := ""):
	tests_run += 1
	if a != b:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(b), str(a)])

func test_sanitize():
	var align = load("res://scenes/schemas/schema_align_openai.gd")
	var schema = {
		"type": "object",
		"properties": {
			"name": {"type": "string", "minLength": 1}
		},
		"additionalProperties": true,
		"allOf": [],
		"required": []
	}
	var out = align.sanitize_envelope_or_schema(schema)
	assert_eq(out["additionalProperties"], false, "additionalProperties")
	assert_eq(out["required"][0], "name", "required filled")
	assert_eq(out.has("allOf"), false, "allOf removed")
	assert_eq(out["properties"]["name"].has("minLength"), false, "minLength removed")

func _init():
	test_sanitize()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
