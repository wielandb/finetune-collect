extends HBoxContainer

const SchemaAlignOpenAI := preload("res://scenes/schemas/schema_align_openai.gd")

var _updating_from_name := false
@onready var _validator := $SchemaValidatorHTTPRequest
var _pending_schema = null
var _current_validation := ""
const VALID_ICON_OK := "res://icons/code-json-check-positive.png"
const VALID_ICON_BAD := "res://icons/code-json-check-negative.png"

func _ready() -> void:
	_validator.request_completed.connect(_on_schema_validator_request_completed)

func _set_edit_pending() -> void:
	var c := $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer
	c.get_node("Spinner").visible = true
	c.get_node("SchemaValidateTextureRect").visible = false
	$MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel.visible = false

func _set_edit_result(ok: bool, msg := "") -> void:
	var c := $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer
	c.get_node("Spinner").visible = false
	c.get_node("SchemaValidateTextureRect").visible = true
	if ok:
		c.get_node("SchemaValidateTextureRect").texture = load(VALID_ICON_OK)
		c.get_node("SchemaValidateLabel").text = "SCHEMAS_SCHEMA_VALIDATED"
		$MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel.visible = false
	else:
		c.get_node("SchemaValidateTextureRect").texture = load(VALID_ICON_BAD)
		c.get_node("SchemaValidateLabel").text = "SCHEMAS_SCHEMA_INVALID"
		$MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel.visible = true
		$MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel.text = msg

func _set_oai_pending() -> void:
	var c := $MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2
	c.get_node("Spinner").visible = true
	c.get_node("SchemaValidateTextureRect").visible = false
	$MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel.visible = false

func _set_oai_result(ok: bool, msg := "") -> void:
	var c := $MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2
	c.get_node("Spinner").visible = false
	c.get_node("SchemaValidateTextureRect").visible = true
	if ok:
		c.get_node("SchemaValidateTextureRect").texture = load(VALID_ICON_OK)
		c.get_node("SchemaValidateLabel").text = "SCHEMAS_SCHEMA_VALIDATED"
		$MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel.visible = false
	else:
		c.get_node("SchemaValidateTextureRect").texture = load(VALID_ICON_BAD)
		c.get_node("SchemaValidateLabel").text = "SCHEMAS_SCHEMA_INVALID"
		$MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel.visible = true
		$MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel.text = msg

func _on_delete_schema_button_pressed() -> void:
	queue_free()

func _on_edit_json_schema_code_edit_text_changed() -> void:
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name_edit := $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
	oai_editor.text = ""
	_set_oai_result(false)
	var json := JSON.new()
	var err := json.parse(editor.text)
	if err != OK:
		_set_edit_result(false, "Invalid JSON")
		return
	var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidationURL", "")
	if validator_url == "":
		_set_edit_result(false, "No validator URL")
		return
	_pending_schema = json.data
	_set_edit_pending()
	_current_validation = "edit"
	var body = {"action": "validateSchema", "schema": json.data}
	_validator.request(validator_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if not _updating_from_name and json.data is Dictionary and json.data.has("title"):
		var title = json.data["title"]
		if title is String:
			name_edit.text = title

func _on_schema_validator_request_completed(result, response_code, headers, body):
	var target := _current_validation
	_current_validation = ""
	var text = body.get_string_from_utf8()
	var ok = false
	var msg = ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var res = JSON.parse_string(text)
		if res is Dictionary:
			ok = res.get("ok", false)
			if not ok and res.has("errors"):
				msg = JSON.stringify(res["errors"])
	else:
		msg = "HTTP error"
	if target == "edit":
		if not ok:
			_set_edit_result(false, msg)
			return
		_set_edit_result(true)
		var sanitized = SchemaAlignOpenAI.sanitize_envelope_or_schema(_pending_schema)
		var oai_text = JSON.stringify(sanitized, "	")
		var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
		oai_editor.text = oai_text
		var json2 := JSON.new()
		if json2.parse(oai_text) != OK:
			_set_oai_result(false, "Invalid JSON")
			return
		_pending_schema = json2.data
		var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidationURL", "")
		_set_oai_pending()
		_current_validation = "oai"
		var body2 = {"action": "validateSchema", "schema": json2.data}
		_validator.request(validator_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body2))
	elif target == "oai":
		if not ok:
			_set_oai_result(false, msg)
			return
		_set_oai_result(true)

func _on_schema_name_line_edit_text_changed(new_text: String) -> void:
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var json := JSON.new()
	var err := json.parse(editor.text)
	if err != OK or not (json.data is Dictionary):
		return
	_updating_from_name = true
	json.data["title"] = new_text
	editor.text = JSON.stringify(json.data, "	")
	_updating_from_name = false
