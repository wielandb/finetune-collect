extends SceneTree

class OpenAiStub:
	extends Node

	signal models_received(models)

	var api_key = ""
	var api_base_url = "https://api.openai.com/v1"

	func get_models() -> void:
		var models: Array[String] = ["gpt-4o-mini", "gpt-4.1-mini"]
		emit_signal("models_received", models)

	func set_api(key: String) -> void:
		api_key = key

	func set_api_base_url(url: String) -> void:
		api_base_url = url

	func get_api() -> String:
		return api_key

class FineTuneStub:
	extends Node

	var SETTINGS = {}
	var _compact_layout_enabled = false

	func is_compact_layout_enabled() -> bool:
		return _compact_layout_enabled

	func update_settings_internal() -> void:
		pass

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _assert_eq(actual, expected, message: String) -> void:
	_check(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fine_tune = FineTuneStub.new()
	fine_tune.name = "FineTune"
	var openai = OpenAiStub.new()
	openai.name = "OpenAi"
	fine_tune.add_child(openai)
	get_root().add_child(fine_tune)

	var conversation_settings = load("res://scenes/conversation_settings.tscn").instantiate()
	conversation_settings.name = "ConversationSettings"
	fine_tune.add_child(conversation_settings)
	await process_frame
	await process_frame

	conversation_settings.from_var({
		"useGlobalSystemMessage": false,
		"globalSystemMessage": "",
		"apikey": "test-key",
		"apiBaseURL": "https://api.openai.com/v1",
		"modelChoice": "gpt-4o-mini",
		"availableModels": ["gpt-4o-mini", "gpt-4.1-mini"]
	})
	await process_frame

	var model_option = conversation_settings.get_node("VBoxContainer/ModelChoiceContainer/ModelChoiceOptionButton")
	var model_line_edit = conversation_settings.get_node("VBoxContainer/ModelChoiceContainer/ModelChoiceLineEdit")
	var model_refresh = conversation_settings.get_node("VBoxContainer/ModelChoiceContainer/ModelChoiceRefreshButton")
	var api_url_edit = conversation_settings.get_node("VBoxContainer/APIBaseURLSettingContainer/APIBaseURLEdit")

	_check(model_option.visible, "OpenAI URL should show model dropdown")
	_check(not model_line_edit.visible, "OpenAI URL should hide custom model input")
	_check(model_refresh.visible, "OpenAI URL should show model refresh button")

	api_url_edit.text = "https://openrouter.ai/api/v1"
	api_url_edit.emit_signal("text_changed", api_url_edit.text)
	await process_frame
	await process_frame
	_check(not model_option.visible, "Custom API URL should hide model dropdown")
	_check(model_line_edit.visible, "Custom API URL should show custom model input")
	_check(not model_refresh.visible, "Custom API URL should hide model refresh button")

	model_line_edit.text = "openai/gpt-4o-mini"
	model_line_edit.emit_signal("text_changed", model_line_edit.text)
	await process_frame
	var custom_settings = conversation_settings.to_var()
	_assert_eq(custom_settings.get("apiBaseURL", ""), "https://openrouter.ai/api/v1", "Custom API URL should be saved")
	_assert_eq(custom_settings.get("modelChoice", ""), "openai/gpt-4o-mini", "Custom model name should be saved from text input")

	api_url_edit.text = "https://api.openai.com/v1/"
	api_url_edit.emit_signal("text_changed", api_url_edit.text)
	await process_frame
	await process_frame
	_check(model_option.visible, "OpenAI URL should restore model dropdown")
	_check(not model_line_edit.visible, "OpenAI URL should hide custom model input after switching back")
	_check(model_refresh.visible, "OpenAI URL should restore refresh button")

	var openai_settings = conversation_settings.to_var()
	_assert_eq(openai_settings.get("apiBaseURL", ""), "https://api.openai.com/v1", "OpenAI URL should be normalized")
	_assert_eq(openai_settings.get("modelChoice", ""), "gpt-4o-mini", "OpenAI mode should store model from dropdown")

	fine_tune.queue_free()
	await process_frame
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)
