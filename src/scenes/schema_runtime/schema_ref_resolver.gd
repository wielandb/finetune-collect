extends RefCounted

class_name SchemaRefResolver

static func resolve_schema(schema: Dictionary) -> Dictionary:
	var root_copy = schema.duplicate(true)
	var resolved = _resolve_node(root_copy, root_copy, [])
	return {
		"schema": resolved,
		"has_external_ref": _contains_marker(resolved, "x_ftc_external_ref"),
		"has_ref_cycle": _contains_marker(resolved, "x_ftc_ref_cycle")
	}

static func _resolve_node(node, root: Dictionary, stack: Array):
	if node is Array:
		var out_array = []
		for item in node:
			out_array.append(_resolve_node(item, root, stack))
		return out_array

	if not (node is Dictionary):
		return node

	var node_dict = node.duplicate(true)
	if node_dict.has("$ref") and node_dict["$ref"] is String:
		var ref = node_dict["$ref"]
		if not ref.begins_with("#/"):
			return {
				"x_ftc_external_ref": ref,
				"x_ftc_source": node_dict
			}
		if stack.has(ref):
			return {
				"x_ftc_ref_cycle": ref,
				"x_ftc_source": node_dict
			}
		var target = _json_pointer_get(root, ref)
		if not (target is Dictionary):
			return {
				"x_ftc_external_ref": ref,
				"x_ftc_source": node_dict
			}
		var merged = _merge_ref_with_siblings(target, node_dict)
		var new_stack = stack.duplicate()
		new_stack.append(ref)
		return _resolve_node(merged, root, new_stack)

	var out_dict = {}
	for key in node_dict.keys():
		out_dict[key] = _resolve_node(node_dict[key], root, stack)
	return out_dict

static func _merge_ref_with_siblings(target: Dictionary, node_with_ref: Dictionary) -> Dictionary:
	var merged = target.duplicate(true)
	for key in node_with_ref.keys():
		if key == "$ref":
			continue
		merged[key] = node_with_ref[key]
	return merged

static func _json_pointer_get(root: Dictionary, pointer: String):
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

static func _contains_marker(node, marker: String) -> bool:
	if node is Dictionary:
		if node.has(marker):
			return true
		for key in node.keys():
			if _contains_marker(node[key], marker):
				return true
	elif node is Array:
		for item in node:
			if _contains_marker(item, marker):
				return true
	return false
