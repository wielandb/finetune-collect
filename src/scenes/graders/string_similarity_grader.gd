extends VBoxContainer

var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	$InputContainer.vertical = enabled
	$ReferenceContainer.vertical = enabled
	$EvaluationMetricContainer.vertical = enabled
	if $NameContainer.has_method("set_compact_layout"):
		$NameContainer.set_compact_layout(enabled)

func _ready() -> void:
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$InputContainer/InputEdit.text = grader_data.get("input", "")
	$ReferenceContainer/ReferenceEdit.text = grader_data.get("reference", "")
	$EvaluationMetricContainer/EvaluationMetricOptionButton.select(-1)
	var metric = grader_data.get("evaluation_metric", "")
	for optix in range($EvaluationMetricContainer/EvaluationMetricOptionButton.item_count):
		if $EvaluationMetricContainer/EvaluationMetricOptionButton.get_item_text(optix) == metric:
			$EvaluationMetricContainer/EvaluationMetricOptionButton.select(optix)
			break

func to_var():
	var me = {}
	me["type"] = "text_similarity"
	me["name"] = $NameContainer.grader_name
	me["evaluation_metric"] = $EvaluationMetricContainer/EvaluationMetricOptionButton.get_item_text($EvaluationMetricContainer/EvaluationMetricOptionButton.selected)
	me["input"] = $InputContainer/InputEdit.text
	me["reference"] = $ReferenceContainer/ReferenceEdit.text
	return me

func is_form_ready() -> bool:
	return (
		$NameContainer.grader_name != "" and
		$InputContainer/InputEdit.text != "" and
		$ReferenceContainer/ReferenceEdit.text != "" and
		$EvaluationMetricContainer/EvaluationMetricOptionButton.selected >= 0
	)
