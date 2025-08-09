extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var scene = load("res://scenes/graders/graders_list.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0).timeout
	var container = scene.get_node("GradersListContainer/SampleItemsContainer")
	var item_edit = container.get_node("SampleItemTextEdit")
	var model_edit = container.get_node("SampleModelOutputEdit")
	item_edit.text = '{"do_function_call": false, "ideal_function_call_data": [], "reference_answer": "...", "moreData": {"a": "Test", "b": "Test"}}'
	model_edit.text = '{"output_text": "fuzzy", "output_json": {"reference_answer": "...", "moreData": {"a": "Test", "b": "Test"}}, "output_tools": [{"id": "call_0", "type": "function", "function": {"name": "foo"}}]}'
	scene._update_copyable_data()
	var datas = []
	for i in range(6, container.get_child_count()):
		datas.append(container.get_child(i).dataStr)
	assert(datas.has("{{ sample.output_text }}"))
	assert(datas.has("{{ sample.output_json }}"))
	assert(datas.has("{{ sample.output_json.reference_answer }}"))
	assert(datas.has("{{ sample.output_json.moreData.a }}"))
	assert(datas.has("{{ sample.output_json.moreData.b }}"))
	assert(datas.has("{{ sample.output_tools }}"))
	assert(datas.has("{{ sample.output_tools[0].function.name }}"))
	assert(datas.has("{{ item.reference_answer }}"))
	assert(datas.has("{{ item.moreData.a }}"))
	assert(datas.has("{{ item.moreData.b }}"))
	assert(datas.has("{{ item.do_function_call }}"))
	print("Copyable data generated")
	quit(0)
