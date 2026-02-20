extends RefCounted

class_name SchemaRefResolver

static func resolve_schema(schema: Dictionary, external_schemas: Dictionary = {}) -> Dictionary:
	var root_copy = schema.duplicate(true)
	var resolved = _resolve_node(root_copy, root_copy, "", external_schemas, [])
	return {
		"schema": resolved,
		"has_external_ref": _contains_marker(resolved, "x_ftc_external_ref"),
		"has_ref_cycle": _contains_marker(resolved, "x_ftc_ref_cycle")
	}

static func has_external_document_ref(schema, base_url: String = "") -> bool:
	return collect_external_document_urls(schema, base_url).size() > 0

static func collect_external_document_urls(schema, base_url: String = "") -> Array:
	var urls = []
	var seen = {}
	_collect_external_document_urls_recursive(schema, base_url, urls, seen)
	return urls

static func _resolve_node(node, root: Dictionary, base_url: String, external_schemas: Dictionary, stack: Array):
	if node is Array:
		var out_array = []
		for item in node:
			out_array.append(_resolve_node(item, root, base_url, external_schemas, stack))
		return out_array

	if not (node is Dictionary):
		return node

	var node_dict = node.duplicate(true)
	if node_dict.has("$ref") and node_dict["$ref"] is String:
		var ref = str(node_dict["$ref"])
		var parsed_ref = _parse_ref(ref, base_url)
		if not bool(parsed_ref.get("ok", false)):
			return _make_external_ref_marker(ref, node_dict, str(parsed_ref.get("error", "invalid $ref")))
		var resolved_id = str(parsed_ref.get("resolved_id", ""))
		if stack.has(resolved_id):
			return {
				"x_ftc_ref_cycle": resolved_id,
				"x_ftc_source": node_dict
			}
		var target_root = root
		var target = null
		var next_base_url = base_url
		if bool(parsed_ref.get("is_external", false)):
			var document_url = str(parsed_ref.get("document_url", ""))
			if document_url == "":
				return _make_external_ref_marker(ref, node_dict, "external $ref has no document URL")
			if not external_schemas.has(document_url):
				return _make_external_ref_marker(ref, node_dict, "external schema not loaded")
			target_root = external_schemas.get(document_url, null)
			if not (target_root is Dictionary):
				return _make_external_ref_marker(ref, node_dict, "external schema is not an object")
			next_base_url = document_url
			target = _json_pointer_get(target_root, str(parsed_ref.get("pointer", "#")))
		else:
			target = _json_pointer_get(root, str(parsed_ref.get("pointer", "#")))
		if not (target is Dictionary):
			return _make_external_ref_marker(ref, node_dict, "unresolvable $ref")
		var merged = _merge_ref_with_siblings(target, node_dict)
		var new_stack = stack.duplicate()
		new_stack.append(resolved_id)
		return _resolve_node(merged, target_root, next_base_url, external_schemas, new_stack)

	var out_dict = {}
	for key in node_dict.keys():
		out_dict[key] = _resolve_node(node_dict[key], root, base_url, external_schemas, stack)
	return out_dict

static func _merge_ref_with_siblings(target: Dictionary, node_with_ref: Dictionary) -> Dictionary:
	var merged = target.duplicate(true)
	for key in node_with_ref.keys():
		if key == "$ref":
			continue
		merged[key] = node_with_ref[key]
	return merged

static func _collect_external_document_urls_recursive(node, base_url: String, output: Array, seen: Dictionary) -> void:
	if node is Array:
		for item in node:
			_collect_external_document_urls_recursive(item, base_url, output, seen)
		return
	if not (node is Dictionary):
		return
	if node.has("$ref") and node["$ref"] is String:
		var parsed_ref = _parse_ref(str(node["$ref"]), base_url)
		if bool(parsed_ref.get("ok", false)) and bool(parsed_ref.get("is_external", false)):
			var document_url = str(parsed_ref.get("document_url", ""))
			if document_url != "" and not seen.has(document_url):
				seen[document_url] = true
				output.append(document_url)
	for key in node.keys():
		_collect_external_document_urls_recursive(node[key], base_url, output, seen)

static func _make_external_ref_marker(ref: String, source: Dictionary, reason: String) -> Dictionary:
	return {
		"x_ftc_external_ref": ref,
		"x_ftc_external_ref_reason": reason,
		"x_ftc_source": source
	}

static func _parse_ref(ref: String, base_url: String) -> Dictionary:
	var normalized_ref = ref.strip_edges()
	if normalized_ref == "":
		return {"ok": false, "error": "empty $ref"}
	var split = _split_ref(normalized_ref)
	var doc = str(split.get("document", ""))
	var pointer = str(split.get("pointer", "#"))
	if pointer == "":
		pointer = "#"
	if doc == "":
		if not pointer.begins_with("#"):
			return {"ok": false, "error": "invalid internal pointer"}
		return {
			"ok": true,
			"is_external": false,
			"pointer": pointer,
			"resolved_id": "local:" + pointer
		}
	var resolved_doc = _resolve_document_url(doc, base_url)
	if resolved_doc == "":
		return {"ok": false, "error": "unsupported external $ref URL"}
	return {
		"ok": true,
		"is_external": true,
		"document_url": resolved_doc,
		"pointer": pointer,
		"resolved_id": "external:" + resolved_doc + pointer
	}

static func _split_ref(ref: String) -> Dictionary:
	var hash_index = ref.find("#")
	if hash_index == -1:
		return {"document": ref, "pointer": "#"}
	return {
		"document": ref.substr(0, hash_index),
		"pointer": ref.substr(hash_index)
	}

static func _resolve_document_url(doc: String, base_url: String) -> String:
	var url = doc.strip_edges()
	if url == "":
		return ""
	if _is_http_url(url):
		return _strip_query_fragment(url)
	if url.begins_with("//"):
		var base_parts = _split_http_url(base_url)
		if base_parts.is_empty():
			return ""
		return base_parts["scheme"] + ":" + url
	if base_url == "":
		return ""
	var base_parts = _split_http_url(base_url)
	if base_parts.is_empty():
		return ""
	var ref_path = url
	var ref_query = ""
	var query_index = ref_path.find("?")
	if query_index != -1:
		ref_query = ref_path.substr(query_index)
		ref_path = ref_path.substr(0, query_index)
	var origin = base_parts["scheme"] + "://" + base_parts["host"]
	if ref_path.begins_with("/"):
		return origin + _normalize_url_path(ref_path) + ref_query
	var base_path = str(base_parts.get("path", "/"))
	var base_dir = base_path
	if not base_dir.ends_with("/"):
		var slash = base_dir.rfind("/")
		if slash == -1:
			base_dir = "/"
		else:
			base_dir = base_dir.substr(0, slash + 1)
	return origin + _normalize_url_path(base_dir + ref_path) + ref_query

static func _is_http_url(url: String) -> bool:
	return url.begins_with("http://") or url.begins_with("https://")

static func _strip_query_fragment(url: String) -> String:
	var out = url
	var hash_index = out.find("#")
	if hash_index != -1:
		out = out.substr(0, hash_index)
	var query_index = out.find("?")
	if query_index != -1:
		out = out.substr(0, query_index)
	return out

static func _split_http_url(url: String) -> Dictionary:
	var normalized = _strip_query_fragment(url.strip_edges())
	if not _is_http_url(normalized):
		return {}
	var sep = normalized.find("://")
	if sep == -1:
		return {}
	var scheme = normalized.substr(0, sep)
	var rest = normalized.substr(sep + 3)
	var slash = rest.find("/")
	if slash == -1:
		return {"scheme": scheme, "host": rest, "path": "/"}
	return {
		"scheme": scheme,
		"host": rest.substr(0, slash),
		"path": rest.substr(slash)
	}

static func _normalize_url_path(path: String) -> String:
	var absolute = path.begins_with("/")
	var parts = path.split("/")
	var normalized_parts = []
	for part in parts:
		if part == "" or part == ".":
			continue
		if part == "..":
			if normalized_parts.size() > 0:
				normalized_parts.pop_back()
			continue
		normalized_parts.append(part)
	var normalized = "/".join(normalized_parts)
	if absolute:
		return "/" + normalized
	return normalized

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
