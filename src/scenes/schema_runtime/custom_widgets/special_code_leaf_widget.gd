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
var _compact_layout_enabled = false

func bind_context(context: SchemaCustomWidgetContext) -> void:
	_context = context
	_ensure_value_shape()
	_sync_ui_from_context()
	var callback = Callable(self, "_on_special_code_text_changed")
	if not $SpecialCodeLineEdit.text_changed.is_connected(callback):
		$SpecialCodeLineEdit.text_changed.connect(callback)
	_apply_compact_layout()

func on_context_value_reloaded() -> void:
	if _context == null:
		return
	_sync_ui_from_context()

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	_apply_compact_layout()

func _ensure_value_shape() -> void:
	if _context == null:
		return
	var value = _context.get_value()
	if value is Dictionary and value.has("special_code"):
		return
	_context.set_value({"special_code": ""}, false)

func _sync_ui_from_context() -> void:
	if _context == null:
		return
	var value = _context.get_value()
	var code_value = ""
	if value is Dictionary and value.has("special_code"):
		code_value = str(value["special_code"])
	$SpecialCodeLineEdit.text = code_value
	$PreviewLabel.text = "Vorschau: " + code_value
	_update_error_state(code_value)

func _on_special_code_text_changed(new_text: String) -> void:
	if _context == null:
		return
	_context.set_value({"special_code": new_text}, false)
	$PreviewLabel.text = "Vorschau: " + new_text
	_update_error_state(new_text)

func _update_error_state(value: String) -> void:
	if _context == null:
		return
	if value.strip_edges() == "":
		$ErrorLabel.text = "special_code darf nicht leer sein"
		$ErrorLabel.visible = true
		_context.set_error("special_code darf nicht leer sein")
	else:
		$ErrorLabel.text = ""
		$ErrorLabel.visible = false
		_context.clear_error()

func _apply_compact_layout() -> void:
	if _compact_layout_enabled:
		add_theme_constant_override("separation", 4)
		$TitleLabel.visible = false
		return
	add_theme_constant_override("separation", 6)
	$TitleLabel.visible = true
