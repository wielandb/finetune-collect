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
		"title": "Person",
		"type": "object",
		"properties": {
			"name": {"type": "string", "minLength": 1}
		},
		"additionalProperties": true,
		"allOf": [],
		"required": []
	}
	var out = align.sanitize_envelope_or_schema(schema)
	assert_eq(out["name"], "Person", "name extracted")
	var s = out["schema"]
	assert_eq(s["additionalProperties"], false, "additionalProperties")
	assert_eq(s["required"][0], "name", "required filled")
	assert_eq(s.has("allOf"), false, "allOf removed")
	assert_eq(s["properties"]["name"].has("minLength"), false, "minLength removed")

func _init():
	test_sanitize()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
