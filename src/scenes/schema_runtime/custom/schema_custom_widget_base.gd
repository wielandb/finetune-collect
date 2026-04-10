extends Control

class_name SchemaCustomWidgetBase

func bind_context(_context: SchemaCustomWidgetContext) -> void:
	push_error("Custom schema widget must implement bind_context(context)")
