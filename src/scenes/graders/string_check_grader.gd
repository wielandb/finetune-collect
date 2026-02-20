extends VBoxContainer

const DESKTOP_GRID_COLUMNS = 3
const COMPACT_GRID_COLUMNS = 1
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	if enabled:
		$GridContainer.columns = COMPACT_GRID_COLUMNS
	else:
		$GridContainer.columns = DESKTOP_GRID_COLUMNS
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
	me["type"] = "string_check"
	me["name"] = $NameContainer.grader_name
	me["input"] = $GridContainer/InputEdit.text
	me["reference"] = $GridContainer/ReferenceEdit.text
	me["operation"] = $GridContainer/OperationOptionButton.get_item_text($GridContainer/OperationOptionButton.selected)
	return me

func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$GridContainer/InputEdit.text = grader_data.get("input", "")
	$GridContainer/ReferenceEdit.text = grader_data.get("reference")
	$GridContainer/OperationOptionButton.select(0)
	var operation = grader_data.get("operation", "eq")
	for i in range($GridContainer/OperationOptionButton.item_count):
		if $GridContainer/OperationOptionButton.get_item_text(i) == operation:
			$GridContainer/OperationOptionButton.select(i)
			break

func is_form_ready() -> bool:
	return (
		$NameContainer.grader_name != "" and
		$GridContainer/InputEdit.text != "" and
		$GridContainer/ReferenceEdit.text != "" and
		$GridContainer/OperationOptionButton.selected >= 0
	)
