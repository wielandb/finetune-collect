extends RefCounted

# Utility to sanitize JSON Schemas for OpenAI Structured Outputs compliance.
# Inspired by scripts/schema_align_openai.php

const _ALLOWED_STRING_FORMATS = [
	"date-time",
	"time",
	"date",
	"duration",
	"email",
	"hostname",
	"ipv4",
	"ipv6",
	"uuid"
]

const _ALLOWED_TYPES = [
	"string",
	"number",
	"boolean",
	"integer",
	"object",
	"array",
	"null"
]

const _SCHEMA_KEYS = [
	"type",
	"properties",
	"required",
	"items",
	"enum",
	"anyOf",
	"$ref",
	"$defs",
	"definitions",
	"additionalProperties",
	"description",
	"pattern",
	"format",
	"multipleOf",
	"maximum",
	"exclusiveMaximum",
	"minimum",
	"exclusiveMinimum",
	"minItems",
	"maxItems",
	"const"
]

const _MAX_TOTAL_PROPERTIES = 5000
const _MAX_NESTING_DEPTH = 10
const _MAX_TOTAL_STRING_BUDGET = 120000
const _MAX_TOTAL_ENUM_VALUES = 1000
const _MAX_ENUM_VALUES_FOR_STRING_BUDGET = 250
const _MAX_ENUM_STRING_BUDGET = 15000

static func _is_schema_like(v) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return false
	for k in _SCHEMA_KEYS:
		if v.has(k):
			return true
	return false

static func sanitize_schema(node, is_root = false):
	return _sanitize_schema(node, is_root)

static func sanitize_envelope_or_schema(data):
	var report = sanitize_envelope_or_schema_with_report(data)
	return report.get("result", {})

static func sanitize_envelope_or_schema_with_report(data) -> Dictionary:
	var result = _sanitize_envelope_or_schema_impl(data)
	var errors = []
	if result is Dictionary:
		if result.has("schema"):
			_validate_sanitized_schema(result["schema"], "/schema", errors)
		if result.has("parameters"):
			_validate_sanitized_schema(result["parameters"], "/parameters", errors)
	if errors.is_empty() and not (result is Dictionary and (result.has("schema") or result.has("parameters"))):
		errors.append(_error("/", "missing_schema", "Missing schema or parameters object"))
	return {
		"ok": errors.is_empty(),
		"result": result,
		"errors": errors
	}

static func _sanitize_schema(node, is_root = false):
	if typeof(node) == TYPE_ARRAY:
		var out = []
		for item in node:
			if typeof(item) in [TYPE_DICTIONARY, TYPE_ARRAY] and _is_schema_like(item):
				out.append(_sanitize_schema(item, false))
			else:
				out.append(item)
		return out
	elif typeof(node) != TYPE_DICTIONARY:
		return node

	if not _is_schema_like(node):
		var out_env = node.duplicate(true)
		if out_env.has("schema"):
			out_env["schema"] = _sanitize_schema(out_env["schema"], true)
		if out_env.has("parameters"):
			out_env["parameters"] = _sanitize_schema(out_env["parameters"], true)
		if out_env.has("components"):
			out_env["components"] = _sanitize_schema(out_env["components"], false)
		return out_env

	var out = {}

	if node.has("type"):
		var t = node["type"]
		if typeof(t) == TYPE_STRING:
			if t in _ALLOWED_TYPES:
				out["type"] = t
		elif typeof(t) == TYPE_ARRAY:
			var filtered = []
			for tv in t:
				if typeof(tv) == TYPE_STRING and tv in _ALLOWED_TYPES and tv not in filtered:
					filtered.append(tv)
			if filtered.size() == 1:
				out["type"] = filtered[0]
			elif filtered.size() > 1:
				out["type"] = filtered

	if node.has("description") and typeof(node["description"]) == TYPE_STRING:
		out["description"] = node["description"]

	if node.has("enum") and typeof(node["enum"]) == TYPE_ARRAY:
		out["enum"] = node["enum"].duplicate()

	if node.has("const"):
		out["const"] = node["const"]

	if node.has("pattern") and typeof(node["pattern"]) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT]:
		out["pattern"] = str(node["pattern"])
	if node.has("format") and typeof(node["format"]) == TYPE_STRING and node["format"] in _ALLOWED_STRING_FORMATS:
		out["format"] = node["format"]

	for nk in ["multipleOf","maximum","exclusiveMaximum","minimum","exclusiveMinimum"]:
		if node.has(nk) and typeof(node[nk]) in [TYPE_INT, TYPE_FLOAT]:
			out[nk] = node[nk]

	if node.has("minItems") and typeof(node["minItems"]) == TYPE_INT and node["minItems"] >= 0:
		out["minItems"] = node["minItems"]
	if node.has("maxItems") and typeof(node["maxItems"]) == TYPE_INT and node["maxItems"] >= 0:
		out["maxItems"] = node["maxItems"]

	if node.has("properties") and typeof(node["properties"]) == TYPE_DICTIONARY:
		var props_out = {}
		for prop_name in node["properties"].keys():
			props_out[prop_name] = _sanitize_schema(node["properties"][prop_name], false)
		out["properties"] = props_out

	if node.has("items") and typeof(node["items"]) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		out["items"] = _sanitize_schema(node["items"], false)

	if node.has("anyOf") and typeof(node["anyOf"]) == TYPE_ARRAY:
		var san = []
		for sub in node["anyOf"]:
			san.append(_sanitize_schema(sub, false))
		out["anyOf"] = san

	if node.has("$ref") and typeof(node["$ref"]) == TYPE_STRING:
		out["$ref"] = node["$ref"]

	var defs = {}
	if node.has("$defs") and typeof(node["$defs"]) == TYPE_DICTIONARY:
		for k in node["$defs"].keys():
			defs[k] = _sanitize_schema(node["$defs"][k], false)
	if node.has("definitions") and typeof(node["definitions"]) == TYPE_DICTIONARY:
		for k in node["definitions"].keys():
			defs[k] = _sanitize_schema(node["definitions"][k], false)
	if defs.size() > 0:
		out["$defs"] = defs

	var is_object = false
	if out.has("type"):
		if typeof(out["type"]) == TYPE_STRING and out["type"] == "object":
			is_object = true
		elif typeof(out["type"]) == TYPE_ARRAY and out["type"].has("object"):
			is_object = true
	if out.has("properties"):
		is_object = true

	if is_object:
		out["additionalProperties"] = false
		if out.has("properties") and typeof(out["properties"]) == TYPE_DICTIONARY:
			var req = []
			for key in out["properties"].keys():
				req.append(key)
			out["required"] = req
		if out.has("properties") and (not out.has("type") or (typeof(out["type"]) == TYPE_ARRAY and not out["type"].has("object"))):
			out["type"] = "object"
	else:
		out.erase("additionalProperties")
		if not out.has("properties"):
			out.erase("required")

	if is_root:
		var root_is_object = is_object
		var root_uses_anyof = out.has("anyOf")
		if not root_is_object or root_uses_anyof:
			return {
				"type": "object",
				"properties": {"value": out},
				"required": ["value"],
				"additionalProperties": false
			}

	return out

static func _sanitize_envelope_or_schema_impl(data):
	if typeof(data) == TYPE_DICTIONARY and not _is_schema_like(data):
		var out = data.duplicate(true)
		if out.has("schema"):
			var schema = out["schema"]
			if schema is Dictionary and schema.has("title") and schema["title"] is String:
				out["name"] = schema["title"]
			elif not out.has("name"):
				out["name"] = ""
			out["schema"] = _sanitize_schema(schema, true)
		if out.has("parameters"):
			var params = out["parameters"]
			if params is Dictionary and params.has("title") and params["title"] is String:
				out["name"] = params["title"]
			elif not out.has("name"):
				out["name"] = ""
			out["parameters"] = _sanitize_schema(params, true)
		if not out.has("name"):
			out["name"] = ""
		return out
	var name = ""
	if data is Dictionary and data.has("title") and data["title"] is String:
		name = data["title"]
	var sanitized = _sanitize_schema(data, true)
	return {"name": name, "schema": sanitized}

static func _validate_sanitized_schema(schema, base_path: String, errors: Array) -> void:
	if typeof(schema) != TYPE_DICTIONARY:
		errors.append(_error(base_path, "schema_type", "Schema must be a JSON object"))
		return
	var state = {
		"property_count": 0,
		"enum_count": 0,
		"string_budget": 0
	}
	_collect_limits(schema, base_path, 1, errors, state)
	var property_count = int(state.get("property_count", 0))
	if property_count > _MAX_TOTAL_PROPERTIES:
		errors.append(_error(base_path, "too_many_properties", "Schema has %d properties, max is %d" % [property_count, _MAX_TOTAL_PROPERTIES]))
	var enum_count = int(state.get("enum_count", 0))
	if enum_count > _MAX_TOTAL_ENUM_VALUES:
		errors.append(_error(base_path, "too_many_enum_values", "Schema has %d enum values, max is %d" % [enum_count, _MAX_TOTAL_ENUM_VALUES]))
	var string_budget = int(state.get("string_budget", 0))
	if string_budget > _MAX_TOTAL_STRING_BUDGET:
		errors.append(_error(base_path, "string_budget_exceeded", "Schema string budget is %d, max is %d" % [string_budget, _MAX_TOTAL_STRING_BUDGET]))

static func _collect_limits(node, path: String, depth: int, errors: Array, state: Dictionary) -> void:
	if typeof(node) != TYPE_DICTIONARY:
		return

	if depth > _MAX_NESTING_DEPTH:
		errors.append(_error(path, "nesting_depth_exceeded", "Schema nesting depth exceeds %d" % _MAX_NESTING_DEPTH))
		return

	if node.has("$ref") and typeof(node["$ref"]) == TYPE_STRING:
		if not str(node["$ref"]).begins_with("#"):
			errors.append(_error(_child_path(path, "$ref"), "external_ref_not_supported", "Only local $ref values starting with # are supported"))

	if node.has("properties") and typeof(node["properties"]) == TYPE_DICTIONARY:
		var props = node["properties"]
		state["property_count"] = int(state.get("property_count", 0)) + props.size()
		for key in props.keys():
			state["string_budget"] = int(state.get("string_budget", 0)) + str(key).length()
			_collect_limits(props[key], _child_path(_child_path(path, "properties"), str(key)), depth + 1, errors, state)

	if node.has("$defs") and typeof(node["$defs"]) == TYPE_DICTIONARY:
		var defs = node["$defs"]
		for key in defs.keys():
			state["string_budget"] = int(state.get("string_budget", 0)) + str(key).length()
			_collect_limits(defs[key], _child_path(_child_path(path, "$defs"), str(key)), depth + 1, errors, state)

	if node.has("enum") and typeof(node["enum"]) == TYPE_ARRAY:
		var enum_values = node["enum"]
		state["enum_count"] = int(state.get("enum_count", 0)) + enum_values.size()
		var all_strings = enum_values.size() > 0
		var enum_string_len = 0
		for value in enum_values:
			if typeof(value) == TYPE_STRING:
				var string_len = str(value).length()
				enum_string_len += string_len
				state["string_budget"] = int(state.get("string_budget", 0)) + string_len
			else:
				all_strings = false
		if all_strings and enum_values.size() > _MAX_ENUM_VALUES_FOR_STRING_BUDGET and enum_string_len > _MAX_ENUM_STRING_BUDGET:
			errors.append(_error(_child_path(path, "enum"), "enum_string_budget_exceeded", "Enum string budget is %d for %d values, max is %d when enum has more than %d values" % [enum_string_len, enum_values.size(), _MAX_ENUM_STRING_BUDGET, _MAX_ENUM_VALUES_FOR_STRING_BUDGET]))

	if node.has("const") and typeof(node["const"]) == TYPE_STRING:
		state["string_budget"] = int(state.get("string_budget", 0)) + str(node["const"]).length()

	if node.has("items"):
		if typeof(node["items"]) == TYPE_DICTIONARY:
			_collect_limits(node["items"], _child_path(path, "items"), depth + 1, errors, state)
		elif typeof(node["items"]) == TYPE_ARRAY:
			for index in range(node["items"].size()):
				var tuple_node = node["items"][index]
				if typeof(tuple_node) == TYPE_DICTIONARY:
					_collect_limits(tuple_node, _child_path(_child_path(path, "items"), str(index)), depth + 1, errors, state)

	if node.has("anyOf") and typeof(node["anyOf"]) == TYPE_ARRAY:
		for index in range(node["anyOf"].size()):
			var branch = node["anyOf"][index]
			if typeof(branch) == TYPE_DICTIONARY:
				_collect_limits(branch, _child_path(_child_path(path, "anyOf"), str(index)), depth + 1, errors, state)

static func _error(path: String, code: String, message: String) -> Dictionary:
	return {
		"path": path if path != "" else "/",
		"code": code,
		"message": message
	}

static func _child_path(path: String, key: String) -> String:
	var escaped = _json_pointer_escape(key)
	if path == "" or path == "/":
		return "/" + escaped
	return path + "/" + escaped

static func _json_pointer_escape(key: String) -> String:
	return key.replace("~", "~0").replace("/", "~1")
