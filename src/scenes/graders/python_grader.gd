extends VBoxContainer

const DESKTOP_EDITOR_MARGIN_LEFT = 50
const DESKTOP_EDITOR_MARGIN_RIGHT = 50
const COMPACT_EDITOR_MARGIN_LEFT = 12
const COMPACT_EDITOR_MARGIN_RIGHT = 12
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	if enabled:
		$MarginContainer.add_theme_constant_override("margin_left", COMPACT_EDITOR_MARGIN_LEFT)
		$MarginContainer.add_theme_constant_override("margin_right", COMPACT_EDITOR_MARGIN_RIGHT)
	else:
		$MarginContainer.add_theme_constant_override("margin_left", DESKTOP_EDITOR_MARGIN_LEFT)
		$MarginContainer.add_theme_constant_override("margin_right", DESKTOP_EDITOR_MARGIN_RIGHT)
	if $NameContainer.has_method("set_compact_layout"):
		$NameContainer.set_compact_layout(enabled)

func _ready() -> void:
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func to_var():
	var me = {}
	me["name"] = $NameContainer.grader_name
	me["image_tag"] = "2025-05-08"
	me["type"] = "python"
	me["source"] = $MarginContainer/PythonEdit.text
	return me
	
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$MarginContainer/PythonEdit.text = grader_data.get("source", "")

func is_form_ready() -> bool:
	return $NameContainer.grader_name != "" and $MarginContainer/PythonEdit.text != ""
