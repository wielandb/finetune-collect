extends RefCounted

class_name SchemaFormRenderer

const INDENT_PER_LEVEL = 12
const MAX_INDENT = 200
const TITLE_FONT_MAX = 22
const TITLE_FONT_MIN = 14
const FIELD_FONT_MAX = 17
const FIELD_FONT_MIN = 12
const DESCRIPTION_FONT_MAX = 15
const DESCRIPTION_FONT_MIN = 11

var _array_item_row_scene = preload("res://scenes/schema_runtime/widgets/schema_array_item_row.tscn")
var _fallback_scene = preload("res://scenes/schema_runtime/widgets/schema_fallback_editor.tscn")
var _ui_font = preload("res://assets/RobotoSlab-VariableFont_wght.ttf")
var _bold_font = null

func render(descriptor: Dictionary, parent: Control, controller, path: Array) -> void:
	_render_node(descriptor, parent, controller, path, 0)

func _render_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	if descriptor.get("nullable", false) and descriptor.get("kind", "") != "null":
		_render_nullable_node(descriptor, parent, controller, path, depth)
		return
	_render_non_nullable_node(descriptor, parent, controller, path, depth)

func _render_nullable_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var wrapper = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, wrapper, depth)
	var null_toggle = CheckBox.new()
	null_toggle.text = tr("MESSAGES_JSON_SCHEMA_FORM_USE_NULL")
	null_toggle.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth))
	null_toggle.add_theme_font_override("font", _get_bold_font())
	wrapper.add_child(null_toggle)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	wrapper.add_child(body)
	var current_value = controller.get_value_at_path(path)
	var is_null_value = current_value == null
	null_toggle.button_pressed = is_null_value
	body.visible = not is_null_value
	null_toggle.toggled.connect(controller._on_nullable_toggled.bind(path.duplicate(true), descriptor))
	if not is_null_value:
		var desc_no_null = descriptor.duplicate(true)
		desc_no_null["nullable"] = false
		_render_non_nullable_node(desc_no_null, body, controller, path, depth + 1)

func _render_non_nullable_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var kind = str(descriptor.get("kind", "fallback"))
	match kind:
		"object":
			_render_object_node(descriptor, parent, controller, path, depth)
		"array":
			_render_array_node(descriptor, parent, controller, path, depth)
		"string":
			_render_string_node(descriptor, parent, controller, path, depth)
		"number", "integer":
			_render_number_node(descriptor, parent, controller, path, depth)
		"boolean":
			_render_boolean_node(descriptor, parent, controller, path, depth)
		"enum":
			_render_enum_node(descriptor, parent, controller, path, depth)
		"const":
			_render_const_node(descriptor, parent, controller, path, depth)
		"null":
			_render_null_node(descriptor, parent, controller, path, depth)
		"union":
			_render_union_node(descriptor, parent, controller, path, depth)
		"fallback":
			_render_fallback_node(descriptor, parent, controller, path, depth)
		_:
			_render_fallback_node({
				"kind": "fallback",
				"title": descriptor.get("title", ""),
				"description": descriptor.get("description", ""),
				"reason": "Unknown descriptor kind: " + kind
			}, parent, controller, path, depth)

func _render_object_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var current_value = controller.get_value_at_path(path)
	if not (current_value is Dictionary):
		current_value = {}
	var properties = []
	for prop in descriptor.get("properties", []):
		if prop is Dictionary:
			properties.append(prop)
	if properties.is_empty():
		var empty_label = Label.new()
		empty_label.text = tr("MESSAGES_JSON_SCHEMA_FORM_NO_PROPERTIES")
		empty_label.autowrap_mode = 2
		empty_label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
		box.add_child(empty_label)
		return
	for i in range(properties.size()):
		var prop = properties[i]
		var prop_name = str(prop.get("name", ""))
		var prop_required = bool(prop.get("required", false))
		var prop_descriptor = prop.get("descriptor", {})
		var prop_line = VBoxContainer.new()
		prop_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_line.add_theme_constant_override("separation", 4)
		box.add_child(prop_line)
		var prop_header = HBoxContainer.new()
		prop_line.add_child(prop_header)
		var prop_label = Label.new()
		prop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_label.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
		prop_label.add_theme_font_override("font", _get_bold_font())
		var required_suffix = ""
		if prop_required:
			required_suffix = " *"
		prop_label.text = prop_name + required_suffix
		prop_header.add_child(prop_label)
		var content_holder = VBoxContainer.new()
		content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_line.add_child(content_holder)
		var has_value = current_value.has(prop_name)
		if prop_required and not has_value:
			controller.set_value_at_path(path + [prop_name], controller.create_default_value(prop_descriptor), false)
			has_value = true
		if not prop_required:
			var include_checkbox = CheckBox.new()
			include_checkbox.text = tr("MESSAGES_JSON_SCHEMA_FORM_INCLUDE")
			include_checkbox.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
			include_checkbox.button_pressed = has_value
			prop_header.add_child(include_checkbox)
			include_checkbox.toggled.connect(controller._on_optional_property_toggled.bind(path.duplicate(true), prop_name, prop_descriptor))
			content_holder.visible = include_checkbox.button_pressed
		else:
			content_holder.visible = true
		if content_holder.visible:
			_render_node(prop_descriptor, content_holder, controller, path + [prop_name], depth + 1)
		if i < properties.size() - 1:
			_add_divider(box)

func _render_array_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	controller._ensure_array_min_items(path, descriptor)
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var array_value = controller.get_value_at_path(path)
	if not (array_value is Array):
		array_value = []
	var items = descriptor.get("items", {})
	for i in range(array_value.size()):
		var row = _array_item_row_scene.instantiate()
		box.add_child(row)
		row.set_index(i)
		var row_label = row.get_node_or_null("Header/ItemLabel")
		if row_label is Label:
			row_label.add_theme_font_override("font", _get_bold_font())
			row_label.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
		row.delete_requested.connect(controller._on_array_item_delete_requested.bind(path.duplicate(true), i, descriptor))
		var min_items = int(descriptor.get("min_items", 0))
		if i < min_items:
			row.get_node("Header/DeleteButton").disabled = true
		var content_container = row.get_content_container()
		_render_node(items, content_container, controller, path + [i], depth + 1)
	var add_button = Button.new()
	add_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_ADD_ITEM")
	add_button.add_theme_font_override("font", _get_bold_font())
	add_button.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
	box.add_child(add_button)
	var max_items = int(descriptor.get("max_items", -1))
	if max_items >= 0 and array_value.size() >= max_items:
		add_button.disabled = true
	add_button.pressed.connect(controller._on_array_item_add_requested.bind(path.duplicate(true), descriptor))

func _render_string_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var line_edit = LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value = controller.get_value_at_path(path)
	if value is String:
		line_edit.text = value
	else:
		line_edit.text = str(controller.create_default_value(descriptor))
	box.add_child(line_edit)
	line_edit.text_changed.connect(controller._on_string_value_changed.bind(path.duplicate(true), descriptor))

func _render_number_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var spin = SpinBox.new()
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if descriptor.get("kind", "") == "integer":
		spin.step = 1.0
	else:
		spin.step = 0.1
	if descriptor.get("minimum", null) is int or descriptor.get("minimum", null) is float:
		spin.min_value = float(descriptor["minimum"])
	elif descriptor.get("exclusive_minimum", null) is int or descriptor.get("exclusive_minimum", null) is float:
		spin.min_value = float(descriptor["exclusive_minimum"]) + spin.step
	if descriptor.get("maximum", null) is int or descriptor.get("maximum", null) is float:
		spin.max_value = float(descriptor["maximum"])
	elif descriptor.get("exclusive_maximum", null) is int or descriptor.get("exclusive_maximum", null) is float:
		spin.max_value = float(descriptor["exclusive_maximum"]) - spin.step
	var value = controller.get_value_at_path(path)
	if value is int or value is float:
		spin.value = float(value)
	else:
		spin.value = float(controller.create_default_value(descriptor))
	box.add_child(spin)
	spin.value_changed.connect(controller._on_number_value_changed.bind(path.duplicate(true), descriptor))

func _render_boolean_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth, false)
	var check = CheckBox.new()
	var check_text = str(descriptor.get("description", "")).strip_edges()
	if check_text == "":
		check_text = str(descriptor.get("title", "")).strip_edges()
	check.text = check_text
	check.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
	var value = controller.get_value_at_path(path)
	check.button_pressed = bool(value)
	box.add_child(check)
	check.toggled.connect(controller._on_bool_value_toggled.bind(path.duplicate(true), descriptor))

func _render_enum_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var choice = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(choice)
	var values = descriptor.get("enum_values", [])
	var current = controller.get_value_at_path(path)
	var selected_index = -1
	for i in range(values.size()):
		var v = values[i]
		choice.add_item(str(v))
		if JSON.stringify(v) == JSON.stringify(current):
			selected_index = i
	if selected_index == -1 and values.size() > 0:
		selected_index = 0
		controller.set_value_at_path(path, values[0], false)
	if selected_index != -1:
		choice.select(selected_index)
	choice.item_selected.connect(controller._on_enum_item_selected.bind(path.duplicate(true), descriptor))

func _render_const_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var label = Label.new()
	label.autowrap_mode = 2
	label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	label.text = "const: " + JSON.stringify(descriptor.get("const_value", null))
	box.add_child(label)
	controller.set_value_at_path(path, descriptor.get("const_value", null), false)

func _render_null_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var label = Label.new()
	label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	label.text = "null"
	box.add_child(label)
	controller.set_value_at_path(path, null, false)

func _render_union_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var mode = str(descriptor.get("mode", "union"))
	var branches = descriptor.get("branches", [])
	if branches.size() == 0:
		_render_fallback_node({
			"kind": "fallback",
			"title": descriptor.get("title", ""),
			"description": descriptor.get("description", ""),
			"reason": "Union has no branches"
		}, box, controller, path, depth + 1)
		return
	var branch_choice = OptionButton.new()
	branch_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(branch_choice)
	for i in range(branches.size()):
		var branch_title = str(branches[i].get("title", ""))
		if branch_title == "":
			branch_title = mode + " option " + str(i + 1)
		branch_choice.add_item(branch_title)
	var active_index = controller.get_union_branch_index(path, descriptor)
	branch_choice.select(active_index)
	branch_choice.item_selected.connect(controller._on_union_branch_selected.bind(path.duplicate(true), descriptor))
	var hint = Label.new()
	hint.autowrap_mode = 2
	hint.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	hint.text = "Switching branch keeps compatible fields and resets incompatible values."
	box.add_child(hint)
	_add_divider(box)
	var branch_holder = VBoxContainer.new()
	branch_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(branch_holder)
	_render_node(branches[active_index], branch_holder, controller, path, depth + 1)

func _render_fallback_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	var editor = _fallback_scene.instantiate()
	box.add_child(editor)
	editor.configure(
		str(descriptor.get("title", "")),
		str(descriptor.get("description", "")),
		str(descriptor.get("reason", "Unsupported schema section"))
	)
	_style_fallback_editor(editor, depth)
	editor.set_json_value(controller.get_value_at_path(path))
	editor.json_value_changed.connect(controller._on_fallback_json_value_changed.bind(path.duplicate(true), descriptor))
	editor.validity_changed.connect(controller._on_fallback_validity_changed.bind(path.duplicate(true), descriptor))

func _add_title_and_description(descriptor: Dictionary, parent: Control, depth: int, include_description: bool = true) -> void:
	var title = str(descriptor.get("title", ""))
	var description = str(descriptor.get("description", ""))
	if title != "":
		var title_label = Label.new()
		title_label.add_theme_font_size_override("font_size", _title_font_size_for_depth(depth))
		title_label.add_theme_font_override("font", _get_bold_font())
		title_label.text = title
		parent.add_child(title_label)
	if include_description and description != "":
		var desc_label = Label.new()
		desc_label.autowrap_mode = 2
		desc_label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth))
		desc_label.text = description
		parent.add_child(desc_label)

func _create_level_box(parent: Control, depth: int) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_indent = depth * INDENT_PER_LEVEL
	if left_indent > MAX_INDENT:
		left_indent = MAX_INDENT
	margin.add_theme_constant_override("margin_left", left_indent)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	parent.add_child(margin)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box

func _add_divider(parent: Control) -> void:
	var divider = HSeparator.new()
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(divider)

func _style_fallback_editor(editor: Node, depth: int) -> void:
	var title = editor.get_node_or_null("FallbackTitle")
	if title is Label:
		title.add_theme_font_override("font", _get_bold_font())
		title.add_theme_font_size_override("font_size", _title_font_size_for_depth(depth))
	var description = editor.get_node_or_null("FallbackDescription")
	if description is Label:
		description.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth))

func _title_font_size_for_depth(depth: int) -> int:
	var size = TITLE_FONT_MAX - (depth * 2)
	if size < TITLE_FONT_MIN:
		size = TITLE_FONT_MIN
	return size

func _field_font_size_for_depth(depth: int) -> int:
	var size = FIELD_FONT_MAX - depth
	if size < FIELD_FONT_MIN:
		size = FIELD_FONT_MIN
	return size

func _description_font_size_for_depth(depth: int) -> int:
	var size = DESCRIPTION_FONT_MAX - depth
	if size < DESCRIPTION_FONT_MIN:
		size = DESCRIPTION_FONT_MIN
	return size

func _get_bold_font():
	if _bold_font != null:
		return _bold_font
	var variation = FontVariation.new()
	variation.base_font = _ui_font
	variation.variation_embolden = 0.8
	_bold_font = variation
	return _bold_font
