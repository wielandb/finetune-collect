extends HBoxContainer

const SchemaAlignOpenAI := preload("res://scenes/schemas/schema_align_openai.gd")
const JsonSchemaValidator := preload("res://json_schema_validator.gd")

var _updating_from_name := false
const VALID_ICON_OK := "res://icons/code-json-check-positive.png"
const VALID_ICON_BAD := "res://icons/code-json-check-negative.png"
var _validate_timer: Timer

func _get_fine_tune_node():
	if not is_inside_tree():
		return null
	var tree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("FineTune")

func _request_schemas_refresh() -> void:
	var ft_node = _get_fine_tune_node()
	if ft_node != null and ft_node.has_method("update_schemas_internal"):
		ft_node.update_schemas_internal()

func _ready() -> void:
	var tab_bar = $MarginContainer2/SchemasTabContainer.get_tab_bar()
	tab_bar.set_tab_title(0, tr("Edit JSON"))
	tab_bar.set_tab_title(1, tr("OpenAI JSON"))
	_validate_timer = Timer.new()
	_validate_timer.one_shot = true
	_validate_timer.wait_time = 0.5
	add_child(_validate_timer)
	_validate_timer.connect("timeout", Callable(self, "_on_validate_timeout"))

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
	_validate_timer.start()

func _on_validate_timeout() -> void:
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
	_set_edit_pending()
	var res = JsonSchemaValidator.validate_schema(json.data)
	if not res["ok"]:
		_set_edit_result(false, JSON.stringify(res["errors"]))
		return
	_set_edit_result(true)
	var sanitized = SchemaAlignOpenAI.sanitize_envelope_or_schema(json.data)
	var oai_text = JSON.stringify(sanitized, "      ")
	oai_editor.text = oai_text
	var json2 := JSON.new()
	if json2.parse(oai_text) != OK:
		_set_oai_result(false, "Invalid JSON")
		return
	var pending_schema = null
	if json2.data is Dictionary:
		pending_schema = json2.data.get("schema", null)
	if pending_schema is Dictionary:
		_set_oai_pending()
		var res2 = JsonSchemaValidator.validate_schema(pending_schema)
		if res2["ok"]:
			_set_oai_result(true)
		else:
			_set_oai_result(false, JSON.stringify(res2["errors"]))
	else:
		_set_oai_result(false, "Missing schema")
	if not _updating_from_name and json.data is Dictionary and json.data.has("title"):
		var title = json.data["title"]
		if title is String:
			name_edit.text = title
	_request_schemas_refresh()

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
