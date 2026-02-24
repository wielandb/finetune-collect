extends RefCounted

class_name SchemaFormCompiler

var _has_partial_fallback = false

const UNSUPPORTED_FALLBACK_KEYS = [
	"patternProperties",
	"propertyNames",
	"if",
	"then",
	"else",
	"dependencies",
	"dependentRequired",
	"dependentSchemas",
	"contains",
	"prefixItems",
	"unevaluatedProperties",
	"unevaluatedItems"
]

func compile_schema(schema: Dictionary) -> Dictionary:
	_has_partial_fallback = false
	var descriptor = _compile_node(schema, "")
	return {
		"descriptor": descriptor,
		"has_partial_fallback": _has_partial_fallback
	}

func _compile_node(schema, pointer: String) -> Dictionary:
	if not (schema is Dictionary):
		return _fallback_descriptor(schema, "Schema node is not an object", pointer)

	if schema.has("x_ftc_external_ref"):
		return _fallback_descriptor(schema, "External or unresolved $ref", pointer)
	if schema.has("x_ftc_ref_cycle"):
		return _fallback_descriptor(schema, "Cyclic $ref detected", pointer)
	if _contains_unsupported_keywords(schema):
		return _fallback_descriptor(schema, "Unsupported JSON-Schema keyword in this node", pointer)

	if schema.has("allOf"):
		var merged = _merge_all_of_schema(schema)
		if not merged["ok"]:
			return _fallback_descriptor(schema, merged.get("reason", "allOf merge conflict"), pointer)
		return _compile_node(merged["schema"], pointer)

	if schema.has("oneOf") or schema.has("anyOf"):
		return _compile_union_schema(schema, pointer)

	var type_info = _get_type_info(schema)
	var nullable = type_info.get("nullable", false)

	if type_info.get("has_multi_type_union", false):
		var type_union_descriptor = _compile_type_union(schema, type_info.get("types", []), pointer)
		type_union_descriptor["nullable"] = nullable
		_apply_common_metadata(type_union_descriptor, schema, pointer)
		return type_union_descriptor

	if schema.has("const"):
		var const_descriptor = {
			"kind": "const",
			"const_value": schema["const"],
			"nullable": nullable
		}
		_apply_common_metadata(const_descriptor, schema, pointer)
		return const_descriptor

	if schema.has("enum") and schema["enum"] is Array:
		var enum_descriptor = {
			"kind": "enum",
			"enum_values": schema["enum"].duplicate(true),
			"nullable": nullable
		}
		_apply_common_metadata(enum_descriptor, schema, pointer)
		return enum_descriptor

	var kind = type_info.get("kind", "")
	match kind:
		"object":
			return _compile_object_schema(schema, pointer, nullable)
		"array":
			return _compile_array_schema(schema, pointer, nullable)
		"string":
			return _compile_string_schema(schema, pointer, nullable)
		"number", "integer":
			return _compile_number_schema(schema, pointer, nullable, kind)
		"boolean":
			return _compile_boolean_schema(schema, pointer, nullable)
		"null":
			return _compile_null_schema(schema, pointer)
		_:
			return _fallback_descriptor(schema, "Could not infer schema type", pointer)

func _compile_object_schema(schema: Dictionary, pointer: String, nullable: bool) -> Dictionary:
	var descriptor = {
		"kind": "object",
		"properties": [],
		"required": [],
		"additional_properties": schema.get("additionalProperties", true),
		"nullable": nullable
	}
	var required = []
	if schema.has("required") and schema["required"] is Array:
		required = schema["required"].duplicate()
	descriptor["required"] = required
	var props = schema.get("properties", {})
	if not (props is Dictionary):
		return _fallback_descriptor(schema, "Object schema has invalid properties", pointer)
	for prop_name in props.keys():
		var child_schema = props[prop_name]
		var child_pointer = pointer + "/" + _escape_pointer_segment(str(prop_name))
		var child_descriptor = _compile_node(child_schema, child_pointer)
		descriptor["properties"].append({
			"name": str(prop_name),
			"required": required.has(prop_name),
			"descriptor": child_descriptor
		})
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_array_schema(schema: Dictionary, pointer: String, nullable: bool) -> Dictionary:
	var items = schema.get("items", null)
	if not (items is Dictionary):
		return _fallback_descriptor(schema, "Array schema needs object items schema", pointer)
	var descriptor = {
		"kind": "array",
		"items": _compile_node(items, pointer + "/items"),
		"min_items": schema.get("minItems", 0),
		"max_items": schema.get("maxItems", -1),
		"unique_items": bool(schema.get("uniqueItems", false)),
		"nullable": nullable
	}
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_string_schema(schema: Dictionary, pointer: String, nullable: bool) -> Dictionary:
	var descriptor = {
		"kind": "string",
		"min_length": schema.get("minLength", -1),
		"max_length": schema.get("maxLength", -1),
		"pattern": schema.get("pattern", ""),
		"format": schema.get("format", ""),
		"nullable": nullable
	}
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_number_schema(schema: Dictionary, pointer: String, nullable: bool, kind: String) -> Dictionary:
	var descriptor = {
		"kind": kind,
		"minimum": schema.get("minimum", null),
		"maximum": schema.get("maximum", null),
		"exclusive_minimum": schema.get("exclusiveMinimum", null),
		"exclusive_maximum": schema.get("exclusiveMaximum", null),
		"multiple_of": schema.get("multipleOf", null),
		"nullable": nullable
	}
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_boolean_schema(schema: Dictionary, pointer: String, nullable: bool) -> Dictionary:
	var descriptor = {
		"kind": "boolean",
		"nullable": nullable
	}
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_null_schema(schema: Dictionary, pointer: String) -> Dictionary:
	var descriptor = {
		"kind": "null",
		"nullable": true
	}
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _compile_union_schema(schema: Dictionary, pointer: String) -> Dictionary:
	var mode = "oneOf"
	var branches = schema.get("oneOf", [])
	if schema.has("anyOf"):
		mode = "anyOf"
		branches = schema.get("anyOf", [])
	if not (branches is Array):
		return _fallback_descriptor(schema, mode + " must be an array", pointer)
	var descriptor = {
		"kind": "union",
		"mode": mode,
		"branches": [],
		"nullable": false,
		"null_branch_optional": false
	}
	var has_explicit_null_branch = false
	for i in range(branches.size()):
		var branch = branches[i]
		var branch_pointer = pointer + "/" + mode + "/" + str(i)
		if _is_explicit_null_union_branch(branch):
			has_explicit_null_branch = true
			continue
		descriptor["branches"].append(_compile_node(branch, branch_pointer))
	if has_explicit_null_branch:
		descriptor["nullable"] = true
		descriptor["null_branch_optional"] = descriptor["branches"].size() > 0
	if descriptor["branches"].is_empty():
		if has_explicit_null_branch:
			return _compile_null_schema(schema, pointer)
		return _fallback_descriptor(schema, mode + " has no branches", pointer)
	_apply_common_metadata(descriptor, schema, pointer)
	return descriptor

func _is_explicit_null_union_branch(branch) -> bool:
	if not (branch is Dictionary):
		return false
	if not branch.has("type"):
		return false
	var t = branch.get("type")
	if t is String:
		return t == "null"
	if t is Array:
		if t.is_empty():
			return false
		for entry in t:
			if not (entry is String) or entry != "null":
				return false
		return true
	return false

func _compile_type_union(schema: Dictionary, types: Array, pointer: String) -> Dictionary:
	var descriptor = {
		"kind": "union",
		"mode": "typeUnion",
		"branches": []
	}
	for t in types:
		if not (t is String):
			continue
		var branch_schema = schema.duplicate(true)
		branch_schema["type"] = t
		descriptor["branches"].append(_compile_node(branch_schema, pointer + "/type/" + t))
	return descriptor

func _get_type_info(schema: Dictionary) -> Dictionary:
	var t = schema.get("type", null)
	if t is String:
		return {
			"kind": t,
			"nullable": false,
			"has_multi_type_union": false
		}
	if t is Array:
		var nullable = false
		var filtered = []
		for entry in t:
			if not (entry is String):
				continue
			if entry == "null":
				nullable = true
				continue
			if not filtered.has(entry):
				filtered.append(entry)
		if filtered.size() == 1:
			return {
				"kind": filtered[0],
				"nullable": nullable,
				"has_multi_type_union": false
			}
		if filtered.size() > 1:
			return {
				"kind": "union",
				"types": filtered,
				"nullable": nullable,
				"has_multi_type_union": true
			}
	if schema.has("properties"):
		return {"kind": "object", "nullable": false, "has_multi_type_union": false}
	if schema.has("items"):
		return {"kind": "array", "nullable": false, "has_multi_type_union": false}
	if schema.has("enum"):
		return {"kind": "enum", "nullable": false, "has_multi_type_union": false}
	return {"kind": "", "nullable": false, "has_multi_type_union": false}

func _contains_unsupported_keywords(schema: Dictionary) -> bool:
	for key in schema.keys():
		var key_name = str(key)
		if key_name.begins_with("unevaluated"):
			return true
		if UNSUPPORTED_FALLBACK_KEYS.has(key_name):
			return true
		if key_name == "items" and schema[key_name] is Array:
			return true
	return false

func _apply_common_metadata(descriptor: Dictionary, schema: Dictionary, pointer: String) -> void:
	descriptor["pointer"] = pointer
	descriptor["title"] = str(schema.get("title", ""))
	descriptor["description"] = str(schema.get("description", ""))
	if schema.has("default"):
		descriptor["default"] = schema["default"]

func _fallback_descriptor(schema, reason: String, pointer: String) -> Dictionary:
	_has_partial_fallback = true
	var title = ""
	var description = ""
	if schema is Dictionary:
		title = str(schema.get("title", ""))
		description = str(schema.get("description", ""))
	return {
		"kind": "fallback",
		"reason": reason,
		"pointer": pointer,
		"title": title,
		"description": description,
		"source_schema": schema
	}

func _merge_all_of_schema(schema: Dictionary) -> Dictionary:
	var all_of_items = schema.get("allOf", [])
	if not (all_of_items is Array) or all_of_items.is_empty():
		return {"ok": false, "reason": "allOf is empty"}
	var merged = schema.duplicate(true)
	merged.erase("allOf")
	for item in all_of_items:
		if not (item is Dictionary):
			return {"ok": false, "reason": "allOf entry is not object"}
		var merge_result = _merge_object_like_schemas(merged, item)
		if not merge_result["ok"]:
			return merge_result
		merged = merge_result["schema"]
	return {"ok": true, "schema": merged}

func _merge_object_like_schemas(a: Dictionary, b: Dictionary) -> Dictionary:
	var out = a.duplicate(true)
	for key in b.keys():
		if key == "required":
			var req = out.get("required", [])
			if not (req is Array):
				req = []
			var incoming = b["required"]
			if incoming is Array:
				for item in incoming:
					if not req.has(item):
						req.append(item)
			out["required"] = req
			continue
		if key == "properties":
			var existing_props = out.get("properties", {})
			if not (existing_props is Dictionary):
				existing_props = {}
			var incoming_props = b["properties"]
			if not (incoming_props is Dictionary):
				return {"ok": false, "reason": "properties conflict in allOf"}
			for prop_name in incoming_props.keys():
				if existing_props.has(prop_name):
					var left_prop = existing_props[prop_name]
					var right_prop = incoming_props[prop_name]
					if left_prop is Dictionary and right_prop is Dictionary:
						var child_merge = _merge_object_like_schemas(left_prop, right_prop)
						if not child_merge["ok"]:
							return {"ok": false, "reason": "property conflict in allOf: " + str(prop_name)}
						existing_props[prop_name] = child_merge["schema"]
					elif JSON.stringify(left_prop) != JSON.stringify(right_prop):
						return {"ok": false, "reason": "property conflict in allOf: " + str(prop_name)}
				else:
					existing_props[prop_name] = incoming_props[prop_name]
			out["properties"] = existing_props
			continue
		if key == "additionalProperties":
			var left_ap = out.get("additionalProperties", true)
			var right_ap = b[key]
			if left_ap == false or right_ap == false:
				out["additionalProperties"] = false
			else:
				out["additionalProperties"] = right_ap
			continue
		if key == "title" or key == "description" or key == "default" or key == "$defs" or key == "definitions":
			if not out.has(key):
				out[key] = b[key]
			continue
		if not out.has(key):
			out[key] = b[key]
			continue
		if JSON.stringify(out[key]) != JSON.stringify(b[key]):
			return {"ok": false, "reason": "allOf conflict on key: " + str(key)}
	return {"ok": true, "schema": out}

func _escape_pointer_segment(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")
