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

	var local_defs_schema = {
		"type": "object",
		"required": ["goals"],
		"properties": {
			"goals": {
				"type": "array",
				"items": {"$ref": "#/$defs/goal"}
			}
		},
		"$defs": {
			"distance": {
				"type": "object",
				"properties": {
					"amount": {"type": "number"}
				}
			},
			"goal": {
				"type": "object",
				"properties": {
					"name": {"type": "string"},
					"distance": {"$ref": "#/$defs/distance"}
				}
			}
		}
	}
	var local_defs_resolved = resolver.resolve_schema(local_defs_schema)
	assert_true(not bool(local_defs_resolved.get("has_external_ref", true)), "local defs ref does not count as unresolved external ref")
	assert_true(not bool(local_defs_resolved.get("has_ref_cycle", true)), "nonrecursive local refs do not create cycle marker")
	var local_goals_items = local_defs_resolved.get("schema", {}).get("properties", {}).get("goals", {}).get("items", {})
	assert_true(local_goals_items is Dictionary, "local array item schema is dictionary")
	assert_true(str(local_goals_items.get("$ref", "")) == "", "local array item ref is expanded")
	assert_true(local_goals_items.get("properties", {}).has("name"), "local array item contains referenced property")
	var local_distance = local_goals_items.get("properties", {}).get("distance", {})
	assert_true(local_distance.get("properties", {}).has("amount"), "nested local ref is expanded")

	var local_recursive_schema = {
		"$id": "https://example.com/schemas/tree.json",
		"type": "object",
		"properties": {
			"root": {"$ref": "#/$defs/node"}
		},
		"$defs": {
			"node": {
				"type": "object",
				"properties": {
					"name": {"type": "string"},
					"children": {
						"type": "array",
						"items": {"$ref": "#/$defs/node"}
					}
				}
			}
		}
	}
	var local_resolved = resolver.resolve_schema(local_recursive_schema)
	assert_true(not bool(local_resolved.get("has_external_ref", true)), "local ref does not count as unresolved external ref")
	assert_true(bool(local_resolved.get("has_ref_cycle", false)), "recursive local ref becomes a cycle marker")
	var local_schema_after = local_resolved.get("schema", {})
	var root_schema = local_schema_after.get("properties", {}).get("root", {})
	assert_true(root_schema.get("properties", {}).has("name"), "local root ref is expanded")
	var nested_item = root_schema.get("properties", {}).get("children", {}).get("items", {})
	assert_true(nested_item.has("x_ftc_ref_cycle"), "recursive nested ref becomes cycle marker")
	var nested_ref = local_schema_after.get("$defs", {}).get("node", {}).get("properties", {}).get("children", {}).get("items", {}).get("$ref", "")
	assert_true(str(nested_ref) == "#/$defs/node", "$defs are copied without eager expansion")

	var local_urls = resolver.collect_external_document_urls(local_recursive_schema)
	assert_true(local_urls.is_empty(), "same-document refs must not be treated as external urls")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
