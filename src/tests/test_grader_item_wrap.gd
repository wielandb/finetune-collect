extends SceneTree

class GraderStub:
	extends "res://addons/openai_api/Scripts/Grader.gd"
	var last_item = null
	func run_grader(grader: Dictionary, model_sample, item = null, url: String = ""):
		last_item = item
	func validate_grader(grader: Dictionary, url: String = ""):
		pass

class OpenAiStub:
	extends Node
	signal gpt_response_completed(message, response)
	signal models_received(models)
	var grader_stub := GraderStub.new()
	func create_grader():
		return grader_stub
	func get_api():
		return ""
	func get_models():
		pass

class MessageStub:
	extends Node
	func to_rft_reference_item():
		return {"reference_answer": "fuzzy wuzzy was a bear", "ideal_function_call_data": [], "do_function_call": false}
	func to_model_output_sample():
		return {"output_tools": [], "output_text": "fuzzy wuzzy was a bear"}
	func to_var():
		return {"type": "Text"}

func _init():
	call_deferred("_run")

func _run():
	var fineTune = Node.new()
	fineTune.name = "FineTune"
	var openai_stub = OpenAiStub.new()
	openai_stub.name = "OpenAi"
	fineTune.add_child(openai_stub)
	var conversation = Node.new()
	conversation.name = "Conversation"
	var messages = Node.new()
	messages.name = "Messages"
	var messages_list = Node.new()
	messages_list.name = "MessagesList"
	var messages_container = Node.new()
	messages_container.name = "MessagesListContainer"
	messages_list.add_child(messages_container)
	messages.add_child(messages_list)
	var graders = Node.new()
	graders.name = "Graders"
	var graders_list = load("res://scenes/graders/graders_list.tscn").instantiate()
	graders_list.name = "GradersList"
	graders.add_child(graders_list)
	conversation.add_child(messages)
	conversation.add_child(graders)
	fineTune.add_child(conversation)
	get_root().add_child(fineTune)
	await create_timer(0).timeout
	var msg = MessageStub.new()
	messages_container.add_child(msg)
	graders_list.update_from_last_message()
	graders_list._on_add_grader_button_pressed()
	var graders_container = graders_list.get_node("GradersListContainer")
	var gc = null
	for child in graders_container.get_children():
		if child.name != "AddGraderButton" and child.name != "SampleItemsContainer":
			gc = child
			break
	gc._last_grader_data = {"type": "string_check"}
	gc._on_grader_validation_completed({})
	var wrapped = openai_stub.grader_stub.last_item
	assert(wrapped.get("reference_answer", "") == "fuzzy wuzzy was a bear")
	print("Grader wraps item reference answer")
	quit(0)
