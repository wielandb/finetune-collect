extends RefCounted

class_name SchemaCustomWidgetRegistry

const CUSTOM_WIDGETS_DIR = "res://scenes/schema_runtime/custom_widgets"

var _entries = []
var _loaded = false
var _compiler = SchemaFormCompiler.new()
var _signature = SchemaDescriptorSignature.new()
var _custom_widgets_dir = CUSTOM_WIDGETS_DIR

func _init(custom_widgets_dir: String = CUSTOM_WIDGETS_DIR) -> void:
	var normalized = custom_widgets_dir.strip_edges()
	if normalized != "":
		_custom_widgets_dir = normalized

func ensure_loaded() -> void:
	if _loaded:
		return
	reload()

func reload() -> void:
	_entries = []
	_loaded = true
	var scene_paths = _discover_widget_scene_paths()
	for scene_path in scene_paths:
		var entry = _build_registry_entry(scene_path)
		if entry.is_empty():
			continue
		_entries.append(entry)

func find_best_widget_for_descriptor(descriptor: Dictionary) -> Dictionary:
	ensure_loaded()
	if not (descriptor is Dictionary):
		return {}
	var target_signature = _signature.descriptor_signature(descriptor)
	if target_signature == "":
		return {}
	var best = {}
	for entry in _entries:
		if str(entry.get("signature", "")) != target_signature:
			continue
		if best.is_empty():
			best = entry
			continue
		var best_complexity = int(best.get("complexity", -1))
		var entry_complexity = int(entry.get("complexity", -1))
		if entry_complexity > best_complexity:
			best = entry
			continue
		if entry_complexity == best_complexity and str(entry.get("scene_path", "")) < str(best.get("scene_path", "")):
			best = entry
	return best

func get_registered_scene_paths() -> Array:
	ensure_loaded()
	var out = []
	for entry in _entries:
		out.append(str(entry.get("scene_path", "")))
	return out

func _discover_widget_scene_paths() -> Array:
	var out_paths = []
	_collect_widget_scene_paths_recursive(_custom_widgets_dir, out_paths)
	out_paths.sort()
	return out_paths

func _collect_widget_scene_paths_recursive(directory_path: String, out_paths: Array) -> void:
	var directory = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name = directory.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = directory.get_next()
			continue
		var full_path = directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_collect_widget_scene_paths_recursive(full_path, out_paths)
		elif entry_name.get_extension().to_lower() == "tscn":
			out_paths.append(full_path)
		entry_name = directory.get_next()
	directory.list_dir_end()

func _build_registry_entry(scene_path: String) -> Dictionary:
	var packed_scene = load(scene_path)
	if not (packed_scene is PackedScene):
		push_warning("Ignoring custom schema widget scene without PackedScene type: " + scene_path)
		return {}
	var instance = packed_scene.instantiate()
	if instance == null:
		push_warning("Ignoring custom schema widget scene that could not be instantiated: " + scene_path)
		return {}
	if not (instance is SchemaCustomWidgetBase):
		push_warning("Ignoring custom schema widget scene without SchemaCustomWidgetBase root script: " + scene_path)
		instance.free()
		return {}
	if not instance.has_method("bind_context"):
		push_warning("Ignoring custom schema widget scene without bind_context(context): " + scene_path)
		instance.free()
		return {}
	if not _has_property(instance, "match_schema"):
		push_warning("Ignoring custom schema widget scene without match_schema property: " + scene_path)
		instance.free()
		return {}
	var match_schema_value = instance.get("match_schema")
	if not (match_schema_value is Dictionary):
		push_warning("Ignoring custom schema widget scene with non-dictionary match_schema: " + scene_path)
		instance.free()
		return {}
	var compiled = _compiler.compile_schema(match_schema_value)
	if bool(compiled.get("has_partial_fallback", false)):
		push_warning("Ignoring custom schema widget scene with unsupported match_schema: " + scene_path)
		instance.free()
		return {}
	var match_descriptor = compiled.get("descriptor", {})
	if not (match_descriptor is Dictionary):
		push_warning("Ignoring custom schema widget scene with invalid descriptor: " + scene_path)
		instance.free()
		return {}
	if str(match_descriptor.get("kind", "")) == "fallback":
		push_warning("Ignoring custom schema widget scene whose match_schema compiled to fallback: " + scene_path)
		instance.free()
		return {}
	var signature = _signature.descriptor_signature(match_descriptor)
	if signature == "":
		push_warning("Ignoring custom schema widget scene with empty signature: " + scene_path)
		instance.free()
		return {}
	var entry = {
		"scene_path": scene_path,
		"packed_scene": packed_scene,
		"signature": signature,
		"complexity": _signature.descriptor_complexity(match_descriptor),
		"match_descriptor": match_descriptor.duplicate(true)
	}
	instance.free()
	return entry

func _has_property(instance, property_name: String) -> bool:
	for property_info in instance.get_property_list():
		if not (property_info is Dictionary):
			continue
		if str(property_info.get("name", "")) == property_name:
			return true
	return false
