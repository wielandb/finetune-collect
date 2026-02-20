extends BoxContainer

const SchemaAlignOpenAI = preload("res://scenes/schemas/schema_align_openai.gd")
const JsonSchemaValidator = preload("res://json_schema_validator.gd")
const SchemaRefResolver = preload("res://scenes/schema_runtime/schema_ref_resolver.gd")
const SchemaRemoteRefLoader = preload("res://scenes/schema_runtime/schema_remote_ref_loader.gd")
const DESKTOP_SCHEMA_TITLE_FONT_SIZE = 20
const COMPACT_SCHEMA_TITLE_FONT_SIZE = 18

var _updating_from_name = false
var _last_resolved_schema = null
var _last_external_errors = []
var _validation_serial = 0
var _compact_layout_enabled = false

const VALID_ICON_OK = "res://icons/code-json-check-positive.png"
const VALID_ICON_BAD = "res://icons/code-json-check-negative.png"
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

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	vertical = enabled
	$MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer.vertical = enabled
	$MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2.vertical = enabled
	$MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer.vertical = enabled
	if enabled:
		$MarginContainer/JSONSchemaControlsContainer/TitleLabel.add_theme_font_size_override("font_size", COMPACT_SCHEMA_TITLE_FONT_SIZE)
		$MarginContainer.add_theme_constant_override("margin_left", 8)
		$MarginContainer.add_theme_constant_override("margin_top", 8)
		$MarginContainer.add_theme_constant_override("margin_right", 8)
		$MarginContainer2.add_theme_constant_override("margin_top", 8)
		$MarginContainer2.add_theme_constant_override("margin_right", 8)
		$MarginContainer2.add_theme_constant_override("margin_bottom", 8)
	else:
		$MarginContainer/JSONSchemaControlsContainer/TitleLabel.add_theme_font_size_override("font_size", DESKTOP_SCHEMA_TITLE_FONT_SIZE)
		$MarginContainer.add_theme_constant_override("margin_left", 20)
		$MarginContainer.add_theme_constant_override("margin_top", 25)
		$MarginContainer.add_theme_constant_override("margin_right", 15)
		$MarginContainer2.add_theme_constant_override("margin_top", 45)
		$MarginContainer2.add_theme_constant_override("margin_right", 40)
		$MarginContainer2.add_theme_constant_override("margin_bottom", 25)

func _ready() -> void:
	var tab_bar = $MarginContainer2/SchemasTabContainer.get_tab_bar()
	tab_bar.set_tab_title(0, tr("Edit JSON"))
	tab_bar.set_tab_title(1, tr("OpenAI JSON"))
	_configure_error_label($MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel)
	_configure_error_label($MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel)
	_validate_timer = Timer.new()
	_validate_timer.one_shot = true
	_validate_timer.wait_time = 0.5
	add_child(_validate_timer)
	_validate_timer.connect("timeout", Callable(self, "_on_validate_timeout"))
	var ft_node = _get_fine_tune_node()
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func _configure_error_label(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

func _set_edit_pending() -> void:
	var c = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer
	c.get_node("Spinner").visible = true
	c.get_node("SchemaValidateTextureRect").visible = false
	$MarginContainer/JSONSchemaControlsContainer/SchemaErrorLabel.visible = false

func _set_edit_result(ok: bool, msg: String = "") -> void:
	var c = $MarginContainer/JSONSchemaControlsContainer/ValidatedSchemaContainer
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
	var c = $MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2
	c.get_node("Spinner").visible = true
	c.get_node("SchemaValidateTextureRect").visible = false
	$MarginContainer/JSONSchemaControlsContainer/OAISchemaErrorLabel.visible = false

func _set_oai_result(ok: bool, msg: String = "") -> void:
	var c = $MarginContainer/JSONSchemaControlsContainer/OAIValidatedSchemaContainer2
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

func _on_delete_schema_button_mouse_entered() -> void:
	if $MarginContainer/JSONSchemaControlsContainer/DeleteSchemaButton.disabled:
		return
	$MarginContainer/JSONSchemaControlsContainer/DeleteSchemaButton.icon = load("res://icons/trashcanOpen_small.png")

func _on_delete_schema_button_mouse_exited() -> void:
	if $MarginContainer/JSONSchemaControlsContainer/DeleteSchemaButton.disabled:
		return
	$MarginContainer/JSONSchemaControlsContainer/DeleteSchemaButton.icon = load("res://icons/trashcan_small.png")

func _on_edit_json_schema_code_edit_text_changed() -> void:
	_validate_timer.start()

func _on_validate_timeout() -> void:
	_validation_serial += 1
	var serial = _validation_serial
	var editor = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor = $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name_edit = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
	oai_editor.text = ""
	_set_oai_result(false)
	var json = JSON.new()
	var err = json.parse(editor.text)
	if err != OK:
		_last_resolved_schema = null
		_last_external_errors = []
		_set_edit_result(false, "Invalid JSON")
		return
	if not (json.data is Dictionary):
		_last_resolved_schema = null
		_last_external_errors = []
		_set_edit_result(false, "Schema must be a JSON object")
		return
	_set_edit_pending()
	var resolve_result = await _resolve_schema_with_external(json.data)
	if serial != _validation_serial:
		return
	var resolved_schema = resolve_result.get("schema", json.data)
	if not (resolved_schema is Dictionary):
		resolved_schema = json.data
	_last_resolved_schema = resolved_schema
	_last_external_errors = resolve_result.get("external_errors", [])
	var res = JsonSchemaValidator.validate_schema(resolved_schema)
	if not res["ok"]:
		var schema_error_text = _format_error_messages(res["errors"])
		var external_error_text = _format_external_errors(_last_external_errors)
		if external_error_text != "":
			schema_error_text += "\n" + external_error_text
		_set_edit_result(false, schema_error_text)
		return
	if bool(resolve_result.get("has_external_ref", false)):
		var unresolved_external_error = _format_external_errors(_last_external_errors)
		if unresolved_external_error == "":
			unresolved_external_error = "External schema reference could not be resolved"
		_set_edit_result(false, unresolved_external_error)
		return
	_set_edit_result(true)
	var conversion_report = SchemaAlignOpenAI.sanitize_envelope_or_schema_with_report(resolved_schema)
	var sanitized = conversion_report.get("result", {})
	var oai_text = JSON.stringify(sanitized, "      ")
	oai_editor.text = oai_text
	var json2 = JSON.new()
	if json2.parse(oai_text) != OK:
		_set_oai_result(false, "Invalid JSON")
		return
	var pending_schema = null
	if json2.data is Dictionary:
		pending_schema = json2.data.get("schema", null)
	var conversion_ok = bool(conversion_report.get("ok", false))
	var conversion_errors = conversion_report.get("errors", [])
	if pending_schema is Dictionary:
		_set_oai_pending()
		if not conversion_ok:
			_set_oai_result(false, _format_error_messages(conversion_errors))
			return
		var res2 = JsonSchemaValidator.validate_schema(pending_schema)
		if res2["ok"]:
			_set_oai_result(true)
		else:
			_set_oai_result(false, _format_error_messages(res2["errors"]))
	else:
		if not conversion_ok:
			_set_oai_result(false, _format_error_messages(conversion_errors))
		else:
			_set_oai_result(false, "Missing schema")
	if not _updating_from_name and json.data is Dictionary and json.data.has("title"):
		var title = json.data["title"]
		if title is String:
			if name_edit.text != title and not name_edit.has_focus():
				name_edit.text = title
	_request_schemas_refresh()

func _resolve_schema_with_external(schema: Dictionary) -> Dictionary:
	if SchemaRefResolver.has_external_document_ref(schema):
		return await SchemaRemoteRefLoader.resolve_schema_with_remote(self, schema)
	return SchemaRefResolver.resolve_schema(schema)

func _format_external_errors(errors: Array) -> String:
	if errors.is_empty():
		return ""
	var lines = []
	for entry in errors:
		if entry is Dictionary:
			var url = str(entry.get("url", "")).strip_edges()
			var message = str(entry.get("message", "")).strip_edges()
			if url != "":
				lines.append(url + ": " + message)
			elif message != "":
				lines.append(message)
		else:
			lines.append(str(entry))
	return "\n".join(lines)

func _format_error_messages(raw_errors) -> String:
	if raw_errors is Array:
		var lines = []
		for entry in raw_errors:
			if entry is Dictionary:
				var path = str(entry.get("path", "")).strip_edges()
				var code = str(entry.get("code", "")).strip_edges()
				var message = str(entry.get("message", "")).strip_edges()
				var prefix_parts = []
				if path != "":
					prefix_parts.append(path)
				if code != "":
					prefix_parts.append(code)
				var prefix = ""
				if not prefix_parts.is_empty():
					prefix = "[" + " | ".join(prefix_parts) + "] "
				if message != "":
					lines.append(prefix + message)
				else:
					lines.append(prefix + JSON.stringify(entry))
			else:
				lines.append(str(entry))
		if not lines.is_empty():
			return "\n".join(lines)
	if raw_errors is Dictionary:
		return JSON.stringify(raw_errors, "\t")
	return str(raw_errors)

func _on_schema_name_line_edit_text_changed(new_text: String) -> void:
	var editor = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var json = JSON.new()
	var err = json.parse(editor.text)
	if err != OK or not (json.data is Dictionary):
		return
	_updating_from_name = true
	json.data["title"] = new_text
	editor.text = JSON.stringify(json.data, "	")
	_updating_from_name = false
	_on_edit_json_schema_code_edit_text_changed()
	get_node("/root/FineTune").update_schemas_internal()

func to_var():
	var editor = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor = $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit.text
	var json = JSON.new()
	var schema = null
	if json.parse(editor.text) == OK:
		schema = json.data
	var json2 = JSON.new()
	var sanitized_schema = null
	if json2.parse(oai_editor.text) == OK and json2.data is Dictionary:
		var dat = json2.data
		sanitized_schema = dat.get("schema", dat)
		if name == "" and dat.has("name") and dat["name"] is String:
			name = dat["name"]
	var resolved_schema = null
	if _last_resolved_schema is Dictionary:
		resolved_schema = _last_resolved_schema
	elif schema is Dictionary:
		resolved_schema = SchemaRefResolver.resolve_schema(schema).get("schema", schema)
	return {
		"schema": schema,
		"resolvedSchema": resolved_schema,
		"sanitizedSchema": sanitized_schema,
		"name": name,
		"externalSchemaErrors": _last_external_errors.duplicate(true)
	}

func from_var(data):
	var editor = $MarginContainer2/SchemasTabContainer/EditSchemaTabBar/VBoxContainer/EditJSONSchemaCodeEdit
	var oai_editor = $MarginContainer2/SchemasTabContainer/OAISchemaTabBar/VBoxContainer/OAIJSONSchemaCodeEdit
	var name_edit = $MarginContainer/JSONSchemaControlsContainer/SchemaNameContainer/LineEdit
	var schema = data.get("schema", null)
	var resolved_schema = data.get("resolvedSchema", null)
	var sanitized_schema = data.get("sanitizedSchema", null)
	var external_errors = data.get("externalSchemaErrors", [])
	var name = data.get("name", "")
	if schema != null:
		editor.text = JSON.stringify(schema, "\t")
	else:
		editor.text = ""
	if resolved_schema is Dictionary:
		_last_resolved_schema = resolved_schema
	elif schema is Dictionary:
		_last_resolved_schema = schema
	else:
		_last_resolved_schema = null
	if external_errors is Array:
		_last_external_errors = external_errors.duplicate(true)
	else:
		_last_external_errors = []
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
