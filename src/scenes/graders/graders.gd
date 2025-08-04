extends ScrollContainer

@onready var GRADER_SCENE = preload("res://scenes/graders/grader_container.tscn")
@onready var COPYABLE_SCENE = preload("res://scenes/graders/copy_able_data_container.tscn")

func _ready():
	var container = $GradersListContainer/SampleItemsContainer
	container/SampleItemTextEdit.text_changed.connect(_update_copyable_data)
	container/SampleModelOutputEdit.text_changed.connect(_update_copyable_data)
	_update_copyable_data()

func _on_add_grader_button_pressed() -> void:
	var inst = GRADER_SCENE.instantiate()
	$GradersListContainer.add_child(inst)
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
	var btn_index = $GradersListContainer.get_children().find($GradersListContainer/AddGraderButton)
	$GradersListContainer.move_child(inst, btn_index)

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
	$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
	if graders_data is Array:
		for g in graders_data:
			var inst = GRADER_SCENE.instantiate()
			$GradersListContainer.add_child(inst)
			$GradersListContainer.move_child($GradersListContainer/SampleItemsContainer, -1)
			var btn_index = $GradersListContainer.get_children().find($GradersListContainer/AddGraderButton)
			$GradersListContainer.move_child(inst, btn_index)
			if inst.has_method("from_var"):
				inst.from_var(g)

func _update_copyable_data():
	var container = $GradersListContainer/SampleItemsContainer
	while container.get_child_count() > 4:
		container.get_child(4).queue_free()
	var item_paths = []
	var item_text = container/SampleItemTextEdit.text
	var json = JSON.new()
	if json.parse(item_text) == OK:
		_collect_paths("item", json.data, item_paths)
	var model_paths = ["{{ sample.output_text }}"]
	json = JSON.new()
	var model_text = container/SampleModelOutputEdit.text
	if json.parse(model_text) == OK:
		_collect_paths("sample.output_json", json.data, model_paths)
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
