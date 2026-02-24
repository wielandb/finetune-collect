extends RefCounted

class_name JsonSchemaValidator

const _ALLOWED_TYPES = ["object", "array", "string", "number", "integer", "boolean", "null"]
const _MAX_DEPTH = 128

static func validate_schema(schema: Dictionary) -> Dictionary:
	var errors = []
	_validate_schema_node(schema, "", errors, schema, 0)
	return {"ok": errors.is_empty(), "phase": "schema", "errors": errors}

static func validate(data, schema: Dictionary) -> Dictionary:
	var errors = []
	_validate(data, schema, "", errors, schema, 0)
	return {"ok": errors.is_empty(), "phase": "instance", "errors": errors}

static func _validate_schema_node(schema, path: String, errors: Array, root: Dictionary, depth: int) -> void:
	if depth > _MAX_DEPTH:
		errors.append({"path": _path_or_root(path), "message": "schema depth limit exceeded"})
		return
	if not (schema is Dictionary):
		errors.append({"path": _path_or_root(path), "message": "schema must be object"})
		return

	if schema.has("$ref"):
		if not (schema["$ref"] is String):
			errors.append({"path": _child_path(path, "$ref"), "message": "$ref must be string"})
		elif not schema["$ref"].begins_with("#/"):
			errors.append({"path": _child_path(path, "$ref"), "message": "only internal $ref is supported"})
		elif _json_pointer_get(root, schema["$ref"]) == null:
			errors.append({"path": _child_path(path, "$ref"), "message": "unresolvable $ref"})

	if schema.has("type"):
		var t = schema["type"]
		if t is String:
			if not _ALLOWED_TYPES.has(t):
				errors.append({"path": _child_path(path, "type"), "message": "unknown type"})
		elif t is Array:
			if t.is_empty():
				errors.append({"path": _child_path(path, "type"), "message": "type array must not be empty"})
			for i in range(t.size()):
				var tv = t[i]
				if not (tv is String) or not _ALLOWED_TYPES.has(tv):
					errors.append({"path": _child_path(path, "type/" + str(i)), "message": "invalid type entry"})
		else:
			errors.append({"path": _child_path(path, "type"), "message": "type must be string or array"})

	if schema.has("required") and not (schema["required"] is Array):
		errors.append({"path": _child_path(path, "required"), "message": "required must be array"})
	elif schema.has("required"):
		for i in range(schema["required"].size()):
			if not (schema["required"][i] is String):
				errors.append({"path": _child_path(path, "required/" + str(i)), "message": "required entry must be string"})

	if schema.has("properties"):
		var props = schema["properties"]
		if not (props is Dictionary):
			errors.append({"path": _child_path(path, "properties"), "message": "properties must be object"})
		else:
			for key in props.keys():
				_validate_schema_node(props[key], _child_path(path, "properties/" + str(key)), errors, root, depth + 1)

	if schema.has("items"):
		var items = schema["items"]
		if items is Dictionary:
			_validate_schema_node(items, _child_path(path, "items"), errors, root, depth + 1)
		elif items is Array:
			for i in range(items.size()):
				_validate_schema_node(items[i], _child_path(path, "items/" + str(i)), errors, root, depth + 1)
		else:
			errors.append({"path": _child_path(path, "items"), "message": "items must be object or array"})

	for union_key in ["oneOf", "anyOf", "allOf"]:
		if schema.has(union_key):
			var branches = schema[union_key]
			if not (branches is Array):
				errors.append({"path": _child_path(path, union_key), "message": union_key + " must be array"})
			else:
				for i in range(branches.size()):
					_validate_schema_node(branches[i], _child_path(path, union_key + "/" + str(i)), errors, root, depth + 1)

	if schema.has("additionalProperties"):
		var ap = schema["additionalProperties"]
		if not (ap is bool) and not (ap is Dictionary):
			errors.append({"path": _child_path(path, "additionalProperties"), "message": "additionalProperties must be bool or object"})

	for defs_key in ["$defs", "definitions"]:
		if schema.has(defs_key):
			var defs = schema[defs_key]
			if not (defs is Dictionary):
				errors.append({"path": _child_path(path, defs_key), "message": defs_key + " must be object"})
			else:
				for def_name in defs.keys():
					_validate_schema_node(defs[def_name], _child_path(path, defs_key + "/" + str(def_name)), errors, root, depth + 1)

	if schema.has("enum") and not (schema["enum"] is Array):
		errors.append({"path": _child_path(path, "enum"), "message": "enum must be array"})
	if schema.has("minLength") and not _is_integer_number(schema["minLength"]):
		errors.append({"path": _child_path(path, "minLength"), "message": "minLength must be integer"})
	if schema.has("maxLength") and not _is_integer_number(schema["maxLength"]):
		errors.append({"path": _child_path(path, "maxLength"), "message": "maxLength must be integer"})
	if schema.has("minimum") and not _is_number(schema["minimum"]):
		errors.append({"path": _child_path(path, "minimum"), "message": "minimum must be number"})
	if schema.has("maximum") and not _is_number(schema["maximum"]):
		errors.append({"path": _child_path(path, "maximum"), "message": "maximum must be number"})
	if schema.has("exclusiveMinimum") and not _is_number(schema["exclusiveMinimum"]):
		errors.append({"path": _child_path(path, "exclusiveMinimum"), "message": "exclusiveMinimum must be number"})
	if schema.has("exclusiveMaximum") and not _is_number(schema["exclusiveMaximum"]):
		errors.append({"path": _child_path(path, "exclusiveMaximum"), "message": "exclusiveMaximum must be number"})
	if schema.has("multipleOf") and not _is_number(schema["multipleOf"]):
		errors.append({"path": _child_path(path, "multipleOf"), "message": "multipleOf must be number"})
	if schema.has("minItems") and not _is_integer_number(schema["minItems"]):
		errors.append({"path": _child_path(path, "minItems"), "message": "minItems must be integer"})
	if schema.has("maxItems") and not _is_integer_number(schema["maxItems"]):
		errors.append({"path": _child_path(path, "maxItems"), "message": "maxItems must be integer"})

static func _validate(data, schema, path: String, errors: Array, root: Dictionary, depth: int) -> void:
	if depth > _MAX_DEPTH:
		errors.append({"path": _path_or_root(path), "message": "validation depth limit exceeded"})
		return
	if not (schema is Dictionary):
		errors.append({"path": _path_or_root(path), "message": "invalid schema node"})
		return
	var resolved_schema = _resolve_schema(schema, root, errors, path)
	if resolved_schema == null:
		return

	if resolved_schema.has("allOf") and resolved_schema["allOf"] is Array:
		for branch in resolved_schema["allOf"]:
			_validate(data, branch, path, errors, root, depth + 1)

	if resolved_schema.has("anyOf") and resolved_schema["anyOf"] is Array:
		var any_ok = false
		for branch in resolved_schema["anyOf"]:
			var branch_res = _validate_collect(data, branch, root, depth + 1)
			if branch_res["ok"]:
				any_ok = true
				break
		if not any_ok:
			errors.append({"path": _path_or_root(path), "message": "no anyOf branch matched"})

	if resolved_schema.has("oneOf") and resolved_schema["oneOf"] is Array:
		var matches = 0
		for branch in resolved_schema["oneOf"]:
			var branch_res = _validate_collect(data, branch, root, depth + 1)
			if branch_res["ok"]:
				matches += 1
		if matches != 1:
			errors.append({"path": _path_or_root(path), "message": "exactly one oneOf branch must match"})

	if not _matches_type_any(data, resolved_schema):
		errors.append({"path": _path_or_root(path), "message": "type mismatch"})
		return

	if resolved_schema.has("const"):
		if JSON.stringify(data) != JSON.stringify(resolved_schema["const"]):
			errors.append({"path": _path_or_root(path), "message": "value does not match const"})

	if resolved_schema.has("enum") and resolved_schema["enum"] is Array:
		var enum_ok = false
		for option in resolved_schema["enum"]:
			if JSON.stringify(option) == JSON.stringify(data):
				enum_ok = true
				break
		if not enum_ok:
			errors.append({"path": _path_or_root(path), "message": "value not in enum"})

	if _should_treat_as_object(resolved_schema):
		_validate_object(data, resolved_schema, path, errors, root, depth)
	if _should_treat_as_array(resolved_schema):
		_validate_array(data, resolved_schema, path, errors, root, depth)
	_validate_string_constraints(data, resolved_schema, path, errors)
	_validate_number_constraints(data, resolved_schema, path, errors)

static func _validate_object(data, schema: Dictionary, path: String, errors: Array, root: Dictionary, depth: int) -> void:
	if not (data is Dictionary):
		errors.append({"path": _path_or_root(path), "message": "expected object"})
		return
	var props = schema.get("properties", {})
	if not (props is Dictionary):
		props = {}
	for key in data.keys():
		if props.has(key):
			_validate(data[key], props[key], _child_path(path, str(key)), errors, root, depth + 1)
		elif schema.get("additionalProperties", true) == false:
			errors.append({"path": _child_path(path, str(key)), "message": "additional property"})
		elif schema.get("additionalProperties", true) is Dictionary:
			_validate(data[key], schema["additionalProperties"], _child_path(path, str(key)), errors, root, depth + 1)
	var req = schema.get("required", [])
	if req is Array:
		for r in req:
			if not data.has(r):
				errors.append({"path": _child_path(path, str(r)), "message": "missing property"})

static func _validate_array(data, schema: Dictionary, path: String, errors: Array, root: Dictionary, depth: int) -> void:
	if not (data is Array):
		errors.append({"path": _path_or_root(path), "message": "expected array"})
		return
	var min_items = int(schema.get("minItems", -1))
	var max_items = int(schema.get("maxItems", -1))
	if min_items >= 0 and data.size() < min_items:
		errors.append({"path": _path_or_root(path), "message": "too few items"})
	if max_items >= 0 and data.size() > max_items:
		errors.append({"path": _path_or_root(path), "message": "too many items"})
	if bool(schema.get("uniqueItems", false)):
		var seen = {}
		for i in range(data.size()):
			var key = JSON.stringify(data[i])
			if seen.has(key):
				errors.append({"path": _child_path(path, str(i)), "message": "duplicate item"})
				break
			seen[key] = true
	if schema.has("items"):
		if schema["items"] is Dictionary:
			for i in range(data.size()):
				_validate(data[i], schema["items"], _child_path(path, str(i)), errors, root, depth + 1)
		elif schema["items"] is Array:
			for i in range(data.size()):
				if i < schema["items"].size():
					_validate(data[i], schema["items"][i], _child_path(path, str(i)), errors, root, depth + 1)

static func _validate_string_constraints(data, schema: Dictionary, path: String, errors: Array) -> void:
	var has_string_constraints = schema.has("minLength") or schema.has("maxLength") or schema.has("pattern") or schema.has("format")
	if not has_string_constraints:
		return
	if not (data is String):
		return
	if schema.has("minLength") and data.length() < int(schema["minLength"]):
		errors.append({"path": _path_or_root(path), "message": "string shorter than minLength"})
	if schema.has("maxLength") and data.length() > int(schema["maxLength"]):
		errors.append({"path": _path_or_root(path), "message": "string longer than maxLength"})
	if schema.has("pattern") and schema["pattern"] is String:
		var regex = RegEx.new()
		if regex.compile(schema["pattern"]) != OK:
			errors.append({"path": _path_or_root(path), "message": "invalid pattern"})
		elif regex.search(data) == null:
			errors.append({"path": _path_or_root(path), "message": "string does not match pattern"})
	if schema.has("format") and schema["format"] is String:
		if not _matches_format(data, schema["format"]):
			errors.append({"path": _path_or_root(path), "message": "string does not match format " + str(schema["format"])})

static func _validate_number_constraints(data, schema: Dictionary, path: String, errors: Array) -> void:
	var has_number_constraints = schema.has("minimum") or schema.has("maximum") or schema.has("exclusiveMinimum") or schema.has("exclusiveMaximum") or schema.has("multipleOf")
	if not has_number_constraints:
		return
	if not _is_number(data):
		return
	var number = float(data)
	if schema.has("minimum") and number < float(schema["minimum"]):
		errors.append({"path": _path_or_root(path), "message": "number below minimum"})
	if schema.has("maximum") and number > float(schema["maximum"]):
		errors.append({"path": _path_or_root(path), "message": "number above maximum"})
	if schema.has("exclusiveMinimum") and number <= float(schema["exclusiveMinimum"]):
		errors.append({"path": _path_or_root(path), "message": "number below or equal exclusiveMinimum"})
	if schema.has("exclusiveMaximum") and number >= float(schema["exclusiveMaximum"]):
		errors.append({"path": _path_or_root(path), "message": "number above or equal exclusiveMaximum"})
	if schema.has("multipleOf"):
		var divisor = float(schema["multipleOf"])
		if divisor != 0.0:
			var remainder = fmod(number, divisor)
			if abs(remainder) > 0.000001 and abs(remainder - divisor) > 0.000001:
				errors.append({"path": _path_or_root(path), "message": "number not multipleOf"})

static func _resolve_schema(schema: Dictionary, root: Dictionary, errors: Array, path: String):
	if not schema.has("$ref"):
		return schema
	var ref = schema.get("$ref", "")
	if not (ref is String):
		errors.append({"path": _path_or_root(path), "message": "$ref must be string"})
		return null
	if not ref.begins_with("#/"):
		errors.append({"path": _path_or_root(path), "message": "external $ref not supported"})
		return null
	var target = _json_pointer_get(root, ref)
	if not (target is Dictionary):
		errors.append({"path": _path_or_root(path), "message": "unresolvable $ref"})
		return null
	var merged = target.duplicate(true)
	for key in schema.keys():
		if key == "$ref":
			continue
		merged[key] = schema[key]
	return merged

static func _json_pointer_get(root, pointer: String):
	if pointer == "#" or pointer == "#/":
		return root
	if not pointer.begins_with("#/"):
		return null
	var current = root
	var parts = pointer.substr(2).split("/")
	for raw_part in parts:
		var part = raw_part.replace("~1", "/").replace("~0", "~")
		if current is Dictionary:
			if not current.has(part):
				return null
			current = current[part]
		elif current is Array:
			if not part.is_valid_int():
				return null
			var index = int(part)
			if index < 0 or index >= current.size():
				return null
			current = current[index]
		else:
			return null
	return current

static func _validate_collect(data, schema: Dictionary, root: Dictionary, depth: int) -> Dictionary:
	var local_errors = []
	_validate(data, schema, "", local_errors, root, depth)
	return {"ok": local_errors.is_empty(), "errors": local_errors}

static func _matches_type_any(data, schema: Dictionary) -> bool:
	var t = schema.get("type", null)
	if t == null:
		return true
	if t is String:
		return _matches_single_type(data, t)
	if t is Array:
		for entry in t:
			if entry is String and _matches_single_type(data, entry):
				return true
		return false
	return false

static func _matches_single_type(data, expected_type: String) -> bool:
	match expected_type:
		"object":
			return data is Dictionary
		"array":
			return data is Array
		"string":
			return data is String
		"number":
			return _is_number(data)
		"integer":
			if data is int:
				return true
			if data is float:
				return int(data) == data
			return false
		"boolean":
			return data is bool
		"null":
			return data == null
		_:
			return true

static func _should_treat_as_object(schema: Dictionary) -> bool:
	var t = schema.get("type", null)
	if t is String and t == "object":
		return true
	if t is Array and t.has("object"):
		return true
	if schema.has("properties") or schema.has("required") or schema.has("additionalProperties"):
		return true
	return false

static func _should_treat_as_array(schema: Dictionary) -> bool:
	var t = schema.get("type", null)
	if t is String and t == "array":
		return true
	if t is Array and t.has("array"):
		return true
	if schema.has("items") or schema.has("minItems") or schema.has("maxItems"):
		return true
	return false

static func _matches_format(value: String, fmt: String) -> bool:
	match fmt:
		"date":
			var date_regex = RegEx.new()
			date_regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
			return date_regex.search(value) != null
		"time":
			var time_regex = RegEx.new()
			time_regex.compile("^\\d{2}:\\d{2}(:\\d{2})?$")
			return time_regex.search(value) != null
		"date-time":
			var dt_regex = RegEx.new()
			dt_regex.compile("^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}(:\\d{2})?(Z|[+-]\\d{2}:\\d{2})?$")
			return dt_regex.search(value) != null
		"email":
			var email_regex = RegEx.new()
			email_regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
			return email_regex.search(value) != null
		"ipv4":
			var ipv4_regex = RegEx.new()
			ipv4_regex.compile("^((25[0-5]|2[0-4]\\d|1?\\d?\\d)\\.){3}(25[0-5]|2[0-4]\\d|1?\\d?\\d)$")
			return ipv4_regex.search(value) != null
		"ipv6":
			var ipv6_regex = RegEx.new()
			ipv6_regex.compile("^[0-9a-fA-F:]+$")
			return ipv6_regex.search(value) != null and value.find(":") != -1
		"uuid":
			var uuid_regex = RegEx.new()
			uuid_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
			return uuid_regex.search(value) != null
		"hostname":
			var host_regex = RegEx.new()
			host_regex.compile("^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
			return host_regex.search(value) != null
		_:
			return true

static func _is_number(value) -> bool:
	return value is int or value is float

static func _is_integer_number(value) -> bool:
	if value is int:
		return true
	if value is float:
		if is_nan(value) or is_inf(value):
			return false
		return int(value) == value
	return false

static func _child_path(path: String, segment: String) -> String:
	if path == "":
		return "/" + segment
	return path + "/" + segment

static func _path_or_root(path: String) -> String:
	if path == "":
		return "/"
	return path
