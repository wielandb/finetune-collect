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
	item_edit.text = '{"reference_answer": "...", "moreData": {"a": "Test", "b": "Test"}}'
	model_edit.text = '{"reference_answer": "...", "moreData": {"a": "Test", "b": "Test"}}'
	scene._update_copyable_data()
	var datas = []
	for i in range(4, container.get_child_count()):
		datas.append(container.get_child(i).dataStr)
	assert(datas == [
		"{{ item.reference_answer }}",
		"{{ sample.output_text }}",
		"{{ item.moreData.a }}",
		"{{ sample.output_json.reference_answer }}",
		"{{ item.moreData.b }}",
		"{{ sample.output_json.moreData.a }}",
		"",
		"{{ sample.output_json.moreData.b }}"
	])
	print("Copyable data generated")
	quit(0)
