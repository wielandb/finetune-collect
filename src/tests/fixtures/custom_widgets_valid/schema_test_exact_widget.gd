extends SchemaCustomWidgetBase

var match_schema: Dictionary = {
	"type": "object",
	"required": ["special_code"],
	"properties": {
		"special_code": {"type": "string"}
	},
	"additionalProperties": false
}

var _context: SchemaCustomWidgetContext = null

func bind_context(context: SchemaCustomWidgetContext) -> void:
	_context = context
	var value = context.get_value()
	var code_value = ""
	if value is Dictionary and value.has("special_code"):
		code_value = str(value["special_code"])
	else:
		context.set_value({"special_code": code_value}, false)
	$SpecialCodeLineEdit.text = code_value
	var callback = Callable(self, "_on_special_code_text_changed")
	if not $SpecialCodeLineEdit.text_changed.is_connected(callback):
		$SpecialCodeLineEdit.text_changed.connect(callback)
	_update_error_state(code_value)

func on_context_value_reloaded() -> void:
	if _context == null:
		return
	var value = _context.get_value()
	if value is Dictionary and value.has("special_code"):
		$SpecialCodeLineEdit.text = str(value["special_code"])
		_update_error_state($SpecialCodeLineEdit.text)

func _on_special_code_text_changed(new_text: String) -> void:
	if _context == null:
		return
	_context.set_value({"special_code": new_text}, false)
	_update_error_state(new_text)

func _update_error_state(value: String) -> void:
	if _context == null:
		return
	if value.strip_edges() == "":
		_context.set_error("special_code must not be empty")
	else:
		_context.clear_error()
