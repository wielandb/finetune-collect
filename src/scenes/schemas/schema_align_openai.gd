extends RefCounted

# Utility to sanitize JSON Schemas for OpenAI Structured Outputs compliance.
# Inspired by scripts/schema_align_openai.php

static func _is_schema_like(v) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return false
	var keys = [
		"type","properties","required","items","enum","anyOf","$ref","$defs","definitions",
		"additionalProperties","description","pattern","format",
		"multipleOf","maximum","exclusiveMaximum","minimum","exclusiveMinimum",
		"minItems","maxItems","const"
	]
	for k in keys:
		if v.has(k):
			return true
	return false

static func sanitize_schema(node, is_root := false):
	if typeof(node) == TYPE_ARRAY:
		var out = []
		for item in node:
			if typeof(item) in [TYPE_DICTIONARY, TYPE_ARRAY] and _is_schema_like(item):
				out.append(sanitize_schema(item, false))
			else:
				out.append(item)
		return out
	elif typeof(node) != TYPE_DICTIONARY:
		return node

	if not _is_schema_like(node):
		var out_env = node.duplicate(true)
		if out_env.has("schema"):
			out_env["schema"] = sanitize_schema(out_env["schema"], true)
		if out_env.has("parameters"):
			out_env["parameters"] = sanitize_schema(out_env["parameters"], true)
		if out_env.has("components"):
			out_env["components"] = sanitize_schema(out_env["components"], false)
		return out_env

	var allowed_string_formats = ["date-time","time","date","duration","email","hostname","ipv4","ipv6","uuid"]
	var allowed_types = ["string","number","boolean","integer","object","array","null"]
	var out = {}

	if node.has("type"):
		var t = node["type"]
		if typeof(t) == TYPE_STRING:
			if t in allowed_types:
				out["type"] = t
		elif typeof(t) == TYPE_ARRAY:
			var filtered = []
			for tv in t:
				if typeof(tv) == TYPE_STRING and tv in allowed_types and tv not in filtered:
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
	if node.has("format") and typeof(node["format"]) == TYPE_STRING and node["format"] in allowed_string_formats:
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
			props_out[prop_name] = sanitize_schema(node["properties"][prop_name], false)
		out["properties"] = props_out

	if node.has("items") and typeof(node["items"]) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		out["items"] = sanitize_schema(node["items"], false)

	if node.has("anyOf") and typeof(node["anyOf"]) == TYPE_ARRAY:
		var san = []
		for sub in node["anyOf"]:
			san.append(sanitize_schema(sub, false))
		out["anyOf"] = san

	if node.has("$ref") and typeof(node["$ref"]) == TYPE_STRING:
		out["$ref"] = node["$ref"]

	var defs = {}
	if node.has("$defs") and typeof(node["$defs"]) == TYPE_DICTIONARY:
		for k in node["$defs"].keys():
			defs[k] = sanitize_schema(node["$defs"][k], false)
	if node.has("definitions") and typeof(node["definitions"]) == TYPE_DICTIONARY:
		for k in node["definitions"].keys():
			defs[k] = sanitize_schema(node["definitions"][k], false)
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

static func sanitize_envelope_or_schema(data):
	if typeof(data) == TYPE_DICTIONARY and not _is_schema_like(data):
		var out = data.duplicate(true)
		if out.has("schema"):
			out["schema"] = sanitize_schema(out["schema"], true)
		if out.has("parameters"):
			out["parameters"] = sanitize_schema(out["parameters"], true)
		return out
	return sanitize_schema(data, true)
