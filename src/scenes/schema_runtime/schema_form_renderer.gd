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
const DATE_PICKER_DOUBLE_CLICK_WINDOW_MS = 350
const DATE_PICKER_WEEKDAY_HEADER_KEYS = [
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_MON",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_TUE",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_WED",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_THU",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_FRI",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_SAT",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_HEADER_SUN"
]
const DATE_PICKER_WEEKDAY_SHORT_KEYS = [
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_MON",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_TUE",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_WED",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_THU",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_FRI",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_SAT",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_SHORT_SUN"
]
const DATE_PICKER_WEEKDAY_LONG_KEYS = [
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_MON",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_TUE",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_WED",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_THU",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_FRI",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_SAT",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_WEEKDAY_LONG_SUN"
]
const DATE_PICKER_MONTH_LONG_KEYS = [
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_JAN",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_FEB",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_MAR",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_APR",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_MAY",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_JUN",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_JUL",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_AUG",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_SEP",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_OCT",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_NOV",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LONG_DEC"
]
const DATE_PICKER_MONTH_SHORT_KEYS = [
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_JAN",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_FEB",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_MAR",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_APR",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_MAY",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_JUN",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_JUL",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_AUG",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_SEP",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_OCT",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_NOV",
	"MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_SHORT_DEC"
]
const DELETE_ICON_CLOSED_SMALL = "res://icons/trashcan_small.png"
const DELETE_ICON_OPEN_SMALL = "res://icons/trashcanOpen_small.png"
const INFO_ICON_SMALL = "res://icons/help-circle-outline-custom.png"
const FILTERABLE_OPTION_THRESHOLD = 10
const FILTERABLE_OPTION_FILTER_LINE_EDIT_NAME = "OptionFilterLineEdit"
const OPTION_SELECTOR_FONT_SIZE = 11

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
	var use_include_toggle = bool(descriptor.get("null_branch_optional", false))
	if use_include_toggle:
		null_toggle.text = tr("MESSAGES_JSON_SCHEMA_FORM_INCLUDE")
	else:
		null_toggle.text = tr("MESSAGES_JSON_SCHEMA_FORM_USE_NULL")
	null_toggle.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth))
	null_toggle.add_theme_font_override("font", _get_bold_font())
	_style_single_line_button(null_toggle)
	wrapper.add_child(null_toggle)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	wrapper.add_child(body)
	var current_value = controller.get_value_at_path(path)
	if use_include_toggle:
		var is_included = current_value != null
		null_toggle.button_pressed = is_included
		body.visible = is_included
		null_toggle.toggled.connect(controller._on_nullable_include_toggled.bind(path.duplicate(true), descriptor))
	else:
		var is_null_value = current_value == null
		null_toggle.button_pressed = is_null_value
		body.visible = not is_null_value
		null_toggle.toggled.connect(controller._on_nullable_toggled.bind(path.duplicate(true), descriptor))
	if body.visible:
		var desc_no_null = descriptor.duplicate(true)
		desc_no_null["nullable"] = false
		var content_depth = depth + 1
		if use_include_toggle:
			content_depth = depth
		_render_non_nullable_node(desc_no_null, body, controller, path, content_depth)

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
				"reason": tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_REASON_UNKNOWN_KIND").replace("{kind}", kind)
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
		_style_wrapping_label(empty_label)
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
		prop_label.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
		prop_label.add_theme_font_override("font", _get_bold_font())
		_style_single_line_label(prop_label)
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
			_style_single_line_button(include_checkbox)
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
	if _is_compact_string_enum_array(descriptor):
		_render_compact_string_enum_array_rows(box, controller, path, depth, descriptor, array_value, items)
	elif _is_key_value_pair_array(descriptor):
		_render_key_value_array_rows(box, controller, path, depth, descriptor, array_value, items)
	else:
		for i in range(array_value.size()):
			var row = _array_item_row_scene.instantiate()
			box.add_child(row)
			row.set_index(i)
			var row_label = row.get_node_or_null("Header/ItemLabel")
			if row_label is Label:
				row_label.add_theme_font_override("font", _get_bold_font())
				row_label.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
				_style_single_line_label(row_label)
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
	_style_single_line_button(add_button)
	box.add_child(add_button)
	var max_items = int(descriptor.get("max_items", -1))
	if max_items >= 0 and array_value.size() >= max_items:
		add_button.disabled = true
	add_button.pressed.connect(controller._on_array_item_add_requested.bind(path.duplicate(true), descriptor))

func _render_compact_string_enum_array_rows(parent: VBoxContainer, controller, path: Array, depth: int, descriptor: Dictionary, array_value: Array, items_descriptor: Dictionary) -> void:
	var enum_values = items_descriptor.get("enum_values", [])
	var labels = []
	for enum_value in enum_values:
		labels.append(str(enum_value))
	for i in range(array_value.size()):
		var row = HBoxContainer.new()
		row.name = "CompactStringEnumRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)

		var info_hint = _create_compact_info_hint(items_descriptor)
		if info_hint != null:
			row.add_child(info_hint)

		var selector_holder = VBoxContainer.new()
		selector_holder.name = "CompactSelectorHolder"
		selector_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector_holder.add_theme_constant_override("separation", 4)
		row.add_child(selector_holder)

		var current = controller.get_value_at_path(path + [i])
		var selected_index = -1
		for value_index in range(enum_values.size()):
			if JSON.stringify(enum_values[value_index]) == JSON.stringify(current):
				selected_index = value_index
				break
		if selected_index == -1 and enum_values.size() > 0:
			selected_index = 0
			controller.set_value_at_path(path + [i], enum_values[0], false)

		_build_option_selector(
			selector_holder,
			labels,
			selected_index,
			controller._on_enum_item_selected.bind(path.duplicate(true) + [i], items_descriptor)
		)

		var delete_button = Button.new()
		delete_button.name = "DeleteButton"
		delete_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DELETE_ITEM")
		delete_button.icon = load(DELETE_ICON_CLOSED_SMALL)
		delete_button.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
		_style_single_line_button(delete_button)
		delete_button.pressed.connect(func() -> void:
			controller._on_array_item_delete_requested(i, path.duplicate(true), i, descriptor)
		)
		delete_button.mouse_entered.connect(_on_delete_button_mouse_entered.bind(delete_button))
		delete_button.mouse_exited.connect(_on_delete_button_mouse_exited.bind(delete_button))
		var min_items = int(descriptor.get("min_items", 0))
		if i < min_items:
			delete_button.disabled = true
		row.add_child(delete_button)

		if i < array_value.size() - 1:
			_add_divider(parent)

func _create_compact_info_hint(item_descriptor: Dictionary) -> TextureRect:
	var title_text = str(item_descriptor.get("title", "")).strip_edges()
	var description_text = str(item_descriptor.get("description", "")).strip_edges()
	var tooltip_parts = []
	if title_text != "":
		tooltip_parts.append(title_text)
	if description_text != "":
		tooltip_parts.append(description_text)
	if tooltip_parts.is_empty():
		return null
	var info_hint = TextureRect.new()
	info_hint.name = "InfoHint"
	info_hint.tooltip_text = "\n\n".join(tooltip_parts)
	info_hint.texture = load(INFO_ICON_SMALL)
	info_hint.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	info_hint.custom_minimum_size = Vector2(24, 24)
	return info_hint

func _render_key_value_array_rows(parent: VBoxContainer, controller, path: Array, depth: int, descriptor: Dictionary, array_value: Array, items_descriptor: Dictionary) -> void:
	var key_descriptor = _get_object_property_descriptor(items_descriptor, "key")
	var value_descriptor = _get_object_property_descriptor(items_descriptor, "value")
	for i in range(array_value.size()):
		var row = VBoxContainer.new()
		row.name = "KeyValueItemRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		var fields_row = HBoxContainer.new()
		fields_row.name = "KeyValueFields"
		fields_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fields_row.add_theme_constant_override("separation", 8)
		row.add_child(fields_row)

		fields_row.add_child(_render_key_value_cell("key", key_descriptor, controller, path + [i, "key"], depth + 1))
		fields_row.add_child(_render_key_value_cell("value", value_descriptor, controller, path + [i, "value"], depth + 1))

		var actions_row = HBoxContainer.new()
		actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_row.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(actions_row)
		var delete_button = Button.new()
		delete_button.name = "DeleteButton"
		delete_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DELETE_ITEM")
		delete_button.icon = load(DELETE_ICON_CLOSED_SMALL)
		delete_button.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
		_style_single_line_button(delete_button)
		delete_button.pressed.connect(controller._on_array_item_delete_requested.bind(-1, path.duplicate(true), i, descriptor))
		delete_button.mouse_entered.connect(_on_delete_button_mouse_entered.bind(delete_button))
		delete_button.mouse_exited.connect(_on_delete_button_mouse_exited.bind(delete_button))
		var min_items = int(descriptor.get("min_items", 0))
		if i < min_items:
			delete_button.disabled = true
		actions_row.add_child(delete_button)
		if i < array_value.size() - 1:
			_add_divider(parent)

func _on_delete_button_mouse_entered(button: Button) -> void:
	if button.disabled:
		return
	button.icon = load(DELETE_ICON_OPEN_SMALL)

func _on_delete_button_mouse_exited(button: Button) -> void:
	if button.disabled:
		return
	button.icon = load(DELETE_ICON_CLOSED_SMALL)

func _build_option_selector(parent: Control, labels: Array, selected_index: int, on_selected: Callable) -> OptionButton:
	var choice = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.set_fit_to_longest_item(false)
	choice.set_clip_text(true)
	choice.set_text_overrun_behavior(TextServer.OVERRUN_TRIM_ELLIPSIS)
	choice.add_theme_font_size_override("font_size", OPTION_SELECTOR_FONT_SIZE)
	choice.get_popup().add_theme_font_size_override("font_size", OPTION_SELECTOR_FONT_SIZE)
	var state = {
		"labels": labels.duplicate(),
		"selected_index": selected_index
	}
	if labels.size() > FILTERABLE_OPTION_THRESHOLD:
		var selector_box = VBoxContainer.new()
		selector_box.name = "FilterableOptionSelector"
		selector_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector_box.add_theme_constant_override("separation", 4)
		parent.add_child(selector_box)
		var filter_input = LineEdit.new()
		filter_input.name = FILTERABLE_OPTION_FILTER_LINE_EDIT_NAME
		filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter_input.placeholder_text = tr("MESSAGES_JSON_SCHEMA_FORM_OPTION_FILTER_PLACEHOLDER")
		selector_box.add_child(filter_input)
		selector_box.add_child(choice)
		filter_input.text_changed.connect(_on_option_filter_text_changed.bind(choice, state, on_selected))
	else:
		parent.add_child(choice)
	_populate_option_selector(choice, state, "")
	choice.item_selected.connect(_on_option_selector_item_selected.bind(choice, state, on_selected))
	return choice

func _populate_option_selector(choice: OptionButton, state: Dictionary, filter_text: String) -> int:
	choice.clear()
	var labels = state.get("labels", [])
	if not (labels is Array):
		return -1
	var normalized_filter = filter_text.strip_edges().to_lower()
	var selected_original_index = int(state.get("selected_index", -1))
	var selected_visible_index = -1
	var visible_index = 0
	for i in range(labels.size()):
		var label_text = str(labels[i])
		if normalized_filter != "" and label_text.to_lower().find(normalized_filter) == -1:
			continue
		choice.add_item(label_text, i)
		choice.set_item_tooltip(visible_index, label_text)
		if i == selected_original_index:
			selected_visible_index = visible_index
		visible_index += 1
	if selected_visible_index != -1:
		choice.select(selected_visible_index)
		state["selected_index"] = choice.get_item_id(selected_visible_index)
		return choice.get_item_id(selected_visible_index)
	elif choice.item_count > 0:
		choice.select(0)
		state["selected_index"] = choice.get_item_id(0)
		return choice.get_item_id(0)
	else:
		choice.select(-1)
		state["selected_index"] = -1
		return -1

func _on_option_filter_text_changed(new_text: String, choice: OptionButton, state: Dictionary, on_selected: Callable) -> void:
	var previous_selected_index = int(state.get("selected_index", -1))
	var selected_original_index = _populate_option_selector(choice, state, new_text)
	if selected_original_index == -1 or selected_original_index == previous_selected_index:
		return
	if not on_selected.is_valid():
		return
	on_selected.call(selected_original_index)

func _on_option_selector_item_selected(index: int, choice: OptionButton, state: Dictionary, on_selected: Callable) -> void:
	if index < 0 or index >= choice.item_count:
		return
	var original_index = choice.get_item_id(index)
	state["selected_index"] = original_index
	if not on_selected.is_valid():
		return
	on_selected.call(original_index)

func _render_key_value_cell(field_name: String, field_descriptor: Dictionary, controller, path: Array, depth: int) -> VBoxContainer:
	var cell = VBoxContainer.new()
	cell.name = field_name.capitalize() + "Cell"
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	var kind = str(field_descriptor.get("kind", ""))
	if kind == "enum":
		var values = field_descriptor.get("enum_values", [])
		var current = controller.get_value_at_path(path)
		var selected_index = -1
		var labels = []
		for i in range(values.size()):
			var enum_value = values[i]
			labels.append(str(enum_value))
			if JSON.stringify(enum_value) == JSON.stringify(current):
				selected_index = i
		if selected_index == -1 and values.size() > 0:
			selected_index = 0
			controller.set_value_at_path(path, values[0], false)
		_build_option_selector(
			cell,
			labels,
			selected_index,
			controller._on_enum_item_selected.bind(path.duplicate(true), field_descriptor)
		)
	else:
		var line_edit = LineEdit.new()
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.placeholder_text = field_name
		var value = controller.get_value_at_path(path)
		if value is String:
			line_edit.text = value
		else:
			line_edit.text = str(controller.create_default_value(field_descriptor))
		cell.add_child(line_edit)
		line_edit.text_changed.connect(controller._on_string_value_changed.bind(path.duplicate(true), field_descriptor))
	_add_key_value_cell_info(cell, field_name, field_descriptor, depth)
	return cell

func _add_key_value_cell_info(cell: VBoxContainer, field_name: String, field_descriptor: Dictionary, depth: int) -> void:
	var title_text = str(field_descriptor.get("title", "")).strip_edges()
	if title_text == "":
		title_text = field_name
	var description_text = str(field_descriptor.get("description", "")).strip_edges()
	var info_box = VBoxContainer.new()
	info_box.name = field_name.capitalize() + "Info"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	cell.add_child(info_box)
	var title_label = Label.new()
	title_label.add_theme_font_override("font", _get_bold_font())
	title_label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth))
	title_label.text = title_text
	_style_wrapping_label(title_label)
	info_box.add_child(title_label)
	if description_text != "":
		var description_label = Label.new()
		_style_wrapping_label(description_label)
		description_label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth))
		description_label.text = description_text
		info_box.add_child(description_label)

func _is_key_value_pair_array(descriptor: Dictionary) -> bool:
	if str(descriptor.get("kind", "")) != "array":
		return false
	var items_descriptor = descriptor.get("items", {})
	if not (items_descriptor is Dictionary):
		return false
	if str(items_descriptor.get("kind", "")) != "object":
		return false
	var key_descriptor = _get_object_property_descriptor(items_descriptor, "key")
	var value_descriptor = _get_object_property_descriptor(items_descriptor, "value")
	if key_descriptor.is_empty() or value_descriptor.is_empty():
		return false
	return _is_supported_key_value_field(key_descriptor) and _is_supported_key_value_field(value_descriptor)

func _is_compact_string_enum_array(descriptor: Dictionary) -> bool:
	if str(descriptor.get("kind", "")) != "array":
		return false
	var items_descriptor = descriptor.get("items", {})
	if not (items_descriptor is Dictionary):
		return false
	if bool(items_descriptor.get("nullable", false)):
		return false
	if str(items_descriptor.get("kind", "")) != "enum":
		return false
	return _is_string_enum_descriptor(items_descriptor)

func _get_object_property_descriptor(object_descriptor: Dictionary, property_name: String) -> Dictionary:
	var property_entry = _get_object_property_entry(object_descriptor, property_name)
	if property_entry.is_empty():
		return {}
	var descriptor = property_entry.get("descriptor", {})
	if descriptor is Dictionary:
		return descriptor
	return {}

func _get_object_property_entry(object_descriptor: Dictionary, property_name: String) -> Dictionary:
	var properties = object_descriptor.get("properties", [])
	if not (properties is Array):
		return {}
	for property_data in properties:
		if not (property_data is Dictionary):
			continue
		if str(property_data.get("name", "")) == property_name:
			return property_data
	return {}

func _is_supported_key_value_field(field_descriptor: Dictionary) -> bool:
	if bool(field_descriptor.get("nullable", false)):
		return false
	var kind = str(field_descriptor.get("kind", ""))
	if kind == "string":
		return true
	if kind == "enum":
		return _is_string_enum_descriptor(field_descriptor)
	return false

func _is_string_enum_descriptor(field_descriptor: Dictionary) -> bool:
	var values = field_descriptor.get("enum_values", [])
	if not (values is Array):
		return false
	for value in values:
		if not (value is String):
			return false
	return true

func _render_string_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var format_name = str(descriptor.get("format", "")).strip_edges()
	if format_name == "date":
		_render_date_string_input(descriptor, box, controller, path, depth)
		return
	var line_edit = LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value = controller.get_value_at_path(path)
	if value is String:
		line_edit.text = value
	else:
		line_edit.text = str(controller.create_default_value(descriptor))
	box.add_child(line_edit)
	line_edit.text_changed.connect(controller._on_string_value_changed.bind(path.duplicate(true), descriptor))

func _render_date_string_input(descriptor: Dictionary, box: VBoxContainer, controller, path: Array, depth: int) -> void:
	var row = HBoxContainer.new()
	row.name = "DateInputRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var line_edit = LineEdit.new()
	line_edit.name = "DateLineEdit"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.placeholder_text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_PLACEHOLDER")
	var value = controller.get_value_at_path(path)
	if value is String:
		line_edit.text = value
	else:
		line_edit.text = str(controller.create_default_value(descriptor))
	row.add_child(line_edit)
	line_edit.text_changed.connect(controller._on_string_value_changed.bind(path.duplicate(true), descriptor))

	var picker_button = Button.new()
	picker_button.name = "DatePickerButton"
	picker_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_OPEN")
	picker_button.add_theme_font_override("font", _get_bold_font())
	picker_button.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
	_style_single_line_button(picker_button)
	row.add_child(picker_button)

	var clear_button = Button.new()
	clear_button.name = "DateClearButton"
	clear_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_CLEAR")
	clear_button.add_theme_font_override("font", _get_bold_font())
	clear_button.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
	_style_single_line_button(clear_button)
	row.add_child(clear_button)

	var picker_dialog = AcceptDialog.new()
	picker_dialog.name = "DatePickerDialog"
	picker_dialog.title = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_DIALOG_TITLE")
	picker_dialog.unresizable = true
	picker_dialog.get_ok_button().hide()
	box.add_child(picker_dialog)

	var dialog_layout = VBoxContainer.new()
	dialog_layout.name = "DatePickerLayout"
	dialog_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_layout.add_theme_constant_override("separation", 10)
	picker_dialog.add_child(dialog_layout)

	var header_panel = PanelContainer.new()
	header_panel.name = "DatePickerHeaderPanel"
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_layout.add_child(header_panel)

	var header_padding = MarginContainer.new()
	header_padding.add_theme_constant_override("margin_left", 14)
	header_padding.add_theme_constant_override("margin_right", 14)
	header_padding.add_theme_constant_override("margin_top", 14)
	header_padding.add_theme_constant_override("margin_bottom", 14)
	header_panel.add_child(header_padding)

	var header_box = VBoxContainer.new()
	header_box.name = "DatePickerHeaderBox"
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_constant_override("separation", 4)
	header_padding.add_child(header_box)

	var header_year_label = Label.new()
	header_year_label.name = "DatePickerHeaderYearLabel"
	header_year_label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	header_box.add_child(header_year_label)

	var header_date_label = Label.new()
	header_date_label.name = "DatePickerHeaderDateLabel"
	header_date_label.add_theme_font_override("font", _get_bold_font())
	header_date_label.add_theme_font_size_override("font_size", _title_font_size_for_depth(depth))
	header_box.add_child(header_date_label)

	var navigation_row = HBoxContainer.new()
	navigation_row.name = "DatePickerNavigationRow"
	navigation_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_row.add_theme_constant_override("separation", 6)
	dialog_layout.add_child(navigation_row)

	var prev_month_button = Button.new()
	prev_month_button.name = "DatePickerPrevMonthButton"
	prev_month_button.text = "<"
	prev_month_button.custom_minimum_size = Vector2(32, 0)
	navigation_row.add_child(prev_month_button)

	var month_label = Label.new()
	month_label.name = "DatePickerMonthLabel"
	month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.add_theme_font_override("font", _get_bold_font())
	month_label.add_theme_font_size_override("font_size", _field_font_size_for_depth(depth + 1))
	navigation_row.add_child(month_label)

	var next_month_button = Button.new()
	next_month_button.name = "DatePickerNextMonthButton"
	next_month_button.text = ">"
	next_month_button.custom_minimum_size = Vector2(32, 0)
	navigation_row.add_child(next_month_button)

	var calendar_grid = GridContainer.new()
	calendar_grid.name = "DatePickerCalendarGrid"
	calendar_grid.columns = 7
	calendar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_grid.add_theme_constant_override("h_separation", 2)
	calendar_grid.add_theme_constant_override("v_separation", 2)
	dialog_layout.add_child(calendar_grid)

	var actions_row = HBoxContainer.new()
	actions_row.name = "DatePickerActionsRow"
	actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_theme_constant_override("separation", 6)
	dialog_layout.add_child(actions_row)

	var dialog_clear_button = Button.new()
	dialog_clear_button.name = "DatePickerDialogClearButton"
	dialog_clear_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_DIALOG_ACTION_CLEAR")
	dialog_clear_button.flat = true
	dialog_clear_button.add_theme_font_override("font", _get_bold_font())
	_style_single_line_button(dialog_clear_button)
	actions_row.add_child(dialog_clear_button)

	var cancel_button = Button.new()
	cancel_button.name = "DatePickerCancelButton"
	cancel_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_DIALOG_ACTION_CANCEL")
	cancel_button.flat = true
	cancel_button.add_theme_font_override("font", _get_bold_font())
	_style_single_line_button(cancel_button)
	actions_row.add_child(cancel_button)

	var set_button = Button.new()
	set_button.name = "DatePickerSetButton"
	set_button.text = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_DIALOG_ACTION_SET")
	set_button.flat = true
	set_button.add_theme_font_override("font", _get_bold_font())
	_style_single_line_button(set_button)
	actions_row.add_child(set_button)

	picker_dialog.set_meta("date_line_edit", line_edit)
	picker_dialog.set_meta("date_controller", controller)
	picker_dialog.set_meta("date_path", path.duplicate(true))
	picker_dialog.set_meta("date_descriptor", descriptor.duplicate(true))
	picker_dialog.set_meta("date_click_key", "")
	picker_dialog.set_meta("date_click_timestamp", -DATE_PICKER_DOUBLE_CLICK_WINDOW_MS)

	var today = Time.get_datetime_dict_from_system()
	_set_date_picker_state(
		picker_dialog,
		int(today.get("year", 2000)),
		int(today.get("month", 1)),
		int(today.get("day", 1))
	)
	_refresh_date_picker_calendar(picker_dialog)

	clear_button.pressed.connect(_on_date_clear_pressed.bind(line_edit, controller, path.duplicate(true), descriptor))
	picker_button.pressed.connect(_on_date_picker_open_pressed.bind(picker_dialog, line_edit))
	prev_month_button.pressed.connect(_on_date_picker_prev_month_pressed.bind(picker_dialog))
	next_month_button.pressed.connect(_on_date_picker_next_month_pressed.bind(picker_dialog))
	dialog_clear_button.pressed.connect(_on_date_picker_dialog_clear_pressed.bind(picker_dialog))
	cancel_button.pressed.connect(_on_date_picker_dialog_cancel_pressed.bind(picker_dialog))
	set_button.pressed.connect(_on_date_picker_dialog_set_pressed.bind(picker_dialog))

func _on_date_clear_pressed(line_edit: LineEdit, controller, path: Array, descriptor: Dictionary) -> void:
	line_edit.text = ""
	controller._on_string_value_changed("", path, descriptor)

func _popup_dialog_fit_to_viewport(dialog: Window, preferred_size: Vector2i) -> void:
	var viewport_size = Vector2.ZERO
	var viewport = dialog.get_viewport()
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		var native_size = DisplayServer.window_get_size()
		viewport_size = Vector2(native_size.x, native_size.y)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		dialog.popup_centered(preferred_size)
		return
	var side_margin = 24
	var vertical_margin = 24
	var max_width = maxi(220, int(viewport_size.x) - side_margin)
	var max_height = maxi(180, int(viewport_size.y) - vertical_margin)
	var target_size = Vector2i(
		mini(preferred_size.x, max_width),
		mini(preferred_size.y, max_height)
	)
	dialog.popup_centered(target_size)

func _on_date_picker_open_pressed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
	var parsed = _parse_iso_date_string(line_edit.text)
	if bool(parsed.get("ok", false)):
		_set_date_picker_state(
			dialog,
			int(parsed.get("year", 2000)),
			int(parsed.get("month", 1)),
			int(parsed.get("day", 1))
		)
	else:
		var today = Time.get_datetime_dict_from_system()
		_set_date_picker_state(
			dialog,
			int(today.get("year", 2000)),
			int(today.get("month", 1)),
			int(today.get("day", 1))
		)
	dialog.set_meta("date_click_key", "")
	dialog.set_meta("date_click_timestamp", -DATE_PICKER_DOUBLE_CLICK_WINDOW_MS)
	_refresh_date_picker_calendar(dialog)
	_popup_dialog_fit_to_viewport(dialog, Vector2i(360, 430))

func _on_date_picker_dialog_clear_pressed(dialog: AcceptDialog) -> void:
	var line_edit = dialog.get_meta("date_line_edit", null)
	var controller = dialog.get_meta("date_controller", null)
	var path = dialog.get_meta("date_path", [])
	var descriptor = dialog.get_meta("date_descriptor", {})
	if line_edit is LineEdit:
		line_edit.text = ""
	if controller != null and controller.has_method("_on_string_value_changed"):
		controller._on_string_value_changed("", path, descriptor)
	dialog.hide()

func _on_date_picker_dialog_cancel_pressed(dialog: AcceptDialog) -> void:
	dialog.hide()

func _on_date_picker_dialog_set_pressed(dialog: AcceptDialog) -> void:
	_apply_date_picker_selection_from_dialog(dialog, true)

func _on_date_picker_prev_month_pressed(dialog: AcceptDialog) -> void:
	var year = int(dialog.get_meta("calendar_year", 2000))
	var month = int(dialog.get_meta("calendar_month", 1)) - 1
	var day = int(dialog.get_meta("calendar_day", 1))
	if month < 1:
		month = 12
		year -= 1
	_set_date_picker_state(dialog, year, month, day)
	dialog.set_meta("date_click_key", "")
	dialog.set_meta("date_click_timestamp", -DATE_PICKER_DOUBLE_CLICK_WINDOW_MS)
	_refresh_date_picker_calendar(dialog)

func _on_date_picker_next_month_pressed(dialog: AcceptDialog) -> void:
	var year = int(dialog.get_meta("calendar_year", 2000))
	var month = int(dialog.get_meta("calendar_month", 1)) + 1
	var day = int(dialog.get_meta("calendar_day", 1))
	if month > 12:
		month = 1
		year += 1
	_set_date_picker_state(dialog, year, month, day)
	dialog.set_meta("date_click_key", "")
	dialog.set_meta("date_click_timestamp", -DATE_PICKER_DOUBLE_CLICK_WINDOW_MS)
	_refresh_date_picker_calendar(dialog)

func _on_date_picker_day_pressed(day: int, month_offset: int, dialog: AcceptDialog) -> void:
	var year = int(dialog.get_meta("calendar_year", 2000))
	var month = int(dialog.get_meta("calendar_month", 1)) + month_offset
	while month < 1:
		month += 12
		year -= 1
	while month > 12:
		month -= 12
		year += 1
	_set_date_picker_state(dialog, year, month, day)
	_refresh_date_picker_calendar(dialog)
	_handle_date_picker_click_shortcut(dialog, year, month, day)

func _handle_date_picker_click_shortcut(dialog: AcceptDialog, year: int, month: int, day: int) -> void:
	var click_key = _format_iso_date_string(year, month, day)
	var now = Time.get_ticks_msec()
	var previous_key = str(dialog.get_meta("date_click_key", ""))
	var previous_time = int(dialog.get_meta("date_click_timestamp", -DATE_PICKER_DOUBLE_CLICK_WINDOW_MS))
	dialog.set_meta("date_click_key", click_key)
	dialog.set_meta("date_click_timestamp", now)
	if click_key == previous_key and now - previous_time <= DATE_PICKER_DOUBLE_CLICK_WINDOW_MS:
		_apply_date_picker_selection_from_dialog(dialog, true)

func _apply_date_picker_selection_from_dialog(dialog: AcceptDialog, close_dialog: bool) -> void:
	var line_edit = dialog.get_meta("date_line_edit", null)
	if not (line_edit is LineEdit):
		if close_dialog:
			dialog.hide()
		return
	var controller = dialog.get_meta("date_controller", null)
	var path = dialog.get_meta("date_path", [])
	var descriptor = dialog.get_meta("date_descriptor", {})
	var year = int(dialog.get_meta("calendar_year", 2000))
	var month = int(dialog.get_meta("calendar_month", 1))
	var day = int(dialog.get_meta("calendar_day", 1))
	var selected_date = _format_iso_date_string(year, month, day)
	line_edit.text = selected_date
	if controller != null and controller.has_method("_on_string_value_changed"):
		controller._on_string_value_changed(selected_date, path, descriptor)
	if close_dialog:
		dialog.hide()

func _set_date_picker_state(dialog: AcceptDialog, year: int, month: int, day: int) -> void:
	if year < 1:
		year = 1
	elif year > 9999:
		year = 9999
	while month < 1:
		month += 12
		year -= 1
	while month > 12:
		month -= 12
		year += 1
	if year < 1:
		year = 1
	elif year > 9999:
		year = 9999
	var max_days = _days_in_month(year, month)
	if day < 1:
		day = 1
	elif day > max_days:
		day = max_days
	dialog.set_meta("calendar_year", year)
	dialog.set_meta("calendar_month", month)
	dialog.set_meta("calendar_day", day)

func _refresh_date_picker_calendar(dialog: AcceptDialog) -> void:
	var header_year_label = dialog.find_child("DatePickerHeaderYearLabel", true, false)
	var header_date_label = dialog.find_child("DatePickerHeaderDateLabel", true, false)
	var month_label = dialog.find_child("DatePickerMonthLabel", true, false)
	var calendar_grid = dialog.find_child("DatePickerCalendarGrid", true, false)
	if not (header_year_label is Label) or not (header_date_label is Label) or not (month_label is Label) or not (calendar_grid is GridContainer):
		return
	var year = int(dialog.get_meta("calendar_year", 2000))
	var month = int(dialog.get_meta("calendar_month", 1))
	var day = int(dialog.get_meta("calendar_day", 1))
	var max_days = _days_in_month(year, month)
	if day > max_days:
		day = max_days
		dialog.set_meta("calendar_day", day)
	header_year_label.text = str(year)
	header_date_label.text = _format_date_picker_header_label(year, month, day)
	month_label.text = _format_date_picker_month_label(year, month)
	var existing_children = calendar_grid.get_children()
	for child in existing_children:
		calendar_grid.remove_child(child)
		child.queue_free()

	var weekday_color = _date_picker_weekday_font_color(dialog)
	for weekday_index in range(7):
		var weekday_label = Label.new()
		weekday_label.name = "DatePickerWeekdayLabel_" + str(weekday_index)
		weekday_label.custom_minimum_size = Vector2(44, 22)
		weekday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weekday_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weekday_label.add_theme_font_override("font", _get_bold_font())
		weekday_label.text = _get_date_picker_weekday_header(weekday_index)
		weekday_label.modulate = weekday_color
		calendar_grid.add_child(weekday_label)

	var regular_color = _date_picker_base_font_color(dialog)
	var adjacent_color = _date_picker_adjacent_font_color(dialog)
	var first_weekday = _weekday_index_monday_first(year, month, 1)
	var prev_month = month - 1
	var prev_year = year
	if prev_month < 1:
		prev_month = 12
		prev_year -= 1
	var prev_month_days = _days_in_month(prev_year, prev_month)

	for i in range(first_weekday):
		var leading_day = prev_month_days - first_weekday + i + 1
		var leading_button = Button.new()
		leading_button.name = "DateOtherMonthDayButtonPrev_" + str(leading_day)
		leading_button.text = str(leading_day)
		leading_button.custom_minimum_size = Vector2(44, 34)
		leading_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leading_button.flat = true
		leading_button.add_theme_color_override("font_color", adjacent_color)
		leading_button.add_theme_color_override("font_hover_color", adjacent_color)
		leading_button.add_theme_color_override("font_pressed_color", adjacent_color)
		leading_button.add_theme_color_override("font_focus_color", adjacent_color)
		leading_button.pressed.connect(_on_date_picker_day_pressed.bind(leading_day, -1, dialog))
		calendar_grid.add_child(leading_button)

	for day_value in range(1, max_days + 1):
		var day_button = Button.new()
		day_button.name = "DateDayButton_" + str(day_value)
		day_button.text = str(day_value)
		day_button.custom_minimum_size = Vector2(44, 34)
		day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day_button.toggle_mode = true
		day_button.button_pressed = day_value == day
		day_button.flat = false
		day_button.add_theme_color_override("font_color", regular_color)
		day_button.add_theme_color_override("font_hover_color", regular_color)
		day_button.add_theme_color_override("font_pressed_color", regular_color)
		day_button.add_theme_color_override("font_focus_color", regular_color)
		if day_value == day:
			day_button.add_theme_font_override("font", _get_bold_font())
		day_button.pressed.connect(_on_date_picker_day_pressed.bind(day_value, 0, dialog))
		calendar_grid.add_child(day_button)

	var used_cells = first_weekday + max_days
	var remaining_cells = used_cells % 7
	if remaining_cells != 0:
		var trailing_day = 1
		for i in range(7 - remaining_cells):
			var trailing_button = Button.new()
			trailing_button.name = "DateOtherMonthDayButtonNext_" + str(trailing_day)
			trailing_button.text = str(trailing_day)
			trailing_button.custom_minimum_size = Vector2(44, 34)
			trailing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trailing_button.flat = true
			trailing_button.add_theme_color_override("font_color", adjacent_color)
			trailing_button.add_theme_color_override("font_hover_color", adjacent_color)
			trailing_button.add_theme_color_override("font_pressed_color", adjacent_color)
			trailing_button.add_theme_color_override("font_focus_color", adjacent_color)
			trailing_button.pressed.connect(_on_date_picker_day_pressed.bind(trailing_day, 1, dialog))
			calendar_grid.add_child(trailing_button)
			trailing_day += 1

func _format_date_picker_month_label(year: int, month: int) -> String:
	var month_name = _get_date_picker_month_name(month)
	var out = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_MONTH_LABEL_PATTERN")
	out = out.replace("{month}", month_name)
	out = out.replace("{year}", str(year))
	return out

func _format_date_picker_header_label(year: int, month: int, day: int) -> String:
	var weekday_name = _get_date_picker_weekday_long(_weekday_index_monday_first(year, month, day))
	var month_name = _get_date_picker_month_name(month)
	var out = tr("MESSAGES_JSON_SCHEMA_FORM_DATE_HEADER_LABEL_PATTERN")
	out = out.replace("{weekday}", weekday_name)
	out = out.replace("{day}", str(day))
	out = out.replace("{month}", month_name)
	return out

func _get_date_picker_weekday_header(index: int) -> String:
	if index < 0 or index >= DATE_PICKER_WEEKDAY_HEADER_KEYS.size():
		return ""
	return tr(DATE_PICKER_WEEKDAY_HEADER_KEYS[index])

func _get_date_picker_month_name(month: int) -> String:
	var index = month - 1
	if index < 0 or index >= DATE_PICKER_MONTH_LONG_KEYS.size():
		return ""
	return tr(DATE_PICKER_MONTH_LONG_KEYS[index])

func _get_date_picker_month_short_name(month: int) -> String:
	var index = month - 1
	if index < 0 or index >= DATE_PICKER_MONTH_SHORT_KEYS.size():
		return ""
	return tr(DATE_PICKER_MONTH_SHORT_KEYS[index])

func _get_date_picker_weekday_short(index: int) -> String:
	if index < 0 or index >= DATE_PICKER_WEEKDAY_SHORT_KEYS.size():
		return ""
	return tr(DATE_PICKER_WEEKDAY_SHORT_KEYS[index])

func _get_date_picker_weekday_long(index: int) -> String:
	if index < 0 or index >= DATE_PICKER_WEEKDAY_LONG_KEYS.size():
		return ""
	return tr(DATE_PICKER_WEEKDAY_LONG_KEYS[index])

func _date_picker_base_font_color(dialog) -> Color:
	return dialog.get_theme_color("font_color", "Label")

func _date_picker_weekday_font_color(dialog) -> Color:
	var color = _date_picker_base_font_color(dialog)
	color.a = color.a * 0.72
	return color

func _date_picker_adjacent_font_color(dialog) -> Color:
	var color = _date_picker_base_font_color(dialog)
	color.a = color.a * 0.5
	return color
func _weekday_index_monday_first(year: int, month: int, day: int) -> int:
	var adjusted_year = year
	var adjusted_month = month
	if adjusted_month < 3:
		adjusted_month += 12
		adjusted_year -= 1
	var k = adjusted_year % 100
	var j = int(adjusted_year / 100)
	var h = int(day + int((13 * (adjusted_month + 1)) / 5) + k + int(k / 4) + int(j / 4) + (5 * j)) % 7
	var mapping = [5, 6, 0, 1, 2, 3, 4]
	return mapping[h]

func _parse_iso_date_string(value: String) -> Dictionary:
	var text = value.strip_edges()
	if text.length() != 10:
		return {"ok": false}
	if text.substr(4, 1) != "-" or text.substr(7, 1) != "-":
		return {"ok": false}
	var year_text = text.substr(0, 4)
	var month_text = text.substr(5, 2)
	var day_text = text.substr(8, 2)
	if not _is_ascii_digit_string(year_text) or not _is_ascii_digit_string(month_text) or not _is_ascii_digit_string(day_text):
		return {"ok": false}
	var year = int(year_text)
	var month = int(month_text)
	var day = int(day_text)
	if year < 1 or year > 9999:
		return {"ok": false}
	if month < 1 or month > 12:
		return {"ok": false}
	var max_days = _days_in_month(year, month)
	if day < 1 or day > max_days:
		return {"ok": false}
	return {
		"ok": true,
		"year": year,
		"month": month,
		"day": day
	}

func _is_ascii_digit_string(value: String) -> bool:
	if value == "":
		return false
	for i in range(value.length()):
		var code = value.unicode_at(i)
		if code < 48 or code > 57:
			return false
	return true

func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if _is_leap_year(year):
				return 29
			return 28
		_:
			return 31

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

func _format_iso_date_string(year: int, month: int, day: int) -> String:
	return _zero_pad_number(year, 4) + "-" + _zero_pad_number(month, 2) + "-" + _zero_pad_number(day, 2)

func _zero_pad_number(value: int, length: int) -> String:
	var text = str(value)
	while text.length() < length:
		text = "0" + text
	return text

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
	_style_single_line_button(check)
	var value = controller.get_value_at_path(path)
	check.button_pressed = bool(value)
	box.add_child(check)
	check.toggled.connect(controller._on_bool_value_toggled.bind(path.duplicate(true), descriptor))

func _render_enum_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var values = descriptor.get("enum_values", [])
	var current = controller.get_value_at_path(path)
	var selected_index = -1
	var labels = []
	for i in range(values.size()):
		var v = values[i]
		labels.append(str(v))
		if JSON.stringify(v) == JSON.stringify(current):
			selected_index = i
	if selected_index == -1 and values.size() > 0:
		selected_index = 0
		controller.set_value_at_path(path, values[0], false)
	_build_option_selector(
		box,
		labels,
		selected_index,
		controller._on_enum_item_selected.bind(path.duplicate(true), descriptor)
	)

func _render_const_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var label = Label.new()
	label.autowrap_mode = 2
	label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	label.text = tr("MESSAGES_JSON_SCHEMA_FORM_CONST_PREFIX") + JSON.stringify(descriptor.get("const_value", null))
	box.add_child(label)
	controller.set_value_at_path(path, descriptor.get("const_value", null), false)

func _render_null_node(descriptor: Dictionary, parent: Control, controller, path: Array, depth: int) -> void:
	var box = _create_level_box(parent, depth)
	_add_title_and_description(descriptor, box, depth)
	var label = Label.new()
	label.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	label.text = tr("MESSAGES_JSON_SCHEMA_FORM_NULL_LITERAL")
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
			"reason": tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_REASON_UNION_NO_BRANCHES")
		}, box, controller, path, depth + 1)
		return
	if branches.size() == 1:
		_render_node(branches[0], box, controller, path, depth)
		return
	var labels = []
	for i in range(branches.size()):
		var branch_title = str(branches[i].get("title", ""))
		if branch_title == "":
			branch_title = mode + " option " + str(i + 1)
		labels.append(branch_title)
	var active_index = controller.get_union_branch_index(path, descriptor)
	if active_index < 0 or active_index >= branches.size():
		active_index = 0
	_build_option_selector(
		box,
		labels,
		active_index,
		controller._on_union_branch_selected.bind(path.duplicate(true), descriptor)
	)
	var hint = Label.new()
	_style_wrapping_label(hint)
	hint.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth + 1))
	hint.text = tr("MESSAGES_JSON_SCHEMA_FORM_UNION_SWITCH_HINT")
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
		str(descriptor.get("reason", tr("MESSAGES_JSON_SCHEMA_FORM_FALLBACK_REASON_UNSUPPORTED_SECTION")))
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
		_style_wrapping_label(title_label)
		parent.add_child(title_label)
	if include_description and description != "":
		var desc_label = Label.new()
		_style_wrapping_label(desc_label)
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
		_style_wrapping_label(title)
	var description = editor.get_node_or_null("FallbackDescription")
	if description is Label:
		description.add_theme_font_size_override("font_size", _description_font_size_for_depth(depth))
		_style_wrapping_label(description)

func _style_wrapping_label(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _style_single_line_label(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_clip_text(true)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _style_single_line_button(button: Button) -> void:
	button.set_clip_text(true)
	button.set_text_overrun_behavior(TextServer.OVERRUN_TRIM_ELLIPSIS)

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
