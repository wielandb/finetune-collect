extends RefCounted

class_name SchemaCustomWidgetContext

var _controller = null
var _descriptor = {}
var _path = []

func _init(controller, descriptor: Dictionary, path: Array) -> void:
	_controller = controller
	_descriptor = descriptor.duplicate(true)
	_path = path.duplicate(true)

func get_value():
	if _controller == null:
		return null
	return _controller.get_value_at_path(_path)

func set_value(value, request_rebuild: bool = false) -> void:
	if _controller == null:
		return
	_controller.set_value_at_path(_path, value, request_rebuild)

func get_descriptor() -> Dictionary:
	return _descriptor.duplicate(true)

func get_path() -> Array:
	return _path.duplicate(true)

func create_default_value(descriptor_override: Dictionary = {}):
	if _controller == null:
		return null
	var target_descriptor = _descriptor
	if descriptor_override is Dictionary and not descriptor_override.is_empty():
		target_descriptor = descriptor_override
	return _controller.create_default_value(target_descriptor)

func set_error(message: String) -> void:
	if _controller == null:
		return
	_controller.set_widget_error_at_path(_path, message)

func clear_error() -> void:
	if _controller == null:
		return
	_controller.clear_widget_error_at_path(_path)
