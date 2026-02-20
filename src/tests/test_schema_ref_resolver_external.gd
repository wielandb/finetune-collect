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
	var resolver = load("res://scenes/schema_runtime/schema_ref_resolver.gd")
	var schema = {
		"type": "object",
		"properties": {
			"user": {
				"$ref": "https://example.com/schemas/person.json#/$defs/person"
			}
		}
	}
	var external_schemas = {
		"https://example.com/schemas/person.json": {
			"$defs": {
				"person": {
					"type": "object",
					"properties": {
						"name": {"type": "string"}
					},
					"required": ["name"]
				}
			}
		}
	}

	var resolved = resolver.resolve_schema(schema, external_schemas)
	assert_true(not bool(resolved.get("has_external_ref", true)), "external schema ref resolved")
	var resolved_schema = resolved.get("schema", null)
	assert_true(resolved_schema is Dictionary, "resolved schema is dictionary")
	var user_schema = {}
	if resolved_schema is Dictionary:
		user_schema = resolved_schema.get("properties", {}).get("user", {})
	assert_true(user_schema is Dictionary, "resolved user schema exists")
	assert_true(user_schema.get("properties", {}).has("name"), "resolved user schema contains remote property")

	var unresolved = resolver.resolve_schema(schema)
	assert_true(bool(unresolved.get("has_external_ref", false)), "missing external ref marked as unresolved")

	var urls = resolver.collect_external_document_urls(schema)
	assert_true(urls.size() == 1, "one external url collected")
	if urls.size() == 1:
		assert_true(urls[0] == "https://example.com/schemas/person.json", "external url normalized")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
