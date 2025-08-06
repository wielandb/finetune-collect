extends SceneTree

class GraderStub:
	extends Node
	signal run_completed(response)
	signal validation_completed(response)
	var last_item = null
	func run_grader(grader, model_sample, item):
		last_item = item
	func validate_grader(grader):
		pass

class OpenAiStub:
	extends Node
	var grader_stub := GraderStub.new()
	func create_grader():
		return grader_stub
	func get_api():
		return ""

func _init():
	call_deferred("_run")

func _run():
	var fineTune = Node.new()
	fineTune.name = "FineTune"
	var openai_stub = OpenAiStub.new()
	fineTune.add_child(openai_stub)
	get_root().add_child(fineTune)

	var scene = load("res://scenes/graders/graders_list.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0).timeout

	scene._on_add_grader_button_pressed()
	var graders_container = scene.get_node("GradersListContainer")
	var gc = null
	for child in graders_container.get_children():
		if child.name != "AddGraderButton" and child.name != "SampleItemsContainer":
			gc = child
			break

	scene.get_node("GradersListContainer/SampleItemsContainer/SampleItemTextEdit").text = '{"reference_answer": "fuzzy wuzzy was a bear"}'
	scene.get_node("GradersListContainer/SampleItemsContainer/SampleModelOutputEdit").text = 'fuzzy wuzzy was a bear'
	gc._last_grader_data = {"type": "string_check"}

	gc._on_grader_validation_completed({})
	var wrapped = openai_stub.grader_stub.last_item
	assert(wrapped.get("reference_json", {}).get("reference_answer", "") == "fuzzy wuzzy was a bear")
	print("Grader wraps item reference_json")
	quit(0)
