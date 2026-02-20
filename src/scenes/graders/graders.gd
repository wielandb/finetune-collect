extends ScrollContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")
@onready var COPYABLE_SCENE = preload("res://scenes/graders/copy_able_data_container.tscn")
const DESKTOP_SAMPLE_COLUMNS = 2
const COMPACT_SAMPLE_COLUMNS = 1
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	var sample_container = get_node_or_null("GradersListContainer/SampleItemsContainer")
	if sample_container is GridContainer:
		if enabled:
			sample_container.columns = COMPACT_SAMPLE_COLUMNS
		else:
			sample_container.columns = DESKTOP_SAMPLE_COLUMNS
	for child in $GradersListContainer.get_children():
		if child.name in ["AddGraderButton", "SampleItemsContainer"]:
			continue
		if child.has_method("set_compact_layout"):
			child.set_compact_layout(enabled)

func _ready():
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var container = $GradersListContainer/SampleItemsContainer
	var item_edit = container.get_node("SampleItemTextEdit")
	var model_edit = container.get_node("SampleModelOutputEdit")
	item_edit.text_changed.connect(_update_copyable_data)
	model_edit.text_changed.connect(_update_copyable_data)
	var tab_container = get_parent().get_parent()
	if tab_container and tab_container.has_signal("tab_changed"):
		tab_container.connect("tab_changed", Callable(self, "_on_tab_changed"))
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)
	update_from_last_message()
	_update_copyable_data()

func _on_tab_changed(tab):
	update_from_last_message()

func update_from_last_message():
	var messages_container = get_tree().get_root().get_node_or_null("FineTune/Conversation/Messages/MessagesList/MessagesListContainer")
	if not messages_container:
		print("Not messages container")
		return
	if messages_container.get_child_count() == 0:
		print("Not child count")
		return
	var last_msg = null
	for mix in messages_container.get_child_count():
		var this_msg = messages_container.get_child(mix)
		if this_msg.has_method("to_rft_reference_item"):
			last_msg = this_msg
	if last_msg == null:
		return
	var ref_item = last_msg.to_rft_reference_item()
	var sample = last_msg.to_model_output_sample()
	var container = $GradersListContainer/SampleItemsContainer
	container.get_node("SampleItemTextEdit").text = JSON.stringify(ref_item)
	container.get_node("SampleModelOutputEdit").text = JSON.stringify(sample)
	_update_copyable_data()
	var last_type = last_msg.to_var().get("type", "")
	if last_type == "Function Call":
		return
	for child in $GradersListContainer.get_children():
		if child.name in ["AddGraderButton", "SampleItemsContainer"]:
			continue
		if child.has_method("verify_grader"):
			child.verify_grader()

func _on_add_grader_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$GradersListContainer.add_child(inst)
	if inst.has_method("set_compact_layout"):
		inst.set_compact_layout(_compact_layout_enabled)
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, 0)
	$GradersListContainer.move_child($GradersListContainer/AddGraderButton, 1)

func to_var():
	var all = []
	for child in $GradersListContainer.get_children():
		if child.name == "AddGraderButton" or child.name == "SampleItemsContainer":
			continue
		if child.has_method("to_var"):
			all.append(child.to_var())
	return all

func from_var(graders_data):
	for child in $GradersListContainer.get_children():
		if child.name != "AddGraderButton" and child.name != "SampleItemsContainer":
			child.queue_free()
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, 0)
	$GradersListContainer.move_child($GradersListContainer/AddGraderButton, 1)
	if graders_data is Array:
		for g in graders_data:
			var inst = GRADER_SCENE.instantiate()
			$GradersListContainer.add_child(inst)
			if inst.has_method("set_compact_layout"):
				inst.set_compact_layout(_compact_layout_enabled)
			if inst.has_method("from_var"):
				inst.from_var(g)

func _update_copyable_data():
	var container = $GradersListContainer/SampleItemsContainer
	var last_static_index = container.get_node("SampleModelOutputEdit").get_index()
	for i in range(container.get_child_count() - 1, last_static_index, -1):
		container.get_child(i).queue_free()
	var item_paths = []
	var item_text = container.get_node("SampleItemTextEdit").text
	var json = JSON.new()
	if json.parse(item_text) == OK:
		_collect_paths("item", json.data, item_paths)
	var model_paths = ["{{ sample.output_text }}"]
	json = JSON.new()
	var model_text = container.get_node("SampleModelOutputEdit").text
	if json.parse(model_text) == OK:
		var sample_data = json.data
		var out_json = sample_data.get("output_json")
		if out_json is Dictionary or out_json is Array:
			model_paths.append("{{ sample.output_json }}")
			_collect_paths("sample.output_json", out_json, model_paths)
		var out_tools = sample_data.get("output_tools")
		if out_tools is Array:
			model_paths.append("{{ sample.output_tools }}")
			_collect_paths("sample.output_tools", out_tools, model_paths)
	var max_len = max(item_paths.size(), model_paths.size())
	for i in range(max_len):
		var item_inst = COPYABLE_SCENE.instantiate()
		if i < item_paths.size():
			item_inst.dataStr = item_paths[i]
			item_inst.copyable = true
		else:
			item_inst.dataStr = ""
			item_inst.copyable = false
		container.add_child(item_inst)
		var model_inst = COPYABLE_SCENE.instantiate()
		if i < model_paths.size():
			model_inst.dataStr = model_paths[i]
			model_inst.copyable = true
		else:
			model_inst.dataStr = ""
			model_inst.copyable = false
		container.add_child(model_inst)

func _collect_paths(prefix, value, paths):
	if value is Dictionary:
		for k in value.keys():
			_collect_paths(prefix + "." + str(k), value[k], paths)
	elif value is Array:
		for i in range(value.size()):
			_collect_paths(prefix + "[" + str(i) + "]", value[i], paths)
	else:
		paths.append("{{ %s }}" % prefix)
