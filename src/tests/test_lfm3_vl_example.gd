extends SceneTree

class OfflineModels:
	extends Models

	func get_available_models(_url: String = ""):
		pass

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var example_path = ProjectSettings.globalize_path("res://../examples/lfm3-vl-traffic-signs.json")
	var example_text = FileAccess.get_file_as_string(example_path)
	var project = JSON.parse_string(example_text)
	_check(project is Dictionary, "Example must be a JSON project")
	if not (project is Dictionary):
		quit(1)
		return

	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	# This import test does not need optional API model discovery.
	var offline_models = OfflineModels.new()
	scene.get_node("OpenAi").add_child(offline_models)
	scene.get_node("OpenAi").models = offline_models
	get_root().add_child(scene)
	await process_frame
	scene.load_from_json_data(example_text)
	await process_frame
	await process_frame
	_check(scene.CONVERSATION_ORDER == ["stop-demo", "tempo30-entwurf"], "Example conversation order")
	_check(scene.SCHEMAS.size() == 1, "Annotation schema is loaded")
	_check(scene.check_is_conversation_ready("stop-demo"), "STOP example is ready")
	_check(not scene.check_is_conversation_ready("tempo30-entwurf"), "Speed-limit example is a draft")
	_check(scene.SETTINGS.get("useGlobalSystemMessage", false), "Global system message is enabled")

	var schema = project["schemas"][0]["schema"]
	var list = scene.get_node("VBoxContainer/ConversationsList")
	for id in project["conversationOrder"]:
		for index in range(list.item_count):
			if list.get_item_tooltip(index) == id:
				scene._on_item_list_item_selected(index, false)
				break
		await process_frame
		await process_frame
		var image_found = false
		var annotation_found = false
		var messages = scene.get_node("Conversation/Messages/MessagesList/MessagesListContainer")
		for message in messages.get_children():
			if not message.is_in_group("message") or message.is_queued_for_deletion():
				continue
			var data = message.to_var()
			if data.get("type", "") == "Image":
				image_found = true
				var texture = message.get_node("ImageMessageContainer/TextureRect").texture
				_check(texture != null, "Embedded image is rendered for " + id)
			elif data.get("role", "") == "assistant" and data.get("type", "") == "JSON":
				annotation_found = true
				_check(data.get("jsonSchemaName", "") == project["schemas"][0]["name"], "Form schema remains selected")
				var expected = JSON.parse_string(project["conversations"][id][-1]["jsonSchemaValue"])
				var actual = JSON.parse_string(data.get("jsonSchemaValue", ""))
				_check(actual == expected, "Annotation survives project import for " + id)
				var validation = JsonSchemaValidator.validate(actual, schema)
				_check(validation.get("ok", false), "Example annotation matches schema for " + id)
				message._rebuild_schema_form_from_selection(false)
				await process_frame
				var form = message.get_node("SchemaMessageContainer/SchemaEditTabs/SchemaFormTab/SchemaFormVBox/SchemaFormScroll/SchemaFormRoot")
				_check(form.get_child_count() > 0, "Annotation input form is populated")
				var form_data = JSON.parse_string(message._schema_form_controller.get_value_as_json(false))
				_check(form_data == expected, "Schema form preserves annotation values")
		_check(image_found, "Image message exists for " + id)
		_check(annotation_found, "JSON annotation exists for " + id)

	scene.queue_free()
	await process_frame
	print("LFM3-VL example: %d checks, %d failures" % [tests_run, tests_failed])
	quit(tests_failed)
