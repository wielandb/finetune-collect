extends RefCounted

class_name JsonSchemaValidator

static func validate_schema(schema: Dictionary) -> Dictionary:
	var errors: Array = []
	_validate_schema_node(schema, "", errors)
	return {"ok": errors.is_empty(), "phase": "schema", "errors": errors}

static func validate(data, schema: Dictionary) -> Dictionary:
	var errors: Array = []
	_validate(data, schema, "", errors)
	return {"ok": errors.is_empty(), "phase": "instance", "errors": errors}

static func _validate_schema_node(schema, path: String, errors: Array) -> void:
	if typeof(schema) != TYPE_DICTIONARY:
		errors.append({"path": path, "message": "schema must be object"})
		return
	var t = schema.get("type", null)
	if t != null and typeof(t) != TYPE_STRING:
		errors.append({"path": path + "/type", "message": "type must be string"})
	var props = schema.get("properties", null)
	if props != null and typeof(props) == TYPE_DICTIONARY:
		for key in props.keys():
			_validate_schema_node(props[key], path + "/properties/" + str(key), errors)
	var items = schema.get("items", null)
	if items != null:
		_validate_schema_node(items, path + "/items", errors)

static func _validate(data, schema, path: String, errors: Array) -> void:
	var t = schema.get("type", null)
	match t:
		"object":
			if typeof(data) != TYPE_DICTIONARY:
				errors.append({"path": path, "message": "expected object"})
				return
			var props: Dictionary = schema.get("properties", {})
			for key in data.keys():
				if props.has(key):
					_validate(data[key], props[key], path + "/" + str(key), errors)
				elif schema.get("additionalProperties", true) == false:
					errors.append({"path": path + "/" + str(key), "message": "additional property"})
			var req = schema.get("required", [])
			for r in req:
				if not data.has(r):
					errors.append({"path": path + "/" + str(r), "message": "missing property"})
		"string":
			if typeof(data) != TYPE_STRING:
				errors.append({"path": path, "message": "expected string"})
		"integer":
			if typeof(data) == TYPE_INT:
				pass
			elif typeof(data) == TYPE_FLOAT and int(data) == data:
				pass
			else:
				errors.append({"path": path, "message": "expected integer"})
		"number":
			if typeof(data) != TYPE_INT and typeof(data) != TYPE_FLOAT:
				errors.append({"path": path, "message": "expected number"})
		"array":
			if typeof(data) != TYPE_ARRAY:
				errors.append({"path": path, "message": "expected array"})
				return
			var items_schema = schema.get("items", null)
			if items_schema != null:
				for i in data.size():
					_validate(data[i], items_schema, path + "/" + str(i), errors)
		"boolean":
			if typeof(data) != TYPE_BOOL:
				errors.append({"path": path, "message": "expected boolean"})
		"null":
			if data != null:
				errors.append({"path": path, "message": "expected null"})
		_:
			pass
