extends RefCounted

class_name SchemaDescriptorSignature

const _METADATA_KEYS = {
	"pointer": true,
	"title": true,
	"description": true,
	"default": true,
	"source_schema": true
}

func descriptor_signature(descriptor: Dictionary) -> String:
	var canonical = _canonicalize_descriptor(descriptor)
	return JSON.stringify(canonical)

func descriptor_complexity(descriptor: Dictionary) -> int:
	return descriptor_signature(descriptor).length()

func descriptors_equal(a: Dictionary, b: Dictionary) -> bool:
	return descriptor_signature(a) == descriptor_signature(b)

func _canonicalize_descriptor(descriptor):
	if not (descriptor is Dictionary):
		return descriptor
	var kind = str(descriptor.get("kind", ""))
	var out = {
		"kind": kind,
		"nullable": bool(descriptor.get("nullable", false))
	}
	match kind:
		"object":
			out["additional_properties"] = _canonicalize_json_value(descriptor.get("additional_properties", true))
			var required = []
			for req_name in descriptor.get("required", []):
				required.append(str(req_name))
			required.sort()
			out["required"] = required
			var canonical_properties = []
			for property_entry in descriptor.get("properties", []):
				if not (property_entry is Dictionary):
					continue
				canonical_properties.append({
					"name": str(property_entry.get("name", "")),
					"required": bool(property_entry.get("required", false)),
					"descriptor": _canonicalize_descriptor(property_entry.get("descriptor", {}))
				})
			canonical_properties = _sort_dictionary_array_by_key(canonical_properties, "name")
			out["properties"] = canonical_properties
		"array":
			out["items"] = _canonicalize_descriptor(descriptor.get("items", {}))
			out["min_items"] = int(descriptor.get("min_items", 0))
			out["max_items"] = int(descriptor.get("max_items", -1))
			out["unique_items"] = bool(descriptor.get("unique_items", false))
		"string":
			out["min_length"] = int(descriptor.get("min_length", -1))
			out["max_length"] = int(descriptor.get("max_length", -1))
			out["pattern"] = str(descriptor.get("pattern", ""))
			out["format"] = str(descriptor.get("format", ""))
		"number", "integer":
			out["minimum"] = _canonicalize_json_value(descriptor.get("minimum", null))
			out["maximum"] = _canonicalize_json_value(descriptor.get("maximum", null))
			out["exclusive_minimum"] = _canonicalize_json_value(descriptor.get("exclusive_minimum", null))
			out["exclusive_maximum"] = _canonicalize_json_value(descriptor.get("exclusive_maximum", null))
			out["multiple_of"] = _canonicalize_json_value(descriptor.get("multiple_of", null))
		"boolean":
			pass
		"enum":
			var enum_values = []
			for enum_value in descriptor.get("enum_values", []):
				enum_values.append(_canonicalize_json_value(enum_value))
			out["enum_values"] = _sort_json_values(enum_values)
		"const":
			out["const_value"] = _canonicalize_json_value(descriptor.get("const_value", null))
		"null":
			pass
		"union":
			out["mode"] = str(descriptor.get("mode", ""))
			out["null_branch_optional"] = bool(descriptor.get("null_branch_optional", false))
			var canonical_branches = []
			for branch in descriptor.get("branches", []):
				canonical_branches.append(_canonicalize_descriptor(branch))
			out["branches"] = _sort_json_values(canonical_branches)
		"fallback":
			out["reason"] = str(descriptor.get("reason", ""))
		_:
			var keys = []
			for raw_key in descriptor.keys():
				var key = str(raw_key)
				if _METADATA_KEYS.has(key):
					continue
				keys.append(key)
			keys.sort()
			for key_name in keys:
				out[key_name] = _canonicalize_json_value(descriptor.get(key_name, null))
	return out

func _canonicalize_json_value(value):
	if value is Dictionary:
		var out = {}
		var keys = []
		for raw_key in value.keys():
			keys.append(str(raw_key))
		keys.sort()
		for key in keys:
			out[key] = _canonicalize_json_value(value[key])
		return out
	if value is Array:
		var out_array = []
		for item in value:
			out_array.append(_canonicalize_json_value(item))
		return out_array
	return value

func _sort_dictionary_array_by_key(values: Array, key_name: String) -> Array:
	var buckets = {}
	var keys = []
	for value in values:
		var key = ""
		if value is Dictionary:
			key = str(value.get(key_name, ""))
		if not buckets.has(key):
			buckets[key] = []
			keys.append(key)
		buckets[key].append(value)
	keys.sort()
	var out = []
	for key in keys:
		for entry in buckets[key]:
			out.append(entry)
	return out

func _sort_json_values(values: Array) -> Array:
	var buckets = {}
	var keys = []
	for value in values:
		var signature = JSON.stringify(value)
		if not buckets.has(signature):
			buckets[signature] = []
			keys.append(signature)
		buckets[signature].append(value)
	keys.sort()
	var out = []
	for signature in keys:
		for entry in buckets[signature]:
			out.append(entry)
	return out
