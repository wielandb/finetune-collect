extends HBoxContainer

const SchemaAlignOpenAI := preload("res://scenes/schemas/schema_align_openai.gd")
const ICON_POSITIVE := preload("res://icons/code-json-check-positive.png")
const ICON_NEGATIVE := preload("res://icons/code-json-check-negative.png")

var pending_schema_json = {}
var pending_oai_schema_json = {}
var validator_state := ""

@onready var validator_request := $SchemaValidatorHTTPRequest

func _ready() -> void:
	validator_request.request_completed.connect(_on_schema_validator_request_completed)

func _on_delete_schema_button_pressed() -> void:
	queue_free()

func set_edit_schema_result(ok: bool, msg: String) -> void:
	var container = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer
	container.get_node("Spinner").visible = false
	container.get_node("SchemaValidateTextureRect").texture = ok ? ICON_POSITIVE : ICON_NEGATIVE
	container.get_node("SchemaValidateLabel").text = ok ? tr("SCHEMAS_SCHEMA_VALIDATED") : ""
	var err_label = $MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel
	err_label.visible = not ok
	err_label.text = msg

func set_oai_schema_result(ok: bool, msg: String) -> void:
	var container = $MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2
	container.get_node("Spinner").visible = false
	container.get_node("SchemaValidateTextureRect").texture = ok ? ICON_POSITIVE : ICON_NEGATIVE
	container.get_node("SchemaValidateLabel").text = ok ? tr("SCHEMAS_SCHEMA_VALIDATED") : ""
	var err_label = $MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel
	err_label.visible = not ok
	err_label.text = msg

func _on_edit_json_schema_code_edit_text_changed() -> void:
	var editor = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor = $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	validator_request.cancel_request()
	set_edit_schema_result(false, "")
	set_oai_schema_result(false, "")
	oai_editor.text = ""
	var json = JSON.new()
	var err = json.parse(editor.text)
	if err != OK:
		set_edit_schema_result(false, json.get_error_message())
		return
	var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidatorURL", "")
	if validator_url == "":
		set_edit_schema_result(false, "No validator URL set")
		return
	pending_schema_json = json.data
	validator_state = "edit"
	$MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer/Spinner.visible = true
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload = {"action": "validateSchema", "schema": pending_schema_json}
	var req_err = validator_request.request(validator_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if req_err != OK:
		set_edit_schema_result(false, "Request error")
		return

func _on_schema_validator_request_completed(result, response_code, headers, body):
	var text = body.get_string_from_utf8()
	var resp = JSON.parse_string(text)
	if validator_state == "edit":
		if response_code != 200 or typeof(resp) != TYPE_DICTIONARY:
			set_edit_schema_result(false, "HTTP error")
			return
		if resp.get("ok", false):
			set_edit_schema_result(true, "")
			var sanitized = SchemaAlignOpenAI.sanitize_envelope_or_schema(pending_schema_json)
			var oai_editor = $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
			oai_editor.text = JSON.stringify(sanitized, "	")
			var json2 = JSON.new()
			var err2 = json2.parse(oai_editor.text)
			if err2 != OK:
				set_oai_schema_result(false, json2.get_error_message())
				return
			pending_oai_schema_json = json2.data
			var validator_url = get_node("/root/FineTune").SETTINGS.get("schemaValidatorURL", "")
			if validator_url == "":
				set_oai_schema_result(false, "No validator URL set")
				return
			validator_state = "oai"
			$MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2/Spinner.visible = true
			var headers2 := PackedStringArray(["Content-Type: application/json"])
			var payload2 = {"action": "validateSchema", "schema": pending_oai_schema_json}
			var req_err2 = validator_request.request(validator_url, headers2, HTTPClient.METHOD_POST, JSON.stringify(payload2))
			if req_err2 != OK:
				set_oai_schema_result(false, "Request error")
				return
		else:
			var msg = ""
			if resp.has("errors") and resp["errors"].size() > 0:
				msg = str(resp["errors"][0].get("message", "Invalid schema"))
			set_edit_schema_result(false, msg)
	elif validator_state == "oai":
		validator_state = ""
		if response_code != 200 or typeof(resp) != TYPE_DICTIONARY:
			set_oai_schema_result(false, "HTTP error")
			return
		if resp.get("ok", false):
			set_oai_schema_result(true, "")
		else:
			var msg = ""
			if resp.has("errors") and resp["errors"].size() > 0:
				msg = str(resp["errors"][0].get("message", "Invalid schema"))
			set_oai_schema_result(false, msg)
