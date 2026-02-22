extends VBoxContainer

signal json_value_changed(value)
signal validity_changed(ok: bool, message: String)

var _last_valid_value = null
var _suppress_change = false

func _ready() -> void:
	$FallbackTitle.text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_TITLE")
	$FallbackDescription.text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_DEFAULT_DESCRIPTION")
	$FallbackError.text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_INVALID_JSON")
	$FallbackJSONEdit.text_changed.connect(_on_fallback_json_text_changed)

func configure(title: String, description: String, reason: String) -> void:
	if title == "":
		$FallbackTitle.text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_TITLE")
	else:
		$FallbackTitle.text = title
	var reason_text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_REASON_PREFIX")
	reason_text = reason_text.replace("{reason}", reason)
	if description != "":
		reason_text += "\n" + description
	$FallbackDescription.text = reason_text

func set_json_value(value) -> void:
	_last_valid_value = value
	_suppress_change = true
	$FallbackJSONEdit.text = JSON.stringify(value, "\t")
	_suppress_change = false
	$FallbackError.visible = false
	validity_changed.emit(true, "")

func get_json_value():
	return _last_valid_value

func _on_fallback_json_text_changed() -> void:
	if _suppress_change:
		return
	var json = JSON.new()
	var err = json.parse($FallbackJSONEdit.text)
	if err != OK:
		$FallbackError.visible = true
		$FallbackError.text = tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_INVALID_JSON")
		validity_changed.emit(false, $FallbackError.text)
		return
	$FallbackError.visible = false
	_last_valid_value = json.data
	json_value_changed.emit(_last_valid_value)
	validity_changed.emit(true, "")
