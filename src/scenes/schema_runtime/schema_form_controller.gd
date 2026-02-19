extends RefCounted

class_name SchemaFormController

signal value_changed(json_text: String)
signal validation_updated(errors: Array)
signal fallback_error_changed(has_errors: bool)
signal schema_loaded(has_fallback: bool)

var _compiler = SchemaFormCompiler.new()
var _renderer = SchemaFormRenderer.new()

var _schema = {}
var _descriptor = {}
var _value = {}
var _errors = []
var _fallback_errors = {}
var _has_partial_fallback = false
var _form_root: Control = null
var _union_selection = {}

func bind_form_root(root: Control) -> void:
	_form_root = root

func load_schema(schema: Dictionary) -> void:
	_schema = schema.duplicate(true)
	var resolved = SchemaRefResolver.resolve_schema(_schema)
	var compiled = _compiler.compile_schema(resolved.get("schema", {}))
	_descriptor = compiled.get("descriptor", _create_empty_fallback("No schema descriptor"))
	_has_partial_fallback = bool(compiled.get("has_partial_fallback", false))
	if bool(resolved.get("has_external_ref", false)) or bool(resolved.get("has_ref_cycle", false)):
		_has_partial_fallback = true
	_value = _coerce_value_for_descriptor(_value, _descriptor)
	_rebuild_form()
	_validate_current()
	schema_loaded.emit(_has_partial_fallback)

func set_value_from_json(json_text: String) -> Dictionary:
	var json = JSON.new()
	if json_text.strip_edges() == "":
		_value = create_default_value(_descriptor)
		_rebuild_form()
		_emit_after_value_update()
		return {"ok": false, "initialized": true, "message": "Empty JSON replaced with defaults"}
	var err = json.parse(json_text)
	if err != OK:
		_value = create_default_value(_descriptor)
		_rebuild_form()
		_emit_after_value_update()
		return {"ok": false, "initialized": true, "message": "Invalid JSON replaced with defaults"}
	_value = _coerce_value_for_descriptor(json.data, _descriptor)
	_rebuild_form()
	_emit_after_value_update()
	return {"ok": true, "initialized": false, "message": ""}

func get_value_as_json(pretty: bool = true) -> String:
	if pretty:
		return JSON.stringify(_value, "\t")
	return JSON.stringify(_value)

func get_validation_errors() -> Array:
	return _errors.duplicate(true)

func get_errors() -> Array:
	return get_validation_errors()

func has_partial_fallback() -> bool:
	return _has_partial_fallback

func get_current_value():
	return _value

func get_value_at_path(path: Array):
	var current = _value
	for segment in path:
		if segment is String:
			if not (current is Dictionary) or not current.has(segment):
				return null
			current = current[segment]
		elif segment is int:
			if not (current is Array):
				return null
			var index = int(segment)
			if index < 0 or index >= current.size():
				return null
			current = current[index]
		else:
			return null
	return current

func set_value_at_path(path: Array, value, request_rebuild: bool) -> void:
	_value = _set_in_tree(_value, path, 0, value)
	if request_rebuild:
		_rebuild_form()
	_emit_after_value_update()

func remove_value_at_path(path: Array, request_rebuild: bool) -> void:
	_value = _remove_in_tree(_value, path, 0)
	if request_rebuild:
		_rebuild_form()
	_emit_after_value_update()

func create_default_value(descriptor: Dictionary):
	if descriptor.has("default"):
		return descriptor["default"]
	var kind = str(descriptor.get("kind", "fallback"))
	if descriptor.get("nullable", false) and kind != "null":
		return _create_default_non_null(descriptor)
	return _create_default_non_null(descriptor)

func _create_default_non_null(descriptor: Dictionary):
	var kind = str(descriptor.get("kind", "fallback"))
	match kind:
		"object":
			var out = {}
			var required = descriptor.get("required", [])
			for prop in descriptor.get("properties", []):
				if not (prop is Dictionary):
					continue
				var name = str(prop.get("name", ""))
				if required.has(name):
					out[name] = create_default_value(prop.get("descriptor", {}))
			return out
		"array":
			var arr = []
			var min_items = int(descriptor.get("min_items", 0))
			for i in range(min_items):
				arr.append(create_default_value(descriptor.get("items", {})))
			return arr
		"string":
			return ""
		"number", "integer":
			if descriptor.get("minimum", null) is int or descriptor.get("minimum", null) is float:
				return descriptor["minimum"]
			if descriptor.get("exclusive_minimum", null) is int or descriptor.get("exclusive_minimum", null) is float:
				if kind == "integer":
					return int(descriptor["exclusive_minimum"]) + 1
				return float(descriptor["exclusive_minimum"]) + 0.1
			return 0
		"boolean":
			return false
		"enum":
			var options = descriptor.get("enum_values", [])
			if options.size() > 0:
				return options[0]
			return ""
		"const":
			return descriptor.get("const_value", null)
		"null":
			return null
		"union":
			var branches = descriptor.get("branches", [])
			if branches.size() == 0:
				return {}
			return create_default_value(branches[0])
		"fallback":
			return {}
		_:
			return {}

func _coerce_value_for_descriptor(value, descriptor: Dictionary):
	var kind = str(descriptor.get("kind", "fallback"))
	if value == null:
		if descriptor.get("nullable", false) or kind == "null":
			return null
		return create_default_value(descriptor)
	match kind:
		"object":
			if not (value is Dictionary):
				return create_default_value(descriptor)
			var out_obj = value.duplicate(true)
			var required = descriptor.get("required", [])
			var props_map = {}
			for prop in descriptor.get("properties", []):
				if prop is Dictionary:
					props_map[str(prop.get("name", ""))] = prop.get("descriptor", {})
			for prop_name in props_map.keys():
				if out_obj.has(prop_name):
					out_obj[prop_name] = _coerce_value_for_descriptor(out_obj[prop_name], props_map[prop_name])
				elif required.has(prop_name):
					out_obj[prop_name] = create_default_value(props_map[prop_name])
			if descriptor.get("additional_properties", true) == false:
				var to_erase = []
				for key in out_obj.keys():
					if not props_map.has(key):
						to_erase.append(key)
				for key_to_erase in to_erase:
					out_obj.erase(key_to_erase)
			return out_obj
		"array":
			if not (value is Array):
				return create_default_value(descriptor)
			var out_arr = value.duplicate(true)
			var item_desc = descriptor.get("items", {})
			for i in range(out_arr.size()):
				out_arr[i] = _coerce_value_for_descriptor(out_arr[i], item_desc)
			var min_items = int(descriptor.get("min_items", 0))
			while out_arr.size() < min_items:
				out_arr.append(create_default_value(item_desc))
			var max_items = int(descriptor.get("max_items", -1))
			if max_items >= 0 and out_arr.size() > max_items:
				out_arr.resize(max_items)
			return out_arr
		"string":
			if value is String:
				return value
			return str(value)
		"number":
			if value is int or value is float:
				return float(value)
			return float(create_default_value(descriptor))
		"integer":
			if value is int:
				return value
			if value is float:
				return int(round(value))
			return int(create_default_value(descriptor))
		"boolean":
			return bool(value)
		"enum":
			var options = descriptor.get("enum_values", [])
			for option in options:
				if JSON.stringify(option) == JSON.stringify(value):
					return value
			if options.size() > 0:
				return options[0]
			return null
		"const":
			return descriptor.get("const_value", null)
		"null":
			return null
		"union":
			var branch_index = _find_matching_union_branch(value, descriptor)
			var branches = descriptor.get("branches", [])
			if branch_index < 0 or branch_index >= branches.size():
				branch_index = 0
			_union_selection[_path_key_from_pointer(str(descriptor.get("pointer", "")))] = branch_index
			return _coerce_value_for_descriptor(value, branches[branch_index])
		"fallback":
			return value
		_:
			return value

func _rebuild_form() -> void:
	if _form_root == null:
		return
	for child in _form_root.get_children():
		child.queue_free()
	_renderer.render(_descriptor, _form_root, self, [])

func _emit_after_value_update() -> void:
	_validate_current()
	value_changed.emit(get_value_as_json(true))
	fallback_error_changed.emit(_fallback_errors.size() > 0)

func _validate_current() -> void:
	_errors = []
	_validate_value_against_descriptor(_value, _descriptor, "", _errors)
	for fallback_path in _fallback_errors.keys():
		_errors.append({"path": fallback_path, "message": _fallback_errors[fallback_path]})
	validation_updated.emit(_errors.duplicate(true))

func _validate_value_against_descriptor(value, descriptor: Dictionary, path: String, errors: Array) -> void:
	var kind = str(descriptor.get("kind", "fallback"))
	if value == null:
		if descriptor.get("nullable", false) or kind == "null":
			return
		errors.append({"path": _path_or_root(path), "message": "Value must not be null"})
		return
	match kind:
		"object":
			if not (value is Dictionary):
				errors.append({"path": _path_or_root(path), "message": "Expected object"})
				return
			var required = descriptor.get("required", [])
			for req in required:
				if not value.has(req):
					errors.append({"path": _path_or_root(path + "/" + str(req)), "message": "Missing required property"})
			var prop_map = {}
			for prop in descriptor.get("properties", []):
				if prop is Dictionary:
					prop_map[str(prop.get("name", ""))] = prop.get("descriptor", {})
			for key in value.keys():
				if prop_map.has(key):
					_validate_value_against_descriptor(value[key], prop_map[key], path + "/" + str(key), errors)
				elif descriptor.get("additional_properties", true) == false:
					errors.append({"path": _path_or_root(path + "/" + str(key)), "message": "Additional property not allowed"})
		"array":
			if not (value is Array):
				errors.append({"path": _path_or_root(path), "message": "Expected array"})
				return
			var min_items = int(descriptor.get("min_items", 0))
			var max_items = int(descriptor.get("max_items", -1))
			if value.size() < min_items:
				errors.append({"path": _path_or_root(path), "message": "Too few array items"})
			if max_items >= 0 and value.size() > max_items:
				errors.append({"path": _path_or_root(path), "message": "Too many array items"})
			for i in range(value.size()):
				_validate_value_against_descriptor(value[i], descriptor.get("items", {}), path + "/" + str(i), errors)
		"string":
			if not (value is String):
				errors.append({"path": _path_or_root(path), "message": "Expected string"})
		"number":
			if not (value is int or value is float):
				errors.append({"path": _path_or_root(path), "message": "Expected number"})
		"integer":
			if value is int:
				pass
			elif value is float and int(value) == value:
				pass
			else:
				errors.append({"path": _path_or_root(path), "message": "Expected integer"})
		"boolean":
			if not (value is bool):
				errors.append({"path": _path_or_root(path), "message": "Expected boolean"})
		"enum":
			var ok = false
			for option in descriptor.get("enum_values", []):
				if JSON.stringify(option) == JSON.stringify(value):
					ok = true
					break
			if not ok:
				errors.append({"path": _path_or_root(path), "message": "Value not in enum"})
		"const":
			if JSON.stringify(value) != JSON.stringify(descriptor.get("const_value", null)):
				errors.append({"path": _path_or_root(path), "message": "Value does not match const"})
		"null":
			if value != null:
				errors.append({"path": _path_or_root(path), "message": "Expected null"})
		"union":
			var branch_index = _find_matching_union_branch(value, descriptor)
			if branch_index == -1:
				errors.append({"path": _path_or_root(path), "message": "No union branch matches value"})
			else:
				var branch = descriptor.get("branches", [])[branch_index]
				_validate_value_against_descriptor(value, branch, path, errors)
		"fallback":
			pass
		_:
			pass

func _path_or_root(path: String) -> String:
	if path == "":
		return "/"
	return path

func _create_empty_fallback(reason: String) -> Dictionary:
	return {
		"kind": "fallback",
		"title": "Schema",
		"description": "",
		"reason": reason,
		"pointer": ""
	}

func _set_in_tree(node, path: Array, depth: int, value):
	if depth >= path.size():
		return value
	var segment = path[depth]
	if segment is String:
		var dict_node = {}
		if node is Dictionary:
			dict_node = node.duplicate(true)
		dict_node[segment] = _set_in_tree(dict_node.get(segment, null), path, depth + 1, value)
		return dict_node
	if segment is int:
		var arr_node = []
		if node is Array:
			arr_node = node.duplicate(true)
		var index = int(segment)
		while arr_node.size() <= index:
			arr_node.append(null)
		arr_node[index] = _set_in_tree(arr_node[index], path, depth + 1, value)
		return arr_node
	return node

func _remove_in_tree(node, path: Array, depth: int):
	if depth >= path.size():
		return node
	var segment = path[depth]
	if depth == path.size() - 1:
		if segment is String and node is Dictionary:
			var dict_node = node.duplicate(true)
			dict_node.erase(segment)
			return dict_node
		if segment is int and node is Array:
			var arr_node = node.duplicate(true)
			var index = int(segment)
			if index >= 0 and index < arr_node.size():
				arr_node.remove_at(index)
			return arr_node
		return node
	if segment is String and node is Dictionary:
		var dict_node_next = node.duplicate(true)
		dict_node_next[segment] = _remove_in_tree(dict_node_next.get(segment, null), path, depth + 1)
		return dict_node_next
	if segment is int and node is Array:
		var arr_node_next = node.duplicate(true)
		var arr_index = int(segment)
		if arr_index >= 0 and arr_index < arr_node_next.size():
			arr_node_next[arr_index] = _remove_in_tree(arr_node_next[arr_index], path, depth + 1)
		return arr_node_next
	return node

func _find_matching_union_branch(value, descriptor: Dictionary) -> int:
	var branches = descriptor.get("branches", [])
	for i in range(branches.size()):
		if _value_matches_descriptor(value, branches[i]):
			return i
	return -1

func _value_matches_descriptor(value, descriptor: Dictionary) -> bool:
	var errs = []
	_validate_value_against_descriptor(value, descriptor, "", errs)
	return errs.is_empty()

func get_union_branch_index(path: Array, descriptor: Dictionary) -> int:
	var key = _path_key(path)
	if _union_selection.has(key):
		var stored = int(_union_selection[key])
		if stored >= 0 and stored < descriptor.get("branches", []).size():
			return stored
	var auto = _find_matching_union_branch(get_value_at_path(path), descriptor)
	if auto == -1:
		auto = 0
	_union_selection[key] = auto
	return auto

func _path_key(path: Array) -> String:
	if path.is_empty():
		return "/"
	var parts = []
	for segment in path:
		parts.append(str(segment))
	return "/" + "/".join(parts)

func _path_key_from_pointer(pointer: String) -> String:
	if pointer == "":
		return "/"
	return pointer

func _strip_nullable(descriptor: Dictionary) -> Dictionary:
	var copy = descriptor.duplicate(true)
	copy["nullable"] = false
	return copy

func _ensure_array_min_items(path: Array, descriptor: Dictionary) -> void:
	var current = get_value_at_path(path)
	var arr = []
	if current is Array:
		arr = current.duplicate(true)
	var min_items = int(descriptor.get("min_items", 0))
	while arr.size() < min_items:
		arr.append(create_default_value(descriptor.get("items", {})))
	set_value_at_path(path, arr, false)

func _on_optional_property_toggled(enabled: bool, path: Array, prop_name: String, prop_descriptor: Dictionary) -> void:
	var prop_path = path + [prop_name]
	if enabled:
		set_value_at_path(prop_path, create_default_value(prop_descriptor), true)
	else:
		remove_value_at_path(prop_path, true)

func _on_array_item_add_requested(path: Array, descriptor: Dictionary) -> void:
	var arr = get_value_at_path(path)
	if not (arr is Array):
		arr = []
	else:
		arr = arr.duplicate(true)
	var max_items = int(descriptor.get("max_items", -1))
	if max_items >= 0 and arr.size() >= max_items:
		return
	arr.append(create_default_value(descriptor.get("items", {})))
	set_value_at_path(path, arr, true)

func _on_array_item_delete_requested(_emitted_index: int, path: Array, index: int, descriptor: Dictionary) -> void:
	var arr = get_value_at_path(path)
	if not (arr is Array):
		return
	arr = arr.duplicate(true)
	var min_items = int(descriptor.get("min_items", 0))
	if arr.size() <= min_items:
		return
	if index >= 0 and index < arr.size():
		arr.remove_at(index)
	set_value_at_path(path, arr, true)

func _on_string_value_changed(new_text: String, path: Array, _descriptor: Dictionary) -> void:
	set_value_at_path(path, new_text, false)

func _on_number_value_changed(new_value: float, path: Array, descriptor: Dictionary) -> void:
	if str(descriptor.get("kind", "")) == "integer":
		set_value_at_path(path, int(round(new_value)), false)
	else:
		set_value_at_path(path, new_value, false)

func _on_bool_value_toggled(enabled: bool, path: Array, _descriptor: Dictionary) -> void:
	set_value_at_path(path, enabled, false)

func _on_enum_item_selected(index: int, path: Array, descriptor: Dictionary) -> void:
	var options = descriptor.get("enum_values", [])
	if index < 0 or index >= options.size():
		return
	set_value_at_path(path, options[index], false)

func _on_nullable_toggled(use_null: bool, path: Array, descriptor: Dictionary) -> void:
	if use_null:
		set_value_at_path(path, null, true)
		return
	var current = get_value_at_path(path)
	if current == null:
		set_value_at_path(path, create_default_value(_strip_nullable(descriptor)), true)
	else:
		_rebuild_form()
		_emit_after_value_update()

func _on_union_branch_selected(index: int, path: Array, descriptor: Dictionary) -> void:
	var branches = descriptor.get("branches", [])
	if index < 0 or index >= branches.size():
		return
	_union_selection[_path_key(path)] = index
	var current = get_value_at_path(path)
	var chosen_branch = branches[index]
	if not _value_matches_descriptor(current, chosen_branch):
		current = create_default_value(chosen_branch)
	set_value_at_path(path, current, true)

func _on_fallback_json_value_changed(value, path: Array, _descriptor: Dictionary) -> void:
	set_value_at_path(path, value, false)

func _on_fallback_validity_changed(ok: bool, message: String, path: Array, _descriptor: Dictionary) -> void:
	var key = _path_key(path)
	if ok:
		_fallback_errors.erase(key)
	else:
		_fallback_errors[key] = message
	_validate_current()
	fallback_error_changed.emit(_fallback_errors.size() > 0)
