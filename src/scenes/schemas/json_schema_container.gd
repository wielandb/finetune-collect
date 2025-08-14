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
	var tab_bar = $MarginContainer2/SchemasTabContainer.get_tab_bar()
	tab_bar.set_tab_title(0, tr("Edit JSON Schema"))
	tab_bar.set_tab_title(1, tr("OpenAI JSON Schema"))

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
	get_node("/root/FineTune").call_deferred("update_schemas_internal")

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
	var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidatorURL", "")
	if validator_url == "":
		_set_edit_result(false, "No validator URL")
		return
	_pending_schema = json.data
	_set_edit_pending()
	_current_validation = "edit"
	var body = {"action": "validate_schema", "schema": json.data}
	var body_json = JSON.stringify(body)
	var body_bytes: PackedByteArray = body_json.to_utf8_buffer()
	_validator.request_raw(validator_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body_bytes)
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
		msg = "HTTP error " + str(response_code)
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
		_pending_schema = json2.data["schema"]
		var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidatorURL", "")
		_set_oai_pending()
		_current_validation = "oai"
		var body2 = {"action": "validate_schema", "schema": _pending_schema}
		var body_json2 = JSON.stringify(body2)
		var body_bytes2: PackedByteArray = body_json2.to_utf8_buffer()
		_validator.request_raw(validator_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body_bytes2)
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
	_on_edit_json_schema_code_edit_text_changed()
	get_node("/root/FineTune").update_schemas_internal()

func to_var():
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit.text
	var json := JSON.new()
	var schema = null
	if json.parse(editor.text) == OK:
		schema = json.data
	var json2 := JSON.new()
	var sanitized_schema = null
	if json2.parse(oai_editor.text) == OK and json2.data is Dictionary:
		var dat = json2.data
		sanitized_schema = dat.get("schema", dat)
		if name == "" and dat.has("name") and dat["name"] is String:
			name = dat["name"]
	return {"schema": schema, "sanitizedSchema": sanitized_schema, "name": name}

func from_var(data):
	var editor := $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor := $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name_edit := $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
	var schema = data.get("schema", null)
	var sanitized_schema = data.get("sanitizedSchema", null)
	var name = data.get("name", "")
	if schema != null:
		editor.text = JSON.stringify(schema, "\t")
	else:
		editor.text = ""
	if sanitized_schema != null:
		var envelope = {"name": name, "schema": sanitized_schema}
		oai_editor.text = JSON.stringify(envelope, "\t")
		_set_edit_result(true)
		_set_oai_result(true)
	else:
		oai_editor.text = ""
		_set_edit_result(false)
		_set_oai_result(false)
	name_edit.text = name
