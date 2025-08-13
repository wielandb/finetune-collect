extends HBoxContainer

@onready var code_edit = $MarginContainer2/JSONSchemaCodeEdit
@onready var name_edit = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
@onready var validate_img = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer/SchemaValidateTextureRect
@onready var validate_label = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer/SchemaValidateLabel
@onready var error_label = $MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel
@onready var spinner = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer/Spinner
@onready var http_request = $SchemaValidatorHTTPRequest

var ignore_code_change = false
var ignore_name_change = false

func _ready():
code_edit.text_changed.connect(_on_code_text_changed)
name_edit.text_changed.connect(_on_name_changed)
http_request.request_completed.connect(_on_request_completed)
_on_code_text_changed()

func _on_delete_schema_button_pressed() -> void:
queue_free()

func _on_code_text_changed():
if ignore_code_change:
return
var text = code_edit.text
var json = JSON.new()
if json.parse(text) != OK:
validate_img.texture = load("res://icons/code-json-check-negative.png")
validate_label.text = "SCHEMAS_SCHEMA_NOT_VALID"
error_label.text = json.get_error_message()
return
else:
error_label.text = ""
_update_name_from_schema(json.data)
var url = get_node("/root/FineTune").SETTINGS.get("jsonSchemaValidatorURL", "")
if url == "" or not url.begins_with("http"):
validate_img.texture = load("res://icons/code-json-check-negative.png")
validate_label.text = "SCHEMAS_SCHEMA_NOT_VALID"
error_label.text = "No validator URL"
return
spinner.visible = true
validate_img.visible = false
http_request.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, text)

func _on_request_completed(result, response_code, headers, body):
spinner.visible = false
validate_img.visible = true
if response_code != 200:
validate_img.texture = load("res://icons/code-json-check-negative.png")
validate_label.text = "SCHEMAS_SCHEMA_NOT_VALID"
error_label.text = "HTTP " + str(response_code)
return
var json = JSON.new()
if json.parse(body.get_string_from_utf8()) != OK:
validate_img.texture = load("res://icons/code-json-check-negative.png")
validate_label.text = "SCHEMAS_SCHEMA_NOT_VALID"
error_label.text = "Invalid response"
return
var data = json.data
if data.get("valid", false):
validate_img.texture = load("res://icons/code-json-check-positive.png")
validate_label.text = "SCHEMAS_SCHEMA_VALIDATED"
error_label.text = ""
else:
validate_img.texture = load("res://icons/code-json-check-negative.png")
validate_label.text = "SCHEMAS_SCHEMA_NOT_VALID"
error_label.text = JSON.stringify(data.get("errors", []))

func _update_name_from_schema(data):
if data.has("title") and typeof(data["title"]) == TYPE_STRING:
ignore_name_change = true
name_edit.text = data["title"]
ignore_name_change = false

func _on_name_changed(new_text):
if ignore_name_change:
return
var json = JSON.new()
if json.parse(code_edit.text) != OK:
return
var data = json.data
data["title"] = new_text
ignore_code_change = true
code_edit.text = JSON.stringify(data, "\t")
ignore_code_change = false
_on_code_text_changed()

func to_var():
return {"name": name_edit.text, "schema": code_edit.text}

func from_var(d):
name_edit.text = d.get("name", "")
code_edit.text = d.get("schema", "")
_on_code_text_changed()
