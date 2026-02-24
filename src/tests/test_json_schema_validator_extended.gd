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
	_test_ref_enum()
	_test_union_and_one_of()
	_test_array_constraints()
	_test_nullable_union_type()
	_test_schema_keyword_integer_numbers_from_json()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

func _test_ref_enum() -> void:
	var schema = {
		"type": "object",
		"properties": {
			"status": {"$ref": "#/$defs/status"}
		},
		"required": ["status"],
		"$defs": {
			"status": {
				"type": "string",
				"enum": ["ok", "error"]
			}
		}
	}
	var ok_result = JsonSchemaValidator.validate({"status": "ok"}, schema)
	assert_true(ok_result.get("ok", false), "ref enum valid")
	var bad_result = JsonSchemaValidator.validate({"status": "wrong"}, schema)
	assert_true(not bad_result.get("ok", true), "ref enum invalid value")

func _test_union_and_one_of() -> void:
	var one_of_schema = {
		"oneOf": [
			{"type": "string"},
			{"type": "number"}
		]
	}
	assert_true(JsonSchemaValidator.validate("abc", one_of_schema).get("ok", false), "oneOf string")
	assert_true(JsonSchemaValidator.validate(12, one_of_schema).get("ok", false), "oneOf number")
	assert_true(not JsonSchemaValidator.validate(true, one_of_schema).get("ok", true), "oneOf rejects bool")

func _test_array_constraints() -> void:
	var schema = {
		"type": "array",
		"minItems": 1,
		"uniqueItems": true,
		"items": {"type": "integer", "minimum": 0}
	}
	assert_true(JsonSchemaValidator.validate([1, 2], schema).get("ok", false), "array valid")
	assert_true(not JsonSchemaValidator.validate([], schema).get("ok", true), "array minItems")
	assert_true(not JsonSchemaValidator.validate([1, 1], schema).get("ok", true), "array uniqueItems")
	assert_true(not JsonSchemaValidator.validate([1, -1], schema).get("ok", true), "array item minimum")

func _test_nullable_union_type() -> void:
	var schema = {"type": ["string", "null"]}
	assert_true(JsonSchemaValidator.validate("hello", schema).get("ok", false), "nullable union string")
	assert_true(JsonSchemaValidator.validate(null, schema).get("ok", false), "nullable union null")
	assert_true(not JsonSchemaValidator.validate(3, schema).get("ok", true), "nullable union rejects number")

func _test_schema_keyword_integer_numbers_from_json() -> void:
	var parsed_valid = JSON.parse_string("{\"type\":\"object\",\"properties\":{\"title\":{\"type\":\"string\",\"minLength\":1,\"maxLength\":50},\"items\":{\"type\":\"array\",\"minItems\":1,\"maxItems\":3,\"items\":{\"type\":\"string\"}}},\"required\":[\"title\",\"items\"],\"additionalProperties\":false}")
	assert_true(parsed_valid is Dictionary, "json parse valid schema")
	if not (parsed_valid is Dictionary):
		return
	var valid_result = JsonSchemaValidator.validate_schema(parsed_valid)
	assert_true(valid_result.get("ok", false), "validate_schema accepts integer-valued JSON numbers")

	var parsed_invalid = JSON.parse_string("{\"type\":\"object\",\"properties\":{\"title\":{\"type\":\"string\",\"maxLength\":2.5}}}")
	assert_true(parsed_invalid is Dictionary, "json parse invalid schema")
	if not (parsed_invalid is Dictionary):
		return
	var invalid_result = JsonSchemaValidator.validate_schema(parsed_invalid)
	assert_true(not invalid_result.get("ok", true), "validate_schema rejects non-integer number for integer keywords")
